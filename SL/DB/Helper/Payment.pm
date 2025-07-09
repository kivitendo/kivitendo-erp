package SL::DB::Helper::Payment;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(pay_invoice);
our @EXPORT_OK = qw(skonto_date amount_less_skonto within_skonto_period percent_skonto reference_account open_amount skonto_amount valid_skonto_amount validate_payment_type get_payment_select_options_for_bank_transaction forex _skonto_charts_and_tax_correction get_exchangerate_for_bank_transaction get_exchangerate _add_bank_fx_fees open_amount_fx open_amount_less_skonto);
our %EXPORT_TAGS = (
  "ALL" => [@EXPORT, @EXPORT_OK],
);

require SL::DB::Chart;

use Carp;
use Data::Dumper;
use DateTime;
use List::Util qw(sum);
use Params::Validate qw(:all);

use SL::DATEV qw(:CONSTANTS);
use SL::DB::Exchangerate;
use SL::DB::Currency;
use SL::HTML::Util;
use SL::Locale::String qw(t8);

#
# Public functions not exported by default
#

sub pay_invoice {
  my ($self, %params) = @_;
  # todo named params
  require SL::DB::Tax;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';
  my $mult = $is_sales ? 1 : -1;  # multiplier for getting the right sign depending on ar/ap
  my @new_acc_ids;
  my $paid_amount = 0; # the amount that will be later added to $self->paid, should be in default currency

  # default values if not set
  $params{payment_type} = 'without_skonto' unless $params{payment_type};
  validate_payment_type($params{payment_type});

  # check for required parameters and optional params depending on payment_type
  Common::check_params(\%params, qw(chart_id transdate amount));
  Common::check_params(\%params, qw(bt_id)) unless $params{payment_type} eq 'without_skonto';

  # three valid cases, test logical params in depth, before proceeding ...
  if ( $params{'payment_type'} eq 'without_skonto' && abs($params{'amount'}) < 0) {
    croak "invalid amount for payment_type 'without_skonto': $params{'amount'}\n";
  } elsif ($params{'payment_type'} eq 'free_skonto') {
    # we dont like too much automagic for this payment type.
    # we force caller input for amount and skonto amount
    Common::check_params(\%params, qw(skonto_amount));
    # secondly we dont want to handle credit notes and purchase credit notes
    croak("Cannot use 'free skonto' for credit or debit notes") if ($params{amount} < 0 || $params{skonto_amount} <= 0);
    # both amount have to be rounded
    $params{skonto_amount} = _round($params{skonto_amount});
    $params{amount}        = _round($params{amount});
    # lastly skonto_amount has to be smaller or equal than the open invoice amount
    if ($params{skonto_amount} > _round($self->open_amount)) {
      croak("Skonto amount:" . $params{skonto_amount} . " higher than the payment or open invoice amount:" . $self->open_amount);
    }
  } elsif ( $params{'payment_type'} eq 'with_skonto_pt' ) {
    # options with_skonto_pt doesn't require the parameter
    # amount, but if amount is passed, make sure it matches the expected value
    # note: the parameter isn't used at all - amount_less_skonto will always be used
    # partial skonto payments are therefore impossible to book
    croak "amount $params{amount} doesn't match open amount less skonto: "
          . $self->open_amount_less_skonto . "\n" if $params{amount}
                                                  && abs($self->open_amount_less_skonto - $params{amount} ) > 0.0000001;
    # croak "payment type with_skonto_pt can't be used if payments have already been made" if $self->paid != 0;
  }

  my $transdate_obj;
  if (ref($params{transdate}) eq 'DateTime') {
    $transdate_obj = $params{transdate};
  } else {
    $transdate_obj = $::locale->parse_date_to_object($params{transdate});
  };
  croak t8('Illegal date') unless ref $transdate_obj;

  # check for closed period
  my $closedto = $::locale->parse_date_to_object($::instance_conf->get_closedto);
  if ( ref $closedto && $transdate_obj < $closedto ) {
    croak t8('Cannot post payment for a closed period!');
  };

  # check for maximum number of future days
  if ( $::instance_conf->get_max_future_booking_interval > 0 ) {
    croak t8('Cannot post transaction above the maximum future booking date!') if $transdate_obj > DateTime->now->add( days => $::instance_conf->get_max_future_booking_interval );
  };

  # currency has to be passed and caller has to be sure to assign it for a forex invoice
  # dies if called for a invoice with the default currency (TODO: Params::Validate before)
  my ($exchangerate, $currency);
  my $fx_gain_loss_amount    = 0;
  my $return_bank_amount     = 0;
  if ($params{currency} || $params{currency_id} && $self->forex) { # currency was specified
    $currency = SL::DB::Manager::Currency->find_by(name => $params{currency}) || SL::DB::Manager::Currency->find_by(id => $params{currency_id});

    die "No currency found" unless ref $currency eq 'SL::DB::Currency';
    die "No exchange rate" unless $params{exchangerate} > 0;

    $exchangerate = $params{exchangerate};

    my $new_open_amount = ( $self->open_amount / $self->get_exchangerate ) * $exchangerate;
    # caller wants to book fees and set a fee amount
    if ($params{fx_book} && $params{fx_fee_amount} > 0) {
      die "Bank Fees can only be added for AP transactions or Sales Credit Notes"
        unless $self->invoice_type =~ m/^purchase_invoice$|^ap_transaction$|^credit_note$/;

      $self->_add_bank_fx_fees(fee           => _round($params{fx_fee_amount}),
                               bt_id         => $params{bt_id},
                               bank_chart_id => $params{chart_id},
                               memo          => $params{memo},
                               source        => $params{source},
                               transdate_obj => $transdate_obj  );
      # invoice_amount add gl booking
      $return_bank_amount += _round($params{fx_fee_amount}); # invoice_type needs negative bank_amount
    }
  } elsif (!$self->forex) { # invoices uses default currency. no exchangerate
    $exchangerate = 1;
  } else {
    die "Cannot calculate exchange rate, if invoices uses the default currency";
  }

  # absolute skonto amount for invoice, use as reference sum to see if the
  # calculated skontos add up
  # only needed for payment_term "with_skonto_pt"

  my $skonto_amount_check = $self->skonto_amount; # variable should be zero after calculating all skonto
  my $total_open_amount   = $self->open_amount;

  # account where money is paid to/from: bank account or cash
  my $account_bank = SL::DB::Manager::Chart->find_by(id => $params{chart_id});
  croak "can't find bank account with id " . $params{chart_id} unless ref $account_bank;

  my $reference_account = $self->reference_account;
  croak "can't find reference account (link = AR/AP) for invoice" unless ref $reference_account;

  my $memo   = $params{memo}   // '';
  my $source = $params{source} // '';

  my $rounded_params_amount = _round( $params{amount} ); # / $exchangerate);
  my $db = $self->db;
  $db->with_transaction(sub {
    my $new_acc_trans;

    # all three payment type create 1 AR/AP booking (the paid part)
    # with_skonto_pt creates 1 bank booking and n skonto bookings (1 for each tax type)
    # and one tax correction as a gl booking
    # without_skonto creates 1 bank booking

    unless ( $rounded_params_amount == 0 ) {
      # cases with_skonto_pt, free_skonto and without_skonto

      # for case with_skonto_pt we need to know the corrected amount at this
      # stage because we don't use $params{amount} ?!

      my $pay_amount = $rounded_params_amount;
      $pay_amount = $self->open_amount_less_skonto if $params{payment_type} eq 'with_skonto_pt';

      # bank account and AR/AP
      $paid_amount += $pay_amount;

      my $amount = (-1 * $pay_amount) * $mult;

      # total amount against bank, do we already know this by now?
      # Yes, method requires this
      $new_acc_trans = SL::DB::AccTransaction->new(trans_id   => $self->id,
                                                   chart_id   => $account_bank->id,
                                                   chart_link => $account_bank->link,
                                                   amount     => $amount,
                                                   transdate  => $transdate_obj,
                                                   source     => $source,
                                                   memo       => $memo,
                                                   project_id => $params{project_id} ? $params{project_id} : undef,
                                                   taxkey     => 0,
                                                   tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
      $new_acc_trans->save;
      $return_bank_amount += $amount;
      push @new_acc_ids, $new_acc_trans->acc_trans_id;
      # deal with fxtransaction ...
      # if invoice exchangerate differs from exchangerate of payment
      # add fxloss or fxgain
      if ($exchangerate != 1 && $self->get_exchangerate and $self->get_exchangerate != 1 and $self->get_exchangerate != $exchangerate) {
        my $fxgain_chart = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_fxgain_accno_id) || die "Can't determine fxgain chart";
        my $fxloss_chart = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_fxloss_accno_id) || die "Can't determine fxloss chart";
        #
        # AMOUNT == EUR / fx rate payment * (fx rate invoice - fx rate payment)
        # AR.pm
        # $amount = $form->round_amount($form->{"paid_$i"} * ($form->{exchangerate} - $form->{"exchangerate_$i"}) * -1, 2);
        # AP.pm
        # exchangerate gain/loss
        # $amount = $form->round_amount($form->{"paid_$i"} * ($form->{exchangerate} - $form->{"exchangerate_$i"}), 2);
        # =>
        my $fx_gain_loss_sign = $is_sales ? -1 : 1;  # multiplier for getting the right sign depending on ar/ap

        $fx_gain_loss_amount  = _round($params{amount} / $exchangerate * ( $self->get_exchangerate - $exchangerate)) * $fx_gain_loss_sign;

        my $gain_loss_chart  = $fx_gain_loss_amount > 0 ? $fxgain_chart : $fxloss_chart;
        # for sales    add loss to ar.paid and subtract gain from ar.paid
        $paid_amount += abs($fx_gain_loss_amount) if $fx_gain_loss_amount < 0 && $self->is_sales;   # extract if we have fx_loss
        $paid_amount -= abs($fx_gain_loss_amount) if $fx_gain_loss_amount > 0 && $self->is_sales;   # but add if to match original invoice amount (arap)
        # for purchase add gain to ap.paid and subtract loss from ap.paid
        $paid_amount += abs($fx_gain_loss_amount) if $fx_gain_loss_amount > 0 && !$self->is_sales; # but add if to match original invoice amount (arap)
        $paid_amount -= abs($fx_gain_loss_amount) if $fx_gain_loss_amount < 0 && !$self->is_sales; # extract if we have fx_loss

        $new_acc_trans = SL::DB::AccTransaction->new(trans_id       => $self->id,
                                                     chart_id       => $gain_loss_chart->id,
                                                     chart_link     => $gain_loss_chart->link,
                                                     amount         => $fx_gain_loss_amount,
                                                     transdate      => $transdate_obj,
                                                     source         => $source,
                                                     memo           => $memo,
                                                     taxkey         => 0,
                                                     fx_transaction => 0, # probably indicates a real bank account in foreign currency
                                                     tax_id         => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
        $new_acc_trans->save;
        push @new_acc_ids, $new_acc_trans->acc_trans_id;
      }
    }
    # skonto cases
    if ($params{payment_type} eq 'with_skonto_pt' or $params{payment_type} eq 'free_skonto' ) {

      my $total_skonto_amount;
      if ( $params{payment_type} eq 'with_skonto_pt' ) {
        $total_skonto_amount = $self->skonto_amount;
      } elsif ( $params{payment_type} eq 'free_skonto') {
        $total_skonto_amount = $params{skonto_amount};
      }
      my @skonto_bookings = $self->_skonto_charts_and_tax_correction(amount => $total_skonto_amount, bt_id => $params{bt_id},
                                                                     transdate_obj => $transdate_obj, memo => $params{memo},
                                                                     source => $params{source});
      my $reference_amount = $total_skonto_amount;

      # create an acc_trans entry for each result of $self->skonto_charts
      foreach my $skonto_booking ( @skonto_bookings ) {
        next unless $skonto_booking->{'chart_id'};
        next unless $skonto_booking->{'skonto_amount'} != 0;
        my $amount = -1 * $skonto_booking->{skonto_amount};
        $new_acc_trans = SL::DB::AccTransaction->new(trans_id   => $self->id,
                                                     chart_id   => $skonto_booking->{'chart_id'},
                                                     chart_link => SL::DB::Manager::Chart->find_by(id => $skonto_booking->{'chart_id'})->link,
                                                     amount     => $amount * $mult,
                                                     transdate  => $transdate_obj,
                                                     source     => $params{source},
                                                     taxkey     => 0,
                                                     tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);

        # the acc_trans entries are saved individually, not added to $self and then saved all at once
        $new_acc_trans->save;
        push @new_acc_ids, $new_acc_trans->acc_trans_id;

        $reference_amount -= abs($amount);
        $paid_amount      += -1 * $amount;
        $skonto_amount_check -= $skonto_booking->{'skonto_amount'};
      }
    }
    my $arap_amount = 0;

    if ( $params{payment_type} eq 'without_skonto' ) {
      $arap_amount = $rounded_params_amount;
    } elsif ( $params{payment_type} eq 'with_skonto_pt' ) {
      # this should be amount + sum(amount+skonto), but while we only allow
      # with_skonto_pt for completely unpaid invoices we just use the value
      # from the invoice
      $arap_amount = $total_open_amount;
    } elsif ( $params{payment_type} eq 'free_skonto' ) {
      # we forced positive values and forced rounding at the beginning
      # therefore the above comment can be safely applied for this payment type
      $arap_amount = $params{amount} + $params{skonto_amount};
    }

    # regardless of payment_type there is always only exactly one arap booking
    # TODO: compare $arap_amount to running total and/or use this as running total for ar.paid|ap.paid
    my $arap_booking= SL::DB::AccTransaction->new(trans_id   => $self->id,
                                                  chart_id   => $reference_account->id,
                                                  chart_link => $reference_account->link,
                                                  amount     => _round($arap_amount * $mult - $fx_gain_loss_amount),
                                                  transdate  => $transdate_obj,
                                                  source     => '', #$params{source},
                                                  taxkey     => 0,
                                                  tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
    $arap_booking->save;
    push @new_acc_ids, $arap_booking->acc_trans_id;

    $self->paid($self->paid + _round($paid_amount)) if $paid_amount;
    $self->datepaid($transdate_obj);
    $self->save;

    # hook for invoice_for_advance_payment DATEV always pairs, acc_trans_id has to be higher than arap_booking ;-)
    if ($self->invoice_type eq 'invoice_for_advance_payment') {
      my $clearing_chart = SL::DB::Chart->new(id => $::instance_conf->get_advance_payment_clearing_chart_id)->load;
      die "No Clearing Chart for Advance Payment" unless ref $clearing_chart eq 'SL::DB::Chart';

      # what does ptc say
      # DONT SAVE $self sellprice, fxsellprice trouble: redmine #352
      my %inv_calc = $self->calculate_prices_and_taxes();
      my @trans_ids = keys %{ $inv_calc{amounts} };
      die "Invalid state for advance payment more than one trans_id" if (scalar @trans_ids > 1);
      my $entry = delete $inv_calc{amounts}{$trans_ids[0]};
      my $tax;
      if ($entry->{tax_id}) {
        $tax = SL::DB::Manager::Tax->find_by(id => $entry->{tax_id}); # || die "Can't find tax with id " . $entry->{tax_id};
      }
      if ($tax and $tax->rate != 0) {
        my ($netamount, $taxamount);
        my $roundplaces = 2;
        # we dont have a clue about skonto, that's why we use $arap_amount as taxincluded
        ($netamount, $taxamount) = Form->calculate_tax($arap_amount, $tax->rate, 1, $roundplaces);
        # for debugging database set
        my $fullmatch = $netamount == $entry->{amount} ? '::netamount total true' : '';
        my $transfer_chart = $tax->taxkey == 2 ? SL::DB::Chart->new(id => $::instance_conf->get_advance_payment_taxable_7_id)->load
                          :  $tax->taxkey == 3 ? SL::DB::Chart->new(id => $::instance_conf->get_advance_payment_taxable_19_id)->load
                          :  undef;
        die "No Transfer Chart for Advance Payment" unless ref $transfer_chart eq 'SL::DB::Chart';

        my $arap_full_booking= SL::DB::AccTransaction->new(trans_id   => $self->id,
                                                           chart_id   => $clearing_chart->id,
                                                           chart_link => $clearing_chart->link,
                                                           amount     => $arap_amount * -1, # full amount
                                                           transdate  => $transdate_obj,
                                                           source     => 'Automatic Tax Booking for Payment in Advance' . $fullmatch,
                                                           taxkey     => 0,
                                                           tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
        $arap_full_booking->save;
        push @new_acc_ids, $arap_full_booking->acc_trans_id;

        my $arap_tax_booking= SL::DB::AccTransaction->new(trans_id   => $self->id,
                                                          chart_id   => $transfer_chart->id,
                                                          chart_link => $transfer_chart->link,
                                                          amount     => _round($netamount), # full amount
                                                          transdate  => $transdate_obj,
                                                          source     => 'Automatic Tax Booking for Payment in Advance' . $fullmatch,
                                                          taxkey     => $tax->taxkey,
                                                          tax_id     => $tax->id);
        $arap_tax_booking->save;
        push @new_acc_ids, $arap_tax_booking->acc_trans_id;

        my $tax_booking= SL::DB::AccTransaction->new(trans_id   => $self->id,
                                                     chart_id   => $tax->chart_id,
                                                     chart_link => $tax->chart->link,
                                                     amount     => _round($taxamount),
                                                     transdate  => $transdate_obj,
                                                     source     => 'Automatic Tax Booking for Payment in Advance' . $fullmatch,
                                                     taxkey     => 0,
                                                     tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);

        $tax_booking->save;
        push @new_acc_ids, $tax_booking->acc_trans_id;
      }
    }
    # make sure transactions will be reloaded the next time $self->transactions
    # is called, as pay_invoice saves the acc_trans objects individually rather
    # than adding them to the transaction relation array.
    $self->forget_related('transactions');

    my $datev_check = 0;
    if ( $is_sales )  {
      if ( (  $self->invoice && $::instance_conf->get_datev_check_on_sales_invoice  ) ||
           ( !$self->invoice && $::instance_conf->get_datev_check_on_ar_transaction )) {
        $datev_check = 1;
      }
    } else {
      if ( (  $self->invoice && $::instance_conf->get_datev_check_on_purchase_invoice ) ||
           ( !$self->invoice && $::instance_conf->get_datev_check_on_ap_transaction   )) {
        $datev_check = 1;
      }
    }

    if ( $datev_check ) {

      my $datev = SL::DATEV->new(
        dbh        => $db->dbh,
        trans_id   => $self->{id},
      );

      $datev->generate_datev_data;

      if ($datev->errors) {
        # this exception should be caught by with_transaction, which handles the rollback
        die join "\n", $::locale->text('DATEV check returned errors:'), $datev->errors;
      }
    }

    1;

  }) || die t8('error while paying invoice #1 : ', $self->invnumber) . $db->error . "\n";

  $return_bank_amount *= -1;   # negative booking is positive bank transaction
                               # positive booking is negative bank transaction
  return wantarray ? ( { return_bank_amount => $return_bank_amount }, @new_acc_ids) : 1;
}

sub skonto_date {
  my $self = shift;

  return undef unless ref $self->payment_terms eq 'SL::DB::PaymentTerm';
  return undef unless $self->payment_terms->terms_skonto > 0;

  return DateTime->from_object(object => $self->transdate)->add(days => $self->payment_terms->terms_skonto);
}

sub reference_account {
  my $self = shift;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  require SL::DB::Manager::AccTransaction;

  my $link_filter = $is_sales ? 'AR' : 'AP';

  my $acc_trans = SL::DB::Manager::AccTransaction->find_by(
     'trans_id'    => $self->id,
     '!chart_id'   => $::instance_conf->get_advance_payment_clearing_chart_id,
     SL::DB::Manager::AccTransaction->chart_link_filter("$link_filter")
  );

  my $id;

  if (! $acc_trans) {
    $id = $is_sales ? $::instance_conf->get_ar_chart_id : $::instance_conf->get_ap_chart_id;
    return undef unless $id;
  } else {
    $id = $acc_trans->chart_id;
  }

  my $reference_account = SL::DB::Manager::Chart->find_by(id => $id);

  return $reference_account;
}

sub open_amount {
  my $self = shift;

  # in the future maybe calculate this from acc_trans

  # if the difference is 0.01 Cent this may end up as 0.009999999999998
  # numerically, so round this value when checking for cent threshold >= 0.01

  return ($self->amount // 0) - ($self->paid // 0);
}

sub open_amount_fx {
  validate_pos(
    @_,
      {  can       => [ qw(forex get_exchangerate open_amount) ],
         callbacks => { 'has forex'        => sub { return $_[0]->forex },
                        'has exchangerate' => sub { return $_[0]->get_exchangerate > 0 } } },
      {  callbacks => {
           'is a positive real'          => sub { return $_[0] =~ m/^[+]?\d+(\.\d+)?$/ }, },
      }
  );

  my ($self, $fx_rate) = @_;

  return ( $self->open_amount / $self->get_exchangerate ) * $fx_rate;

}

sub amount_less_skonto_fx {
  validate_pos(
    @_,
      {  can       => [ qw(forex get_exchangerate percent_skonto) ],
         callbacks => { 'has forex'      => sub { return $_[0]->forex } } },
      {  callbacks => {
           'is a positive real'          => sub { return $_[0] =~ m/^[+]?\d+(\.\d+)?$/ }, },
      }
  );

  my ($self, $fx_rate) = @_;

  return ( $self->amount_less_skonto / $self->get_exchangerate ) * $fx_rate;
}

sub skonto_amount {
  my $self = shift;

  return $self->amount - $self->amount_less_skonto;
}

sub percent_skonto {
  my $self = shift;

  my $percent_skonto = 0;

  return undef unless ref $self->payment_terms;
  return undef unless $self->payment_terms->percent_skonto > 0;
  $percent_skonto = $self->payment_terms->percent_skonto;

  return $percent_skonto;
}

sub amount_less_skonto {
  # amount that has to be paid if skonto applies, always return positive rounded values
  # no, rare case, but credit_notes and negative ap have negative amounts
  # and therefore this comment may be misguiding
  # the result is rounded so we can directly compare it with the user input
  my $self = shift;

  my $percent_skonto = $self->percent_skonto || 0;

  return _round($self->amount - ( $self->amount * $percent_skonto) );

}
sub open_amount_less_skonto {
  # amount that has to be paid if skonto applies, always return positive rounded values
  # no, rare case, but credit_notes and negative ap have negative amounts
  # and therefore this comment may be misguiding
  # the result is rounded so we can directly compare it with the user input
  my $self = shift;

  my $percent_skonto = $self->percent_skonto || 0;

  my $open_amount = ($self->amount // 0) - ($self->paid // 0);
  return _round($open_amount - ( $self->amount * $percent_skonto) );

}
sub _add_bank_fx_fees {
  my ($self, %params)   = @_;
  my $amount = $params{fee};

  croak "no amount passed for bank fx fees"   unless abs(_round($amount)) >= 0.01;
  croak "no banktransaction.id passed"        unless $params{bt_id};
  croak "no bank chart id passed"             unless $params{bank_chart_id};
  croak "no banktransaction.transdate passed" unless ref $params{transdate_obj} eq 'DateTime';

  $params{memo}   //= '';
  $params{source} //= '';

  my ($credit, $debit);
  $credit = SL::DB::Chart->load_cached($params{bank_chart_id});
  $debit  = SL::DB::Manager::Chart->find_by(description => 'Nebenkosten des Geldverkehrs');
  croak("No such Chart ID")  unless ref $credit eq 'SL::DB::Chart' && ref $debit eq 'SL::DB::Chart';
  my $notes = SL::HTML::Util->strip($self->notes);

  my $current_transaction = SL::DB::GLTransaction->new(
         employee_id    => $self->employee_id,
         transdate      => $params{transdate_obj},
         notes          => $params{source} . ' ' . $params{memo},
         description    => $notes || $self->invnumber,
         reference      => t8('Automatic Foreign Exchange Bank Fees') . " "  . $self->invnumber,
         department_id  => $self->department_id ? $self->department_id : undef,
         imported       => 0, # not imported
         taxincluded    => 0,
    )->add_chart_booking(
         chart  => $debit,
         debit  => abs($amount),
         source => t8('Automatic Foreign Exchange Bank Fees') . " "  . $self->invnumber,
         memo   => $params{memo},
         tax_id => 0,
    )->add_chart_booking(
         chart  => $credit,
         credit => abs($amount),
         source => t8('Automatic Foreign Exchange Bank Fees') . " "  . $self->invnumber,
         memo   => $params{memo},
         tax_id => 0,
    )->post;

    # add a stable link acc_trans_id to bank_transactions.id
    foreach my $transaction (@{ $current_transaction->transactions }) {
      my %props_acc = (
           acc_trans_id        => $transaction->acc_trans_id,
           bank_transaction_id => $params{bt_id},
           gl                  => $current_transaction->id,
      );
      SL::DB::BankTransactionAccTrans->new(%props_acc)->save;
    }
    # Record a record link from banktransactions to gl
    my %props_rl = (
         from_table => 'bank_transactions',
         from_id    => $params{bt_id},
         to_table   => 'gl',
         to_id      => $current_transaction->id,
    );
    SL::DB::RecordLink->new(%props_rl)->save;
    # Record a record link from ap to gl
    # linked gl booking will appear in tab linked records
    # this is just a link for convenience
    %props_rl = (
         from_table => $self->is_sales ? 'ar' : 'ap', # yep sales credit notes
         #from_table => 'ap',
         from_id    => $self->id,
         to_table   => 'gl',
         to_id      => $current_transaction->id,
    );
    SL::DB::RecordLink->new(%props_rl)->save;
}

sub _skonto_charts_and_tax_correction {
  my ($self, %params)   = @_;
  my $amount = $params{amount} || $self->skonto_amount;

  croak "no amount passed to skonto_charts"                    unless abs(_round($amount)) >= 0.01;
  croak "no banktransaction.id passed to skonto_charts"        unless $params{bt_id};
  croak "no banktransaction.transdate passed to skonto_charts" unless ref $params{transdate_obj} eq 'DateTime';

  $params{memo}   //= '';
  $params{source} //= '';


  my $is_sales = $self->is_sales;
  my (@skonto_charts, $inv_calc, $total_skonto_rounded);

  $inv_calc = $self->get_tax_and_amount_by_tax_chart_id();
  die t8('Cannot calculate Amount and Tax for this booking correctly, please check chart settings') unless $inv_calc;

  # foreach tax.chart_id || $entry->{ta..id}
  while (my ($tax_chart_id, $entry) = each %{ $inv_calc } ) {
    my $tax = SL::DB::Manager::Tax->find_by(id => $entry->{tax_id}) || die "Can't find tax with id " . $tax_chart_id;
    die t8('no skonto_chart configured for taxkey #1 : #2 : #3', $tax->taxkey, $tax->taxdescription , $tax->rate * 100)
      unless $is_sales ? ref $tax->skonto_sales_chart : ref $tax->skonto_purchase_chart;

    # percent net amount
    my $transaction_net_skonto_percent = abs($entry->{netamount} / $self->amount);
    my $skonto_netamount_unrounded     = abs($amount * $transaction_net_skonto_percent);

    # percent tax amount
    my $transaction_tax_skonto_percent = abs($entry->{tax} / $self->amount);
    my $skonto_taxamount_unrounded     = abs($amount * $transaction_tax_skonto_percent);

    my $skonto_taxamount_rounded   = _round($skonto_taxamount_unrounded);
    my $skonto_netamount_rounded   = _round($skonto_netamount_unrounded);
    my $chart_id                   = $is_sales ? $tax->skonto_sales_chart->id : $tax->skonto_purchase_chart->id;

    my $credit_note_multiplier = $self->is_credit_note ? -1 : 1;
    # entry net + tax for caller
    my $rec_net = {
      chart_id               => $chart_id,
      skonto_amount          => _round($skonto_netamount_unrounded + $skonto_taxamount_unrounded)
                                * $credit_note_multiplier,
    };
    push @skonto_charts, $rec_net;
    $total_skonto_rounded += $rec_net->{skonto_amount};

    # add-on: correct tax with one linked gl booking

    # no skonto tax correction for dual tax (reverse charge) or rate = 0 or taxamount below 0.01
    next if ($tax->rate == 0 || $tax->reverse_charge_chart_id || $skonto_taxamount_rounded < 0.01);

    my ($credit, $debit);
    $credit = SL::DB::Manager::Chart->find_by(id => $chart_id);
    $debit  = SL::DB::Manager::Chart->find_by(id => $tax_chart_id);
    croak("No such Chart ID")  unless ref $credit eq 'SL::DB::Chart' && ref $debit eq 'SL::DB::Chart';
    my $notes = SL::HTML::Util->strip($self->notes);

    my $debit_state = ( $is_sales && !$self->is_credit_note)        ? 1
                    : (!$is_sales && !$self->is_credit_note)        ? 0
                    : $self->invoice_type eq 'purchase_credit_note' ? 1
                    : $self->invoice_type eq 'credit_note'          ? 0
                    : die "invalid type state";

    my $current_transaction = SL::DB::GLTransaction->new(
         employee_id    => $self->employee_id,
         transdate      => $params{transdate_obj},
         notes          => $params{source} . ' ' . $params{memo},
         description    => $notes || $self->invnumber,
         reference      => t8('Skonto Tax Correction for') . " " . $tax->rate * 100 . '% ' . $self->invnumber,
         department_id  => $self->department_id ? $self->department_id : undef,
         imported       => 0, # not imported
         taxincluded    => 0,
      )->add_chart_booking(
         chart  => $debit_state ? $debit : $credit,
         debit  => abs($skonto_taxamount_rounded),
         source => t8('Skonto Tax Correction for') . " " . $self->invnumber,
         memo   => $params{memo},
         tax_id => 0,
      )->add_chart_booking(
         chart  => $debit_state ? $credit : $debit,
         credit => abs($skonto_taxamount_rounded),
         source => t8('Skonto Tax Correction for') . " " . $self->invnumber,
         memo   => $params{memo},
         tax_id => 0,
      )->post;

    # add a stable link acc_trans_id to bank_transactions.id
    foreach my $transaction (@{ $current_transaction->transactions }) {
      my %props_acc = (
           acc_trans_id        => $transaction->acc_trans_id,
           bank_transaction_id => $params{bt_id},
           gl                  => $current_transaction->id,
      );
      SL::DB::BankTransactionAccTrans->new(%props_acc)->save;
    }
    # Record a record link from banktransactions to gl
    my %props_rl = (
         from_table => 'bank_transactions',
         from_id    => $params{bt_id},
         to_table   => 'gl',
         to_id      => $current_transaction->id,
    );
    SL::DB::RecordLink->new(%props_rl)->save;
    # Record a record link from arap to gl
    # linked gl booking will appear in tab linked records
    # this is just a link for convenience
    %props_rl = (
         from_table => $is_sales ? 'ar' : 'ap',
         from_id    => $self->id,
         to_table   => 'gl',
         to_id      => $current_transaction->id,
    );
    SL::DB::RecordLink->new(%props_rl)->save;

  }
  # check for rounding errors, at least for the payment chart
  # we ignore tax rounding errors as long as the amount (user input or calculated)
  # is fully assigned.
  # we simply alter one cent for the first skonto booking entry
  # should be correct for most of the cases (no invoices with mixed taxes)
  if (_round($total_skonto_rounded - $amount) >= 0.01) {
    # subtract one cent
    $skonto_charts[0]->{skonto_amount} -= 0.01;
  } elsif (_round($amount - $total_skonto_rounded) >= 0.01) {
    # add one cent
    $skonto_charts[0]->{skonto_amount} += 0.01;
  }

  # return same array of skonto charts as sub skonto_charts
  return @skonto_charts;
}

sub within_skonto_period {
  my $self = shift;
  validate(
    @_,
       { transdate => {
                        isa => 'DateTime',
                        callbacks => {
                          'self has a skonto date'  => sub { ref $self->skonto_date eq 'DateTime' },
                        },
                      },
       }
    );
  # return 1 if requested date (or today) is inside skonto period
  # this will also return 1 if date is before the invoice date
  my (%params) = @_;
  return $params{transdate} <= $self->skonto_date;
}

sub valid_skonto_amount {
  my $self = shift;
  my $amount = shift || 0;
  my $max_skonto_percent = 0.10;

  return 0 unless $amount > 0;

  # does this work for other currencies?
  return ($self->amount*$max_skonto_percent) > $amount;
}

sub get_payment_select_options_for_bank_transaction {
  my ($self, $bt_id) = @_;

  my @options;

  # 1. no sane skonto support for foreign currency yet
  if ($self->forex) {
    push(@options, { payment_type => 'without_skonto', display => t8('without skonto'), selected => 1 });
    return @options;
  }
  # 2. no skonto available -> done
  if (!$self->skonto_date) {
    push(@options, { payment_type => 'without_skonto', display => t8('without skonto'), selected => 1 });
    push(@options, { payment_type => 'free_skonto', display => t8('free skonto') });
    return @options;
  }

  # 2. valid skonto date, check if date is within skonto period
  # CAVEAT template code expects with_skonto_pt at position 1 for visual help
  # [% is_skonto_pt   = SELECT_OPTIONS.1.selected %]

  my $bt = SL::DB::BankTransaction->new(id => $bt_id)->load;
  croak "No Bank Transaction with ID $bt_id found" unless ref $bt eq 'SL::DB::BankTransaction';

  if (ref $self->skonto_date eq 'DateTime' &&  $self->within_skonto_period(transdate => $bt->transdate)) {
    push(@options, { payment_type => 'without_skonto', display => t8('without skonto') });
    push(@options, { payment_type => 'with_skonto_pt', display => t8('with skonto acc. to pt'), selected => 1 });
    push(@options, { payment_type => 'with_fuzzy_skonto_pt', display => t8('with fuzzy skonto acc. to pt')});
  } else {
    push(@options, { payment_type => 'without_skonto', display => t8('without skonto') , selected => 1 });
    push(@options, { payment_type => 'with_skonto_pt', display => t8('with skonto acc. to pt')});
    push(@options, { payment_type => 'with_fuzzy_skonto_pt', display => t8('with fuzzy skonto acc. to pt')});
  }
  push(@options, { payment_type => 'free_skonto', display => t8('free skonto') });
  return @options;
}

sub get_exchangerate {
  my ($self) = @_;

  return 1 if $self->currency_id == $::instance_conf->get_currency_id;

  # return record exchange rate if set
  return $self->exchangerate if $self->exchangerate && $self->exchangerate > 0;

  # none defined check daily exchangerate at records transdate
  die "transdate isn't a DateTime object:" . ref($self->transdate) unless ref($self->transdate) eq 'DateTime';

  my $rate = SL::DB::Manager::Exchangerate->find_by(currency_id => $self->currency_id,
                                                    transdate   => $self->transdate,
                                                   );
  return undef unless $rate;

  return $self->is_sales ? $rate->buy : $rate->sell; # also undef if not defined
}

# locales for payment type
#
# $main::locale->text('without_skonto')
# $main::locale->text('with_skonto_pt')
#

sub validate_payment_type {
  my $payment_type = shift;

  my %allowed_payment_types = map { $_ => 1 } qw(without_skonto with_skonto_pt free_skonto);
  croak "illegal payment type: $payment_type, must be one of: " . join(' ', keys %allowed_payment_types) unless $allowed_payment_types{ $payment_type };

  return 1;
}

sub forex {
  my ($self) = @_;
  $self->currency_id == $::instance_conf->get_currency_id ? return 0 : return 1;
}

sub get_exchangerate_for_bank_transaction {
  validate_pos(
    @_,
      {  can       => [ qw(forex is_sales) ],
         callbacks => { 'has forex'      => sub { return $_[0]->forex } } },
      {  callbacks => {
           'is an integer'               => sub { return $_[0] =~ /^[1-9][0-9]*$/                                              },
           'is a valid bank transaction' => sub { ref SL::DB::BankTransaction->load_cached($_[0]) eq 'SL::DB::BankTransaction' },
           'has a valid valuta date'     => sub { ref SL::DB::BankTransaction->load_cached($_[0])->valutadate eq 'DateTime'    },
         },
      }
  );

  my ($self, $bt_id) = @_;

  my $bt   = SL::DB::BankTransaction->load_cached($bt_id);
  my $rate = SL::DB::Manager::Exchangerate->find_by(currency_id => $self->currency_id,
                                                    transdate   => $bt->valutadate,
                                                   );
  return undef unless $rate;

  return $self->is_sales ? $rate->buy : $rate->sell; # also undef if not defined
}

sub _round {
  my $value = shift;
  my $num_dec = 2;
  return $::form->round_amount($value, 2);
}

1;

__END__

=pod

=head1 NAME

SL::DB::Helper::Payment  Mixin providing helper methods for paying C<Invoice>
                         and C<PurchaseInvoice> objects and using skonto

=head1 SYNOPSIS

In addition to actually causing a payment via pay_invoice this helper contains
many methods that help in determining information about the status of the
invoice, such as the remaining open amount, whether skonto applies, until which
date skonto applies, the skonto amount and relative percentages, what to do
with skonto, ...

To prevent duplicate code this was all added in this mixin rather than directly
in SL::DB::Invoice and SL::DB::PurchaseInvoice.

=over 4

=item C<pay_invoice %params>

Create a payment booking for an existing invoice object (type ar/ap/is/ir) via
a configured bank account.

This function deals with all the acc_trans entries and also updates paid and datepaid.
The params C<transdate>, C<amount> and C<chart_id> are mandantory.

For all valid skonto types ('free_skonto' or 'with_skonto_pt') the source of
the bank_transaction is needed, therefore pay_invoice expects the param
C<bt_id> with a valid bank_transactions.id.

If the payment type ('free_skonto') is used the number param skonto_amount is
as well mandantory and needs to be positive. Furthermore the skonto amount has
to be lower or equal than the open invoice amount.
Payments with only skonto and zero bank transaction amount are possible.

Transdate can either be a date object or a date string.
Chart_id is the id of the payment booking chart.
Amount is either a positive or negative number, and for the case 'free_skonto' might be zero.

If the parameters currency and exchangerate exists the method will determine gain and
loss rates for exchangerates.

If the parameters fx_book is true and fx_fee_amount exists as number the method will book the costs of
foreign exchanges with a link GL Record.

CAVEAT! The helper tries to get the sign right and all calls from BankTransaction are
positive (abs($value)) values.


Example:

  my $ap   = SL::DB::Manager::PurchaseInvoice->find_by( invnumber => '1');
  my $bank = SL::DB::Manager::BankAccount->find_by( name => 'Bank');
  $ap->pay_invoice(chart_id      => $bank->chart_id,
                   amount        => $ap->open_amount,
                   transdate     => DateTime->now->to_kivitendo,
                   memo          => 'foobar',
                   source        => 'barfoo',
                   payment_type  => 'without_skonto',  # default if not specified
                   project_id    => 25,
                  );

or with skonto:
  $ap->pay_invoice(chart_id      => $bank->chart_id,
                   amount        => $ap->amount,       # doesn't need to be specified
                   transdate     => DateTime->now->to_kivitendo,
                   memo          => 'foobar',
                   source        => 'barfoo',
                   payment_type  => 'with_skonto',
                  );

or in a certain currency:
  $ap->pay_invoice(chart_id      => $bank->chart_id,
                   amount        => 500,
                   currency      => 'USD',
                   exchangerate  => 0.9820,
                   transdate     => DateTime->now->to_kivitendo,
                   memo          => 'foobar',
                   source        => 'barfoo',
                   payment_type  => 'with_skonto_pt',
                  );

Allowed payment types are:
  without_skonto with_skonto_pt

The option C<payment_type> allows for a basic skonto mechanism.

C<without_skonto> is the default mode, "amount" is paid to the account in
chart_id. This can also be used for partial payments and corrections via
negative amounts.

C<with_skonto_pt> can't be used for partial payments. When used on unpaid
invoices the whole amount is paid, with the skonto part automatically being
booked according to the skonto chart configured in the tax settings for each
tax key. If an amount is passed it is ignored and the actual configured skonto
amount is used.

So passing amount doesn't have any effect for the case C<with_skonto_pt>.

The skonto modes automatically calculate the relative amounts for a mix of
taxes, e.g. items with 7% and 19% in one invoice. There is a helper method
_skonto_charts_and_tax_correction, which calculates the relative percentages
according to the amounts in acc_trans grouped by different tax rates.

The helper method also generates the tax correction for the skonto booking
and links this to the original bank transaction and the selected record.

There is currently no way of excluding certain items in an invoice from having
skonto applied to them.  If this feature was added to parts the calculation
method of relative skonto would have to be completely rewritten using the
invoice items rather than acc_trans.

Because of the way skonto_charts works the calculation doesn't work if there
are negative values in acc_trans. E.g. one invoice with a positive value for
19% tax and a negative value for the acc_trans line with 7%

Skonto doesn't/shouldn't apply if the invoice contains credited items.

If no amount is given the whole open amout is paid.

If neither currency or currency_id are given as params, the currency of the
invoice is assumed to be the payment currency.

If successful the return value will be 1 in scalar context or in list context
the two or more (gl transaction for skonto tax correction) ids (acc_trans_id)
of the newly created bookings.


=item C<reference_account>

Returns a chart object which is the chart of the invoice with link AR or AP.

Example (1200 is the AR account for SKR04):
  my $invoice = invoice(invnumber => '144');
  $invoice->reference_account->accno
  # 1200

=item C<percent_skonto>

Returns the configured skonto percentage of the payment terms of an invoice,
e.g. 0.02 for 2%. Payment terms come from invoice settingssettings for ap.

=item C<amount_less_skonto>

If the invoice has a payment term,
calculate the amount to be paid in the case of skonto.  This doesn't check,
whether skonto applies (i.e. skonto doesn't wasn't exceeded), it just subtracts
the configured percentage (e.g. 2%) from the total amount.

The returned value is rounded to two decimals.

=item C<open_amount_less_skonto>

The same as amount_less_skonto but calculates skonto against the current
open amount, i.e. some amount of the invoice is reduced because of a linked
credit note.

The returned value is rounded to two decimals.


=item C<skonto_date>

The date up to which skonto may be taken. This is calculated from the invoice
date + the number of days configured in the payment terms.

This method can also be used to determine whether skonto applies for the
invoice, as it returns undef if there is no payment term or skonto days is set
to 0.

=item C<within_skonto_period [transdate =E<gt> DateTime]>

Returns 1 if skonto_date is in a skontoable period otherwise undef.


Expects transdate to be set and to be a DateTime object.
Expects calling object to be a Invoice object with a skonto_date set.

Throws a error if any of the two mandantory conditions are not met.

If the conditions are met the routine simply checks if the param transdate
is within the max allowed date of the invoices skonto date.

Example usage:

 my $inv = SL::DB::Invoice->new;
 my $bt  = SL::DB::BankTransaction->new;

 my $payment_date_is_skontoable =
   (ref $inv->skonto_date eq 'DateTime' && $inv->within_skonto_period(transdate => $bt->transdate));

=item C<valid_skonto_amount>

Takes an amount as an argument and checks whether the amount is less than 10%
of the total amount of the invoice. The value of 10% is currently hardcoded in
the method. This method is currently used to check whether to offer the payment
option "difference as skonto".

Example:
 if ( $invoice->valid_skonto_amount($invoice->open_amount) ) {
   # ... do something
 }

=item C<_skonto_charts_and_tax_correction [amount => $amount, bt_id => $bank_transaction.id, transdate_ojb => DateTime]>

Needs a valid bank_transaction id and the transdate of the bank_transaction as
a DateTime object.
If no amout is passed, the currently open invoice amount will be used.

Returns a list of chart_ids and some calculated numbers that can be used for
paying the invoice with skonto. This function will automatically calculate the
relative skonto amounts even if the invoice contains several types of taxes
(e.g. 7% and 19%).

Example usage:
  my $invoice = SL::DB::Manager::Invoice->find_by(invnumber => '211');
  my @skonto_charts = $invoice->_skonto_charts_and_tax_correction(bt_id         => $bt_id,
                                                                  transdate_obj => $transdate_obj);

or with the total skonto amount as an argument:
  my @skonto_charts = $invoice->_skonto_charts_and_tax_correction(amount => $invoice->open_amount,
                                                                  bt_id  => $bt_id,
                                                                  transdate_obj => $transdate_obj);

The following values are generated for each chart:

=over 2

=item C<chart_id>

The chart id of the skonto amount to be booked.

=item C<skonto_amount>

The total amount to be paid to the account

=back

If the invoice contains several types of taxes then skonto_charts can be used
to calculate the relative amounts.

C<_skonto_charts_and_tax_correction> generates one entry for each tax type entry.

=item C<open_amount>

Unrounded total open amount of invoice (amount - paid).
Doesn't take into account pending SEPA transfers.

=item C<get_payment_suggestions %params>

Creates data intended for an L.select_tag dropdown that can be used in a
template. Depending on the rules it will choose from the options
without_skonto and with_skonto_pt and select the most
likely one.

If the parameter "sepa" is passed, the SEPA export payments that haven't been
executed yet are considered when determining the open amount of the invoice.

The current rules are:

=over 2

=item * without_skonto is always an option

=item * with_skonto_pt is only offered if there haven't been any payments yet and the current date is within the skonto period.

with_skonto_pt will only be offered, if all the AR_amount/AP_amount have a
taxkey with a configured skonto chart

=back

It will also fill $self->{invoice_amount_suggestion} with either the open
amount, or if with_skonto_pt is selected, with amount_less_skonto, so the
template can fill the input with the likely amount.

Example in console:
  my $ar = invoice( invnumber => '257');
  $ar->get_payment_suggestions;
  print $ar->{invoice_amount_suggestion} . "\n";
  # 97.23
  pp $ar->{payment_select_options}
  # $VAR1 = [
  #         {
  #           'display' => 'ohne Skonto',
  #           'payment_type' => 'without_skonto'
  #         },
  #         {
  #           'display' => 'mit Skonto nach ZB',
  #           'payment_type' => 'with_skonto_pt',
  #           'selected' => 1
  #         }
  #       ];

The resulting array $ar->{payment_select_options} can be used in a template
select_tag using value_key and title_key:

[% L.select_tag('payment_type_' _ loop.count, invoice.payment_select_options, value_key => 'payment_type', title_key => 'display', id => 'payment_type_' _ loop.count) %]

It would probably make sense to have different rules for the pre-selected items
for sales and purchase, and to also make these rules configurable in the
defaults. E.g. when creating a SEPA bank transfer for vendor invoices a company
might always want to pay quickly making use of skonto, while another company
might always want to pay as late as possible.

=item C<get_payment_select_options_for_bank_transaction $banktransaction_id %params>

Make suggestion for a skonto payment type by returning an HTML blob of the options
of a HTML drop-down select with the most likely option preselected.

This is a helper function for BankTransaction/ajax_payment_suggestion and
template/webpages/bank_transactions/invoices.html

We are working with an existing payment, so (deprecated) difference_as_skonto never makes sense.

If skonto is not possible (skonto_date does not exists) simply return
the single 'no skonto' option as a visual hint.

If skonto is possible (skonto_date exists), add two possibilities:
without_skonto and with_skonto_pt if payment date is within skonto_date,
preselect with_skonto_pt, otherwise preselect without skonto.

=item C<exchangerate>

Returns 1 immediately if the record uses the default currency.

Returns the exchangerate in database format for the invoice according to that
invoice's transdate, returning 'buy' for sales, 'sell' for purchases.

If no exchangerate can be found for that day undef is returned.

=item C<forex>

Returns 1 if record uses a different currency, 0 if the default currency is used.

=back

=head1 TODO AND CAVEATS

=over 4

=item *

when looking at open amount, maybe consider that there may already be queued
amounts in SEPA Export

=item * C<_skonto_charts_and_tax_correction>

Cannot handle negative skonto amounts, will always calculate the skonto amount
for credit notes or negative ap transactions with a positive sign.


=back

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
