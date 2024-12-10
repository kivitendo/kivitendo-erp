# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::BankTransaction;

use strict;

use SL::DB::MetaSetup::BankTransaction;
use SL::DB::Manager::BankTransaction;
use SL::DB::Helper::LinkedRecords;
use Carp;

require SL::DB::Invoice;
require SL::DB::PurchaseInvoice;

__PACKAGE__->meta->initialize;


# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
#__PACKAGE__->meta->make_manager_class;

sub compare_to {
  my ($self, $other) = @_;

  return  1 if  $self->transdate && !$other->transdate;
  return -1 if !$self->transdate &&  $other->transdate;

  my $result = 0;
  $result    = $self->transdate <=> $other->transdate if $self->transdate;
  return $result || ($self->id <=> $other->id);
}

sub linked_invoices {
  my ($self) = @_;

  #my $record_links = $self->linked_records(direction => 'both');

  my @linked_invoices;

  my $record_links = SL::DB::Manager::RecordLink->get_all(where => [ from_table => 'bank_transactions', from_id => $self->id ]);

  foreach my $record_link (@{ $record_links }) {
    push @linked_invoices, SL::DB::Manager::Invoice->find_by(id => $record_link->to_id)         if $record_link->to_table eq 'ar';
    push @linked_invoices, SL::DB::Manager::PurchaseInvoice->find_by(id => $record_link->to_id) if $record_link->to_table eq 'ap';
    push @linked_invoices, SL::DB::Manager::GLTransaction->find_by(id => $record_link->to_id)   if $record_link->to_table eq 'gl';
  }

  return [ @linked_invoices ];
}

