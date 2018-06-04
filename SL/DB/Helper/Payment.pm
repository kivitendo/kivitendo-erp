package SL::DB::Helper::Payment;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(pay_invoice);
our @EXPORT_OK = qw(skonto_date skonto_charts amount_less_skonto within_skonto_period percent_skonto reference_account reference_amount open_amount open_percent remaining_skonto_days skonto_amount check_skonto_configuration valid_skonto_amount get_payment_suggestions validate_payment_type open_sepa_transfer_amount get_payment_select_options_for_bank_transaction exchangerate forex);
our %EXPORT_TAGS = (
  "ALL" => [@EXPORT, @EXPORT_OK],
);

require SL::DB::Chart;
use Data::Dumper;
use DateTime;
use SL::DATEV qw(:CONSTANTS);
use SL::Locale::String qw(t8);
use List::Util qw(sum);
use SL::DB::Exchangerate;
use SL::DB::Currency;
use Carp;

#
# Public functions not exported by default
#

sub pay_invoice {
  my ($self, %params) = @_;

  require SL::DB::Tax;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';
  my $mult = $is_sales ? 1 : -1;  # multiplier for getting the right sign depending on ar/ap

  my $paid_amount = 0; # the amount that will be later added to $self->paid, should be in default currency

  # default values if not set
  $params{payment_type} = 'without_skonto' unless $params{payment_type};
  validate_payment_type($params{payment_type});

  # check for required parameters
  Common::check_params(\%params, qw(chart_id transdate));

  my $transdate_obj;
  if (ref($params{transdate} eq 'DateTime')) {
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

  # currency is either passed or use the invoice currency if it differs from the default currency
  my ($exchangerate,$currency);
  if ($params{currency} || $params{currency_id} || $self->currency_id != $::instance_conf->get_currency_id) {
    if ($params{currency} || $params{currency_id} ) { # currency was specified
      $currency = SL::DB::Manager::Currency->find_by(name => $params{currency}) || SL::DB::Manager::Currency->find_by(id => $params{currency_id});
    } else { # use invoice currency
      $currency = SL::DB::Manager::Currency->find_by(id => $self->currency_id);
    };
    die "no currency" unless $currency;
    if ($currency->id == $::instance_conf->get_currency_id) {
      $exchangerate = 1;
    } else {
      my $rate = SL::DB::Manager::Exchangerate->find_by(currency_id => $currency->id,
                                                        transdate   => $transdate_obj,
                                                       );
      if ($rate) {
        $exchangerate = $is_sales ? $rate->buy : $rate->sell;
      } else {
        die "No exchange rate for " . $transdate_obj->to_kivitendo;
      };
    };
  } else { # no currency param given or currency is the same as default_currency
    $exchangerate = 1;
  };

  # input checks:
  if ( $params{'payment_type'} eq 'without_skonto' ) {
    croak "invalid amount for payment_type 'without_skonto': $params{'amount'}\n" unless abs($params{'amount'}) > 0;
  };

  # options with_skonto_pt and difference_as_skonto don't require the parameter
  # amount, but if amount is passed, make sure it matches the expected value
  if ( $params{'payment_type'} eq 'difference_as_skonto' ) {
    croak "amount $params{amount} doesn't match open amount " . $self->open_amount . ", diff = " . ($params{amount}-$self->open_amount) if $params{amount} && abs($self->open_amount - $params{amount} ) > 0.0000001;
  } elsif ( $params{'payment_type'} eq 'with_skonto_pt' ) {
    croak "amount $params{amount} doesn't match amount less skonto: " . $self->amount_less_skonto . "\n" if $params{amount} && abs($self->amount_less_skonto - $params{amount} ) > 0.0000001;
    croak "payment type with_skonto_pt can't be used if payments have already been made" if $self->paid != 0;
  };

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
  my $fx_gain_loss_amount = 0; # for fx_gain and fx_loss

  my $db = $self->db;
  $db->with_transaction(sub {
    my $new_acc_trans;

    # all three payment type create 1 AR/AP booking (the paid part)
    # difference_as_skonto creates n skonto bookings (1 for each tax type)
    # with_skonto_pt creates 1 bank booking and n skonto bookings (1 for each tax type)
    # without_skonto creates 1 bank booking

    # as long as there is no automatic tax, payments are always booked with
    # taxkey 0

    unless ( $params{payment_type} eq 'difference_as_skonto' ) {
      # cases with_skonto_pt and without_skonto

      # for case with_skonto_pt we need to know the corrected amount at this
      # stage if we are going to use $params{amount}

      my $pay_amount = $rounded_params_amount;
      $pay_amount = $self->amount_less_skonto if $params{payment_type} eq 'with_skonto_pt';

      # bank account and AR/AP
      $paid_amount += $pay_amount * $exchangerate;

      my $amount = (-1 * $pay_amount) * $mult;


      # total amount against bank, do we already know this by now?
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

      # deal with fxtransaction
      if ( $self->currency_id != $::instance_conf->get_currency_id ) {
        my $fxamount = _round($amount - ($amount * $exchangerate));
        $new_acc_trans = SL::DB::AccTransaction->new(trans_id       => $self->id,
                                                     chart_id       => $account_bank->id,
                                                     chart_link     => $account_bank->link,
                                                     amount         => $fxamount * -1,
                                                     transdate      => $transdate_obj,
                                                     source         => $source,
                                                     memo           => $memo,
                                                     taxkey         => 0,
                                                     fx_transaction => 1,
                                                     tax_id         => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
        $new_acc_trans->save;
        # if invoice exchangerate differs from exchangerate of payment
        # deal with fxloss and fxamount
        if ($self->exchangerate and $self->exchangerate != 1 and $self->exchangerate != $exchangerate) {
          my $fxgain_chart = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_fxgain_accno_id) || die "Can't determine fxgain chart";
          my $fxloss_chart = SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_fxloss_accno_id) || die "Can't determine fxloss chart";
          my $gain_loss_amount = _round($amount * ($exchangerate - $self->exchangerate ) * -1,2);
          my $gain_loss_chart = $gain_loss_amount > 0 ? $fxgain_chart : $fxloss_chart;
          $fx_gain_loss_amount = $gain_loss_amount;

          $new_acc_trans = SL::DB::AccTransaction->new(trans_id       => $self->id,
                                                       chart_id       => $gain_loss_chart->id,
                                                       chart_link     => $gain_loss_chart->link,
                                                       amount         => $gain_loss_amount,
                                                       transdate      => $transdate_obj,
                                                       source         => $source,
                                                       memo           => $memo,
                                                       taxkey         => 0,
                                                       fx_transaction => 0,
                                                       tax_id         => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
          $new_acc_trans->save;

        };
      };
    };

    if ( $params{payment_type} eq 'difference_as_skonto' or $params{payment_type} eq 'with_skonto_pt' ) {

      my $total_skonto_amount;
      if ( $params{payment_type} eq 'with_skonto_pt' ) {
        $total_skonto_amount = $self->skonto_amount;
      } elsif ( $params{payment_type} eq 'difference_as_skonto' ) {
        $total_skonto_amount = $self->open_amount;
      };

      my @skonto_bookings = $self->skonto_charts($total_skonto_amount);

      # error checking:
      if ( $params{payment_type} eq 'difference_as_skonto' ) {
        my $calculated_skonto_sum  = sum map { $_->{skonto_amount} } @skonto_bookings;
        croak "calculated skonto for difference_as_skonto = $calculated_skonto_sum doesn't add up open amount: " . $self->open_amount unless _round($calculated_skonto_sum) == _round($self->open_amount);
      };

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

        $reference_amount -= abs($amount);
        $paid_amount      += -1 * $amount * $exchangerate;
        $skonto_amount_check -= $skonto_booking->{'skonto_amount'};
      };
      if ( $params{payment_type} eq 'difference_as_skonto' ) {
          die "difference_as_skonto calculated incorrectly, sum of calculated payments doesn't add up to open amount $total_open_amount, reference_amount = $reference_amount\n" unless _round($reference_amount) == 0;
      }

    };

    my $arap_amount = 0;

    if ( $params{payment_type} eq 'difference_as_skonto' ) {
      $arap_amount = $total_open_amount;
    } elsif ( $params{payment_type} eq 'without_skonto' ) {
      $arap_amount = $rounded_params_amount;
    } elsif ( $params{payment_type} eq 'with_skonto_pt' ) {
      # this should be amount + sum(amount+skonto), but while we only allow
      # with_skonto_pt for completely unpaid invoices we just use the value
      # from the invoice
      $arap_amount = $total_open_amount;
    };

    # regardless of payment_type there is always only exactly one arap booking
    # TODO: compare $arap_amount to running total
    my $arap_booking= SL::DB::AccTransaction->new(trans_id   => $self->id,
                                                  chart_id   => $reference_account->id,
                                                  chart_link => $reference_account->link,
                                                  amount     => _round($arap_amount * $mult * $exchangerate - $fx_gain_loss_amount),
                                                  transdate  => $transdate_obj,
                                                  source     => '', #$params{source},
                                                  taxkey     => 0,
                                                  tax_id     => SL::DB::Manager::Tax->find_by(taxkey => 0)->id);
    $arap_booking->save;

    $fx_gain_loss_amount *= -1 if $self->is_sales;
    $self->paid($self->paid + _round($paid_amount) + $fx_gain_loss_amount) if $paid_amount;
    $self->datepaid($transdate_obj);
    $self->save;

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

  return 1;
};

sub skonto_date {

  my $self = shift;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  my $skonto_date;

  if ( $is_sales ) {
    return undef unless ref $self->payment_terms;
    return undef unless $self->payment_terms->terms_skonto > 0;
    $skonto_date = DateTime->from_object(object => $self->transdate)->add(days => $self->payment_terms->terms_skonto);
  } else {
    return undef unless ref $self->vendor->payment_terms;
    return undef unless $self->vendor->payment_terms->terms_skonto > 0;
    $skonto_date = DateTime->from_object(object => $self->transdate)->add(days => $self->vendor->payment_terms->terms_skonto);
  };

  return $skonto_date;
};

sub reference_account {
  my $self = shift;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  require SL::DB::Manager::AccTransaction;

  my $link_filter = $is_sales ? 'AR' : 'AP';

  my $acc_trans = SL::DB::Manager::AccTransaction->find_by(
     trans_id   => $self->id,
     SL::DB::Manager::AccTransaction->chart_link_filter("$link_filter")
  );

  return undef unless ref $acc_trans;

  my $reference_account = SL::DB::Manager::Chart->find_by(id => $acc_trans->chart_id);

  return $reference_account;
};

sub reference_amount {
  my $self = shift;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  require SL::DB::Manager::AccTransaction;

  my $link_filter = $is_sales ? 'AR' : 'AP';

  my $acc_trans = SL::DB::Manager::AccTransaction->find_by(
     trans_id   => $self->id,
     SL::DB::Manager::AccTransaction->chart_link_filter("$link_filter")
  );

  return undef unless ref $acc_trans;

  # this should be the same as $self->amount
  return $acc_trans->amount;
};


sub open_amount {
  my $self = shift;

  # in the future maybe calculate this from acc_trans

  # if the difference is 0.01 Cent this may end up as 0.009999999999998
  # numerically, so round this value when checking for cent threshold >= 0.01

  return ($self->amount // 0) - ($self->paid // 0);
};

sub open_percent {
  my $self = shift;

  return 0 if $self->amount == 0;
  my $open_percent;
  if ( $self->open_amount < 0 ) {
    # overpaid, currently treated identically
    $open_percent = $self->open_amount * 100 / $self->amount;
  } else {
    $open_percent = $self->open_amount * 100 / $self->amount;
  };

  return _round($open_percent) || 0;
};

sub skonto_amount {
  my $self = shift;

  return $self->amount - $self->amount_less_skonto;
};

sub remaining_skonto_days {
  my $self = shift;

  return undef unless ref $self->skonto_date;

  my $dur = DateTime::Duration->new($self->skonto_date - DateTime->today);
  return $dur->delta_days();

};

sub percent_skonto {
  my $self = shift;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  my $percent_skonto = 0;

  if ( $is_sales ) {
    return undef unless ref $self->payment_terms;
    return undef unless $self->payment_terms->percent_skonto > 0;
    $percent_skonto = $self->payment_terms->percent_skonto;
  } else {
    return undef unless ref $self->vendor->payment_terms;
    return undef unless $self->vendor->payment_terms->terms_skonto > 0;
    $percent_skonto = $self->vendor->payment_terms->percent_skonto;
  };

  return $percent_skonto;
};

sub amount_less_skonto {
  # amount that has to be paid if skonto applies, always return positive rounded values
  # the result is rounded so we can directly compare it with the user input
  my $self = shift;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  my $percent_skonto = $self->percent_skonto || 0;

  return _round($self->amount - ( $self->amount * $percent_skonto) );

};

sub check_skonto_configuration {
  my $self = shift;

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  my $skonto_configured = 1; # default is assume skonto works

  # my $transactions = $self->transactions;
  foreach my $transaction (@{ $self->transactions }) {
    # find all transactions with an AR_amount or AP_amount link
    my $tax = SL::DB::Manager::Tax->get_first( where => [taxkey => $transaction->taxkey, id => $transaction->tax_id ]);
    croak "no tax for taxkey " . $transaction->{taxkey} unless ref $tax;

    $transaction->{chartlinks} = { map { $_ => 1 } split(m/:/, $transaction->chart_link) };
    if ( $is_sales && $transaction->{chartlinks}->{AR_amount} ) {
      $skonto_configured = 0 unless $tax->skonto_sales_chart_id;
    } elsif ( !$is_sales && $transaction->{chartlinks}->{AP_amount}) {
      $skonto_configured = 0 unless $tax->skonto_purchase_chart_id;
    };
  };

  return $skonto_configured;
};

sub open_sepa_transfer_amount {
  my $self = shift;

  my ($vc, $key, $type);
  if ( ref($self) eq 'SL::DB::Invoice' ) {
    $vc   = 'customer';
    $key  = 'ap_id';
    $type = 'ar';
  } else {
    $vc   = 'vendor';
    $key  = 'ap_id';
    $type = 'ap';
  };

  my $sql = qq|SELECT SUM(sei.amount) AS amount FROM sepa_export_items sei | .
            qq| LEFT JOIN sepa_export se ON (sei.sepa_export_id = se.id)   | .
            qq| WHERE $key = ? AND NOT se.closed AND (se.vc = '$vc')       |;

  my ($open_sepa_amount) = $self->db->dbh->selectrow_array($sql, undef, $self->id);

  return $open_sepa_amount || 0;

};


sub skonto_charts {
  my $self = shift;

  # TODO: use param for amount, may also want to calculate skonto_amounts by
  # passing percentage in the future

  my $amount = shift || $self->skonto_amount;

  croak "no amount passed to skonto_charts" unless abs(_round($amount)) >= 0.01;

  # TODO: check whether there are negative values in invoice / acc_trans ... credited items

  # don't check whether skonto applies, because user may want to override this
  # return undef unless $self->percent_skonto;  # for is_sales
  # return undef unless $self->vendor->payment_terms->percent_skonto;  # for purchase

  my $is_sales = ref($self) eq 'SL::DB::Invoice';

  my $mult = $is_sales ? 1 : -1;  # multiplier for getting the right sign

  my @skonto_charts;  # resulting array with all income/expense accounts that have to be corrected

  # calculate effective skonto (percentage) in difference_as_skonto mode
  # only works if there are no negative acc_trans values
  my $effective_skonto_rate = $amount ? $amount / $self->amount : 0;

  # checks:
  my $total_skonto_amount  = 0;
  my $total_rounding_error = 0;

  my $reference_ARAP_amount = 0;

  # my $transactions = $self->transactions;
  foreach my $transaction (@{ $self->transactions }) {
    # find all transactions with an AR_amount or AP_amount link
    $transaction->{chartlinks} = { map { $_ => 1 } split(m/:/, $transaction->{chart_link}) };
    # second condition is that we can determine an automatic Skonto account for each AR_amount entry

    if ( ( $is_sales && $transaction->{chartlinks}->{AR_amount} ) or ( !$is_sales && $transaction->{chartlinks}->{AP_amount}) ) {
        # $reference_ARAP_amount += $transaction->{amount} * $mult;

        # quick hack that works around problem of non-unique tax keys in SKR04
        # ? use tax_id in acc_trans
        my $tax = SL::DB::Manager::Tax->get_first( where => [id => $transaction->{tax_id}]);
        croak "no tax for taxkey " . $transaction->{taxkey} unless ref $tax;

        if ( $is_sales ) {
          die t8('no skonto_chart configured for taxkey #1 : #2 : #3', $transaction->{taxkey} , $tax->taxdescription , $tax->rate*100) unless ref $tax->skonto_sales_chart;
        } else {
          die t8('no skonto_chart configured for taxkey #1 : #2 : #3', $transaction->{taxkey} , $tax->taxdescription , $tax->rate*100) unless ref $tax->skonto_purchase_chart;
        };

        my $skonto_amount_unrounded;

        my $skonto_percent_abs = $self->amount ? abs($transaction->amount * (1 + $tax->rate) * 100 / $self->amount) : 0;

        my $transaction_amount = abs($transaction->{amount} * (1 + $tax->rate));
        my $transaction_skonto_percent = abs($transaction_amount/$self->amount); # abs($transaction->{amount} * (1 + $tax->rate));


        $skonto_amount_unrounded   = abs($amount * $transaction_skonto_percent);
        my $skonto_amount_rounded  = _round($skonto_amount_unrounded);
        my $rounding_error         = $skonto_amount_unrounded - $skonto_amount_rounded;
        my $rounded_rounding_error = _round($rounding_error);

        $total_rounding_error += $rounding_error;
        $total_skonto_amount  += $skonto_amount_rounded;

        my $rec = {
          # skonto_percent_abs: relative part of amount + tax to the total invoice amount
          'skonto_percent_abs'     => $skonto_percent_abs,
          'chart_id'               => $is_sales ? $tax->skonto_sales_chart->id : $tax->skonto_purchase_chart->id,
          'skonto_amount'          => $skonto_amount_rounded,
          # 'rounding_error'         => $rounding_error,
          # 'rounded_rounding_error' => $rounded_rounding_error,
        };

        push @skonto_charts, $rec;
      };
  };

  # if the rounded sum of all rounding_errors reaches 0.01 this sum is
  # subtracted from the largest skonto_amount
  my $rounded_total_rounding_error = abs(_round($total_rounding_error));

  if ( $rounded_total_rounding_error > 0 ) {
    my $highest_amount_pos = 0;
    my $highest_amount = 0;
    my $i = -1;
    foreach my $ref ( @skonto_charts ) {
      $i++;
      if ( $ref->{skonto_amount} > $highest_amount ) {
        $highest_amount     = $ref->{skonto_amount};
        $highest_amount_pos = $i;
      };
    };
    $skonto_charts[$i]->{skonto_amount} -= $rounded_total_rounding_error;
  };

  return @skonto_charts;
};


sub within_skonto_period {
  my $self = shift;
  my $dateref = shift || DateTime->now->truncate( to => 'day' );

  return undef unless ref $dateref eq 'DateTime';
  return 0 unless $self->skonto_date;

  # return 1 if requested date (or today) is inside skonto period
  # this will also return 1 if date is before the invoice date
  return $dateref <= $self->skonto_date;
};

sub valid_skonto_amount {
  my $self = shift;
  my $amount = shift || 0;
  my $max_skonto_percent = 0.10;

  return 0 unless $amount > 0;

  # does this work for other currencies?
  return ($self->amount*$max_skonto_percent) > $amount;
};

sub get_payment_select_options_for_bank_transaction {
  my ($self, $bt_id, %params) = @_;

  my $bt = SL::DB::Manager::BankTransaction->find_by( id => $bt_id );
  die unless $bt;

  my $open_amount = $self->open_amount;
  #$main::lxdebug->message(LXDebug->DEBUG2(),"skonto_date=".$self->skonto_date." open amount=".$open_amount);
  my @options;
  if ( $open_amount &&                   # invoice amount not 0
       $self->skonto_date &&             # check whether skonto applies
       ( abs(abs($self->amount_less_skonto) - abs($bt->amount)) < 0.01 ||
        ( abs($self->amount_less_skonto) < abs($bt->amount) )) &&
       $self->check_skonto_configuration) {
         if ( $self->within_skonto_period($bt->transdate) ) {
           push(@options, { payment_type => 'without_skonto', display => t8('without skonto') });
           push(@options, { payment_type => 'with_skonto_pt', display => t8('with skonto acc. to pt'), selected => 1 });
         } else {
           push(@options, { payment_type => 'without_skonto', display => t8('without skonto') , selected => 1 });
           push(@options, { payment_type => 'with_skonto_pt', display => t8('with skonto acc. to pt')});
         };
  };

  return @options;

};

sub exchangerate {
  my ($self) = @_;

  return 1 if $self->currency_id == $::instance_conf->get_currency_id;

  die "transdate isn't a DateTime object:" . ref($self->transdate) unless ref($self->transdate) eq 'DateTime';
  my $rate = SL::DB::Manager::Exchangerate->find_by(currency_id => $self->currency_id,
                                                    transdate   => $self->transdate,
                                                   );
  return undef unless $rate;

  return $self->is_sales ? $rate->buy : $rate->sell; # also undef if not defined
};

sub get_payment_suggestions {

  my ($self, %params) = @_;

  my $open_amount = $self->open_amount;
  $open_amount   -= $self->open_sepa_transfer_amount if $params{sepa};

  $self->{invoice_amount_suggestion} = $open_amount;
  undef $self->{payment_select_options};
  push(@{$self->{payment_select_options}} , { payment_type => 'without_skonto',  display => t8('without skonto') });
  if ( $self->within_skonto_period ) {
    # If there have been no payments yet suggest amount_less_skonto, otherwise the open amount
    if ( $open_amount &&                   # invoice amount not 0
         $open_amount == $self->amount &&  # no payments yet, or sum of payments and sepa export amounts is zero
         $self->check_skonto_configuration) {
      $self->{invoice_amount_suggestion} = $self->amount_less_skonto;
      push(@{$self->{payment_select_options}} , { payment_type => 'with_skonto_pt',  display => t8('with skonto acc. to pt') , selected => 1 });
    } else {
      if ( ( $self->valid_skonto_amount($self->open_amount) || $self->valid_skonto_amount($open_amount) ) and not $params{sepa} ) {
        $self->{invoice_amount_suggestion} = $open_amount;
        # only suggest difference_as_skonto if open_amount exactly matches skonto_amount
        # AND we aren't in SEPA mode
        my $selected = 0;
        $selected = 1 if _round($open_amount) == _round($self->skonto_amount);
        push(@{$self->{payment_select_options}} , { payment_type => 'difference_as_skonto',  display => t8('difference as skonto') , selected => $selected });
      };
    };
  } else {
    # invoice was configured with skonto, but skonto date has passed, or no skonto available
    $self->{invoice_amount_suggestion} = $open_amount;
    # difference_as_skonto doesn't make any sense for SEPA transfer, as this doesn't cause any actual payment
    if ( $self->valid_skonto_amount($self->open_amount) && not $params{sepa} ) {
      push(@{$self->{payment_select_options}} , { payment_type => 'difference_as_skonto',  display => t8('difference as skonto') , selected => 0 });
    };
  };
  return 1;
};

# locales for payment type
#
# $main::locale->text('without_skonto')
# $main::locale->text('with_skonto_pt')
# $main::locale->text('difference_as_skonto')
#

sub validate_payment_type {
  my $payment_type = shift;

  my %allowed_payment_types = map { $_ => 1 } qw(without_skonto with_skonto_pt difference_as_skonto);
  croak "illegal payment type: $payment_type, must be one of: " . join(' ', keys %allowed_payment_types) unless $allowed_payment_types{ $payment_type };

  return 1;
}

sub forex {
  my ($self) = @_;
  $self->currency_id == $::instance_conf->get_currency_id ? return 0 : return 1;
};

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
                   transdate     => DateTime->now->to_kivitendo,
                   memo          => 'foobar',
                   source        => 'barfoo',
                   payment_type  => 'with_skonto_pt',
                  );

Allowed payment types are:
  without_skonto with_skonto_pt difference_as_skonto

The option C<payment_type> allows for a basic skonto mechanism.

C<without_skonto> is the default mode, "amount" is paid to the account in
chart_id. This can also be used for partial payments and corrections via
negative amounts.

C<with_skonto_pt> can't be used for partial payments. When used on unpaid
invoices the whole amount is paid, with the skonto part automatically being
booked according to the skonto chart configured in the tax settings for each
tax key. If an amount is passed it is ignored and the actual configured skonto
amount is used.

C<difference_as_skonto> can only be used after partial payments have been made,
the whole specified amount is booked according to the skonto charts configured
in the tax settings for each tax key.

So passing amount doesn't have any effect for the cases C<with_skonto_pt> and
C<difference_as_skonto>, as all necessary values are taken from the stored
invoice.

The skonto modes automatically calculate the relative amounts for a mix of
taxes, e.g. items with 7% and 19% in one invoice. There is a helper method
skonto_charts, which calculates the relative percentages according to the
amounts in acc_trans (which are grouped by tax).

There is currently no way of excluding certain items in an invoice from having
skonto applied to them.  If this feature was added to parts the calculation
method of relative skonto would have to be completely rewritten using the
invoice items rather than acc_trans.

The skonto modes also still don't automatically correct the tax, this still has
to be done manually. Therefore all payments generated by pay_invoice have
taxkey 0.

There is currently no way to directly pay an invoice via this method if the
effective skonto differs from the skonto according to the payment terms
configured for the invoice/vendor.

In this case one has to pay in two steps: first the actual paid amount via
"without skonto", and then the remainder via "difference_as_skonto". The user
has to there actively decide whether to accept the differing skonto.

Because of the way skonto_charts works the calculation doesn't work if there
are negative values in acc_trans. E.g. one invoice with a positive value for
19% tax and a negative value for the acc_trans line with 7%

Skonto doesn't/shouldn't apply if the invoice contains credited items.

If no amount is given the whole open amout is paid.

If neither currency or currency_id are given as params, the currency of the
invoice is assumed to be the payment currency.

=item C<reference_account>

Returns a chart object which is the chart of the invoice with link AR or AP.

Example (1200 is the AR account for SKR04):
  my $invoice = invoice(invnumber => '144');
  $invoice->reference_account->accno
  # 1200

=item C<percent_skonto>

Returns the configured skonto percentage of the payment terms of an invoice,
e.g. 0.02 for 2%. Payment terms come from invoice settings for ar, from vendor
settings for ap.

=item C<amount_less_skonto>

If the invoice has a payment term (via ar for sales, via vendor for purchase),
calculate the amount to be paid in the case of skonto.  This doesn't check,
whether skonto applies (i.e. skonto doesn't wasn't exceeded), it just subtracts
the configured percentage (e.g. 2%) from the total amount.

The returned value is rounded to two decimals.

=item C<skonto_date>

The date up to which skonto may be taken. This is calculated from the invoice
date + the number of days configured in the payment terms.

This method can also be used to determine whether skonto applies for the
invoice, as it returns undef if there is no payment term or skonto days is set
to 0.

=item C<within_skonto_period [DATE]>

Returns 0 or 1.

Checks whether the invoice has payment terms configured, and whether the date
is within the skonto max date. If no date is passed the current date is used.

You can also pass a dateref object as a parameter to check whether skonto
applies for that date rather than the current date.

=item C<valid_skonto_amount>

Takes an amount as an argument and checks whether the amount is less than 10%
of the total amount of the invoice. The value of 10% is currently hardcoded in
the method. This method is currently used to check whether to offer the payment
option "difference as skonto".

Example:
 if ( $invoice->valid_skonto_amount($invoice->open_amount) ) {
   # ... do something
 }

=item C<skonto_charts [$amount]>

Returns a list of chart_ids and some calculated numbers that can be used for
paying the invoice with skonto. This function will automatically calculate the
relative skonto amounts even if the invoice contains several types of taxes
(e.g. 7% and 19%).

Example usage:
  my $invoice = SL::DB::Manager::Invoice->find_by(invnumber => '211');
  my @skonto_charts = $invoice->skonto_charts;

or with the total skonto amount as an argument:
  my @skonto_charts = $invoice->skonto_charts($invoice->open_amount);

The following values are generated for each chart:

=over 2

=item C<chart_id>

The chart id of the skonto amount to be booked.

=item C<skonto_amount>

The total amount to be paid to the account

=item C<skonto_percent>

The relative percentage of that skonto chart. This can be useful if the actual
ekonto that is paid deviates from the granted skonto, e.g. customer effectively
pays 2.6% skonto instead of 2%, and we accept this. Then we can still calculate
the relative skonto amounts for different taxes based on the absolute
percentages. Used for case C<difference_as_skonto>.

=item C<skonto_percent_abs>

The absolute percentage of that skonto chart in relation to the total amount.
Used to calculate skonto_amount for case C<with_skonto_pt>.

=back

If the invoice contains several types of taxes then skonto_charts can be used
to calculate the relative amounts.

Example in console of an invoice with 100 Euro at 7% and 100 Euro at 19% with
tax not included:

  my $invoice = invoice(invnumber => '144');
  $invoice->amount
  226.00000
  $invoice->payment_terms->percent_skonto
  0.02
  $invoice->skonto_charts
  pp $invoice->skonto_charts
  #             $VAR1 = {
  #               'chart_id'       => 128,
  #               'skonto_amount'  => '2.14',
  #               'skonto_percent' => '47.3451327433627'
  #             };
  #             $VAR2 = {
  #               'chart_id'       => 130,
  #               'skonto_amount'  => '2.38',
  #               'skonto_percent' => '52.654867256637'
  #             };

C<skonto_charts> always returns positive values (abs) for C<skonto_amount> and
C<skonto_percent>.

C<skonto_charts> generates one entry for each acc_trans entry. ar and ap
bookings only have one acc_trans entry for each taxkey (e.g. 7% and 19%).  This
is because all the items are grouped according to the Buchungsgruppen mechanism
and the totals are written to acc_trans.  For is and ir it is possible to have
several acc_trans entries with the same tax. In this case skonto_charts
generates a skonto booking for each acc_trans income/expense entry.

In the future this function may also be used to calculate the corrections for
the income tax.

=item C<open_amount>

Unrounded total open amount of invoice (amount - paid).
Doesn't take into account pending SEPA transfers.

=item C<open_percent>

Percentage of the invoice that is still unpaid, e.g. 100,00 if no payments have
been made yet, 0,00 if fully paid.

=item C<remaining_skonto_days>

How many days skonto can still be taken, calculated from current day. Returns 0
if current day is the max skonto date, and negative number if skonto date has
already passed.

Returns undef if skonto is not configured for that invoice.

=item C<get_payment_suggestions %params>

Creates data intended for an L.select_tag dropdown that can be used in a
template. Depending on the rules it will choose from the options
without_skonto, with_skonto_pt and difference_as_skonto, and select the most
likely one.

If the parameter "sepa" is passed, the SEPA export payments that haven't been
executed yet are considered when determining the open amount of the invoice.

The current rules are:

=over 2

=item * without_skonto is always an option

=item * with_skonto_pt is only offered if there haven't been any payments yet and the current date is within the skonto period.

=item * difference_as_skonto is only offered if there have already been payments made and the open amount is smaller than 10% of the total amount.

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

This is a helper function for BankTransaction/ajax_payment_suggestion.

We are working with an existing payment, so difference_as_skonto never makes sense.

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

=back

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.de<gt>

=cut