sub is_batch_transaction {
  ($_[0]->transaction_code // '') eq "191";
}


sub get_agreement_with_invoice {
  my ($self, $invoice, %params) = @_;

  carp "get_agreement_with_invoice needs an invoice object as its first argument"
    unless ref($invoice) eq 'SL::DB::Invoice' or ref($invoice) eq 'SL::DB::PurchaseInvoice';

  my %points = (
    cust_vend_name_in_purpose   => 1,
    cust_vend_number_in_purpose => 1,
    datebonus0                  => 3,
    datebonus14                 => 2,
    datebonus35                 => 1,
    datebonus120                => 0,
    datebonus_negative          => -1,
    depositor_matches           => 2,
    exact_amount                => 4,
    exact_open_amount           => 4,
    invoice_in_purpose          => 2,
    own_invoice_in_purpose      => 5,
    invnumber_in_purpose        => 1,
    own_invnumber_in_purpose    => 4,
    # overpayment                 => -1, # either other invoice is more likely, or several invoices paid at once
    payment_before_invoice      => -2,
    payment_within_30_days      => 1,
    remote_account_number       => 3,
    skonto_exact_amount         => 5,
    skonto_fuzzy_amount         => 3,
    wrong_sign                  => -4,
    sepa_export_item            => 5,
    end_to_end_id               => 8,
    batch_sepa_transaction      => 20,
    qr_reference                => 20,
  );

  my ($agreement,$rule_matches);

  if ( $self->is_batch_transaction && $self->{sepa_export_ok}) {
    $agreement += $points{batch_sepa_transaction};
    $rule_matches .= 'batch_sepa_transaction(' . $points{'batch_sepa_transaction'} . ') ';
  }

  # check swiss qr reference if feature enabled
  if ($::instance_conf->get_create_qrbill_invoices == 1) {
    if ($self->{qr_reference} && $invoice->{qr_reference} &&
        $self->{qr_reference} eq $invoice->{qr_reference}) {

      $agreement += $points{qr_reference};
      $rule_matches .= 'qr_reference(' . $points{'qr_reference'} . ') ';
    }
  }

  # compare banking arrangements
  my ($iban, $bank_code, $account_number);
  $bank_code      = $invoice->customer->bank_code      if $invoice->is_sales;
  $account_number = $invoice->customer->account_number if $invoice->is_sales;
  $iban           = $invoice->customer->iban           if $invoice->is_sales;
  $bank_code      = $invoice->vendor->bank_code        if ! $invoice->is_sales;
  $iban           = $invoice->vendor->iban             if ! $invoice->is_sales;
  $account_number = $invoice->vendor->account_number   if ! $invoice->is_sales;

  # check only valid remote_account_number (with some content)
  if ($self->remote_account_number) {
    if ($bank_code eq $self->remote_bank_code && $account_number eq $self->remote_account_number) {
      $agreement += $points{remote_account_number};
      $rule_matches .= 'remote_account_number(' . $points{'remote_account_number'} . ') ';
    } elsif ($iban eq $self->remote_account_number) { # elsif -> do not add twice
      $agreement += $points{remote_account_number};
      $rule_matches .= 'remote_account_number(' . $points{'remote_account_number'} . ') ';
    }
  }

  my $datediff = $self->transdate->{utc_rd_days} - $invoice->transdate->{utc_rd_days};
  $invoice->{datediff} = $datediff;

  # compare amount
  if (abs(abs($invoice->amount) - abs($self->amount)) < 0.01 &&
        $::form->format_amount(\%::myconfig,abs($invoice->amount),2) eq
        $::form->format_amount(\%::myconfig,abs($self->amount),2)
      ) {
    $agreement += $points{exact_amount};
    $rule_matches .= 'exact_amount(' . $points{'exact_amount'} . ') ';
  }

  # compare open amount, preventing double points when open amount = invoice amount
  if ( $invoice->amount != $invoice->open_amount && abs(abs($invoice->open_amount) - abs($self->amount)) < 0.01 &&
         $::form->format_amount(\%::myconfig,abs($invoice->open_amount),2) eq
         $::form->format_amount(\%::myconfig,abs($self->amount),2)
       ) {
    $agreement += $points{exact_open_amount};
    $rule_matches .= 'exact_open_amount(' . $points{'exact_open_amount'} . ') ';
  }

  if ( $invoice->skonto_date && abs(abs($invoice->amount_less_skonto) - abs($self->amount)) < 0.01 &&
         $::form->format_amount(\%::myconfig,abs($invoice->amount_less_skonto),2) eq
         $::form->format_amount(\%::myconfig,abs($self->amount),2)
       ) {
    $agreement += $points{skonto_exact_amount};
    $rule_matches .= 'skonto_exact_amount(' . $points{'skonto_exact_amount'} . ') ';
    $invoice->{skonto_type} = 'with_skonto_pt';
  } elsif (   $::instance_conf->get_fuzzy_skonto
           && $invoice->skonto_date && $::instance_conf->get_fuzzy_skonto_percentage > 0
           && abs(abs($invoice->amount_less_skonto) - abs($self->amount))
              < abs($invoice->amount / (100 / $::instance_conf->get_fuzzy_skonto_percentage))) {
    # we have a skonto within the range of fuzzy skonto percentage (default 0.5%)
    $agreement += $points{skonto_fuzzy_amount};
    $rule_matches .= 'skonto_fuzzy_amount(' . $points{'skonto_fuzzy_amount'} . ') ';
    $invoice->{skonto_type} = 'with_fuzzy_skonto_pt';
  }

  #search invoice number in purpose
  my $invnumber = $invoice->invnumber;
  # invnumber has to have at least 3 characters
  my $squashed_purpose = $self->purpose;
  $squashed_purpose =~ s/ //g;
  if (length($invnumber) > 4 && $squashed_purpose =~ /\Q$invnumber/ && $invoice->is_sales){
    $agreement      += $points{own_invoice_in_purpose};
    $rule_matches   .= 'own_invoice_in_purpose(' . $points{'own_invoice_in_purpose'} . ') ';
  } elsif (length($invnumber) > 3 && $squashed_purpose =~ /\Q$invnumber/ ) {
    $agreement      += $points{invoice_in_purpose};
    $rule_matches   .= 'invoice_in_purpose(' . $points{'invoice_in_purpose'} . ') ';
  } else {
    # only check number part of invoice number
    $invnumber      =~ s/[A-Za-z_]+//g;
    if (length($invnumber) > 4 && $squashed_purpose =~ /\Q$invnumber/ && $invoice->is_sales){
      $agreement    += $points{own_invnumber_in_purpose};
      $rule_matches .= 'own_invnumber_in_purpose(' . $points{'own_invnumber_in_purpose'} . ') ';
    } elsif (length($invnumber) > 3 && $squashed_purpose =~ /\Q$invnumber/ ) {
      $agreement    += $points{invnumber_in_purpose};
      $rule_matches .= 'invnumber_in_purpose(' . $points{'invnumber_in_purpose'} . ') ';
    }
  }

  #check sign
  if (( $invoice->is_sales && $invoice->amount > 0 && $self->amount < 0 ) ||
      ( $invoice->is_sales && $invoice->amount < 0 && $self->amount > 0 )     ) { # sales credit note
    $agreement += $points{wrong_sign};
    $rule_matches .= 'wrong_sign(' . $points{'wrong_sign'} . ') ';
  }
  if (( !$invoice->is_sales && $invoice->amount > 0 && $self->amount > 0)  ||
      ( !$invoice->is_sales && $invoice->amount < 0 && $self->amount < 0)     ) { # purchase credit note
    $agreement += $points{wrong_sign};
    $rule_matches .= 'wrong_sign(' . $points{'wrong_sign'} . ') ';
  }

  # search customer/vendor number in purpose
  my $cvnumber;
  $cvnumber = $invoice->customer->customernumber if $invoice->is_sales;
  $cvnumber = $invoice->vendor->vendornumber     if ! $invoice->is_sales;
  if ( $cvnumber && $self->purpose =~ /\b$cvnumber\b/i ) {
    $agreement += $points{cust_vend_number_in_purpose};
    $rule_matches .= 'cust_vend_number_in_purpose(' . $points{'cust_vend_number_in_purpose'} . ') ';
  }

  # search for customer/vendor name in purpose (may contain GMBH, CO KG, ...)
  my $cvname;
  $cvname = $invoice->customer->name if $invoice->is_sales;
  $cvname = $invoice->vendor->name   if ! $invoice->is_sales;
  if ( $cvname && $self->purpose =~ /\b\Q$cvname\E\b/i ) {
    $agreement += $points{cust_vend_name_in_purpose};
    $rule_matches .= 'cust_vend_name_in_purpose(' . $points{'cust_vend_name_in_purpose'} . ') ';
  }

  # compare depositorname, don't try to match empty depositors
  my $depositorname;
  $depositorname = $invoice->customer->depositor if $invoice->is_sales;
  $depositorname = $invoice->vendor->depositor   if ! $invoice->is_sales;
  if ( $depositorname && $self->remote_name =~ /\Q$depositorname/ ) {
    $agreement += $points{depositor_matches};
    $rule_matches .= 'depositor_matches(' . $points{'depositor_matches'} . ') ';
  }

  #Check if words in remote_name appear in cvname
  my $check_string_points = _check_string($self->remote_name,$cvname);
  if ( $check_string_points ) {
    $agreement += $check_string_points;
    $rule_matches .= 'remote_name(' . $check_string_points . ') ';
  }

  # transdate prefilter: compare transdate of bank_transaction with transdate of invoice
  if ( $datediff < -5 ) { # this might conflict with advance payments
    $agreement += $points{payment_before_invoice};
    $rule_matches .= 'payment_before_invoice(' . $points{'payment_before_invoice'} . ') ';
  }
  if ( $datediff < 30 ) {
    $agreement += $points{payment_within_30_days};
    $rule_matches .= 'payment_within_30_days(' . $points{'payment_within_30_days'} . ') ';
  }

  # only if we already have a good agreement, let date further change value of agreement.
  # this is so that if there are several plausible open invoices which are all equal
  # (rent jan, rent feb...) the one with the best date match is chosen over
  # the others

  # another way around this is to just pre-filter by periods instead of matching everything
  if ( $agreement > 5 ) {
    if ( $datediff == 0 ) {
      $agreement += $points{datebonus0};
      $rule_matches .= 'datebonus0(' . $points{'datebonus0'} . ') ';
    } elsif  ( $datediff > 0 and $datediff <= 14 ) {
      $agreement += $points{datebonus14};
      $rule_matches .= 'datebonus14(' . $points{'datebonus14'} . ') ';
    } elsif  ( $datediff >14 and $datediff < 35) {
      $agreement += $points{datebonus35};
      $rule_matches .= 'datebonus35(' . $points{'datebonus35'} . ') ';
    } elsif  ( $datediff >34 and $datediff < 120) {
      $agreement += $points{datebonus120};
      $rule_matches .= 'datebonus120(' . $points{'datebonus120'} . ') ';
    } elsif  ( $datediff < 0 ) {
      $agreement += $points{datebonus_negative};
      $rule_matches .= 'datebonus_negative(' . $points{'datebonus_negative'} . ') ';
    } else {
      # e.g. datediff > 120
    }
  }

  # if there is exactly one non-executed sepa_export_item for the invoice
  my $seis = $params{sepa_export_items}
           ? [ grep { $invoice->id == ($invoice->is_sales ? $_->ar_id : $_->ap_id) } @{ $params{sepa_export_items} } ]
           : $invoice->find_sepa_export_items({ executed => 0 });
  if ($seis) {
    if (scalar @$seis == 1) {
      my $sei = $seis->[0];
      # test for end to end id
      if ($self->end_to_end_id && $self->end_to_end_id eq $sei->end_to_end_id) {
        $agreement    += $points{end_to_end_id};
        $rule_matches .= 'end_to_end_id(' . $points{'end_to_end_id'} . ') ';
      }

      # test for amount and id matching only, sepa transfer date and bank
      # transaction date needn't match
      if (abs($self->amount) == ($sei->amount)) {
        $agreement    += $points{sepa_export_item};
        $rule_matches .= 'sepa_export_item(' . $points{'sepa_export_item'} . ') ';
      }
    } else {
      # zero or more than one sepa_export_item, do nothing for this invoice
      # zero: do nothing, no sepa_export_item exists, no match
      # more than one: does this ever apply? Currently you can't create sepa
      # exports for invoices that already have a non-executed sepa_export
      # TODO: Catch the more than one case. User is allowed to split
      # payments for one invoice item in one sepa export.
    }
  }

  return ($agreement,$rule_matches);
};

sub _check_string {
    my $bankstring = shift;
    my $namestring = shift;
    return 0 unless $bankstring and $namestring;

    my @bankwords = grep(/^\w+$/, split(/\b/,$bankstring));

    my $match = 0;
    foreach my $bankword ( @bankwords ) {
        # only try to match strings with more than 2 characters
        next unless length($bankword)>2;
        if ( $namestring =~ /\b$bankword\b/i ) {
            $match++;
        };
    };
    return $match;
};


sub not_assigned_amount {
  my ($self) = @_;

  my $not_assigned_amount = $self->amount - $self->invoice_amount;
  die ("undefined state") if (abs($not_assigned_amount) > abs($self->amount));

  return $not_assigned_amount;

}
sub closed_period {
  my ($self) = @_;

  # check for closed period
  croak t8('Illegal date') unless ref $self->valutadate eq 'DateTime';


  my $closedto = $::locale->parse_date_to_object($::instance_conf->get_closedto);
  if ( ref $closedto && $self->valutadate < $closedto ) {
    return 1;
  } else {
    return 0;
  }
}
1;

__END__

=pod

=head1 NAME

SL::DB::BankTransaction

=head1 FUNCTIONS

=over 4

=item C<get_agreement_with_invoice $invoice>

Using a point system this function checks whether the bank transaction matches
an invoices, using a variety of tests, such as

=over 2

=item * amount

=item * amount_less_skonto

=item * payment date

=item * invoice number in purpose

=item * customer or vendor name in purpose

=item * account number matches account number of customer or vendor

=back

The total number of points, and the rules that matched, are returned.

Example:
  my $bt      = SL::DB::Manager::BankTransaction->find_by(id => 522);
  my $invoice = SL::DB::Manager::Invoice->find_by(invnumber => '198');
  my ($agreement,rule_matches) = $bt->get_agreement_with_invoice($invoice);

=item C<linked_invoices>

Returns an array of record objects (invoices, debit, credit or gl objects)
which are linked for this bank transaction.

Returns an empty array ref if no links are found.
Usage:
 croak("No linked records at all") unless @{ $bt->linked_invoices() };


=item C<not_assigned_amount>

Returns the not open amount of this bank transaction.
Dies if the return amount is higher than the original amount.

=item C<closed_period>

Returns 1 if the bank transaction valutadate is in a closed period, 0 if the
valutadate of the bank transaction is not in a closed period.

=back

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.de<gt>

=cut
