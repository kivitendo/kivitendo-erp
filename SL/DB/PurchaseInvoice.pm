package SL::DB::PurchaseInvoice;

use strict;

use Carp;
use Data::Dumper;
use List::Util qw(sum);

use SL::DB::MetaSetup::PurchaseInvoice;
use SL::DB::Manager::PurchaseInvoice;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::Payment qw(:ALL);
use SL::DB::Helper::RecordLink qw(RECORD_ID RECORD_TYPE_REF RECORD_ITEM_ID RECORD_ITEM_TYPE_REF);
use SL::DB::Helper::SalesPurchaseInvoice;
use SL::DB::Helper::ZUGFeRD qw(:IMPORT);
use SL::Locale::String qw(t8);
use Rose::DB::Object::Helpers qw(has_loaded_related forget_related as_tree strip);

# The calculator hasn't been adjusted for purchase invoices yet.
# use SL::DB::Helper::PriceTaxCalculator;

__PACKAGE__->meta->add_relationship(
  invoiceitems   => {
    type         => 'one to many',
    class        => 'SL::DB::InvoiceItem',
    column_map   => { id => 'trans_id' },
    manager_args => { with_objects => [ 'part' ] }
  },
  sepa_export_items => {
    type            => 'one to many',
    class           => 'SL::DB::SepaExportItem',
    column_map      => { id => 'ap_id' },
    manager_args    => { with_objects => [ 'sepa_export' ] }
  },
  sepa_exports      => {
    type            => 'many to many',
    map_class       => 'SL::DB::SepaExportItem',
    map_from        => 'ap',
    map_to          => 'sepa_export',
  },
  custom_shipto     => {
    type            => 'one to one',
    class           => 'SL::DB::Shipto',
    column_map      => { id => 'trans_id' },
    query_args      => [ module => 'AP' ],
  },
  transactions   => {
    type         => 'one to many',
    class        => 'SL::DB::AccTransaction',
    column_map   => { id => 'trans_id' },
    manager_args => { with_objects => [ 'chart' ],
                      sort_by      => 'acc_trans_id ASC' }
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_html('notes');
__PACKAGE__->attr_sorted('items');

__PACKAGE__->after_save('_after_save_link_records');

# hooks

sub _after_save_link_records {
  my ($self) = @_;

  my @allowed_record_sources = qw(SL::DB::Reclamation SL::DB::Order);
  my @allowed_item_sources = qw(SL::DB::ReclamationItem SL::DB::OrderItem);

  SL::DB::Helper::RecordLink::link_records(
    $self,
    \@allowed_record_sources,
    \@allowed_item_sources,
    close_source_quotations => 1,
  );
}

# methods

sub items { goto &invoiceitems; }
sub add_items { goto &add_invoiceitems; }
sub record_number { goto &invnumber; }
sub record_type { goto &invoice_type; }

sub is_sales {
  # For compatibility with Order, DeliveryOrder
  croak 'not an accessor' if @_ > 1;
  return 0;
}

sub date {
  goto &transdate;
}

sub reqdate {
  goto &duedate;
}

sub customervendor {
  goto &vendor;
}

sub abbreviation {
  my $self = shift;

  return t8('AP Transaction (abbreviation)') if !$self->invoice && !$self->storno;
  return t8('AP Transaction (abbreviation)') . '(' . t8('Storno (one letter abbreviation)') . ')' if !$self->invoice && $self->storno;
  return t8('Invoice (one letter abbreviation)'). '(' . t8('Storno (one letter abbreviation)') . ')' if $self->storno;
  return t8('Invoice (one letter abbreviation)');

}

sub oneline_summary {
  my $self = shift;

  return sprintf("%s: %s %s %s (%s)", $self->abbreviation, $self->invnumber, $self->vendor->name,
                                      $::form->format_amount(\%::myconfig, $self->amount,2), $self->transdate->to_kivitendo);
}

sub link {
  my ($self) = @_;

  my $html;
  $html   = $self->presenter->purchase_invoice(display => 'inline') if $self->invoice;
  $html   = $self->presenter->ap_transaction(display => 'inline') if !$self->invoice;

  return $html;
}

sub invoice_type {
  my ($self) = @_;

  return 'purchase_credit_note'  if  $self->amount < 0;
  return 'ap_transaction'        if !$self->invoice;
  return 'purchase_invoice';
}
sub is_credit_note {
  my ($self) = @_;

  return $self->invoice_type eq 'purchase_credit_note' ? 1 : undef;
}

sub displayable_type {
  my ($self) = @_;

  return t8('AP Transaction')    if $self->invoice_type eq 'ap_transaction';
  return t8('Purchase Invoice');
}

sub displayable_name {
  join ' ', grep $_, map $_[0]->$_, qw(displayable_type record_number);
}

sub convert_to_reclamation {
  my ($self, %params) = @_;
  $params{destination_type} = $self->is_sales ? 'sales_reclamation'
                                              : 'purchase_reclamation';

  require SL::DB::Reclamation;
  my $reclamation = SL::DB::Reclamation->new_from($self, %params);

  return $reclamation;
}

sub create_from_zugferd_data {
  my ($class, $data) = @_;

  my $ap_invoice = $class->new();

  $ap_invoice->import_zugferd_data($data);
}

sub create_ap_row {
  my ($self, %params) = @_;
  # needs chart as param
  # to be called after adding all AP_amount rows

  # only allow this method for ap invoices (Kreditorenbuchung)
  die if $self->invoice and not $self->vendor_id;

  return 0 unless scalar @{$self->transactions} > 0;

  my $acc_trans = [];
  my $chart = $params{chart} || SL::DB::Manager::Chart->find_by(id => $::instance_conf->get_ap_chart_id);
  die "illegal chart in create_ap_row" unless $chart;

  die "receivables chart must have link 'AP'" . Dumper($chart) unless $chart->link eq 'AP';

  # hardcoded entry for no tax, tax_id and taxkey should be 0
  my $tax = SL::DB::Manager::Tax->find_by(id => 0, taxkey => 0) || die "Can't find tax with id 0 and taxkey 0";

  my $sign = $self->vendor_id ? 1 : -1;
  my $acc = SL::DB::AccTransaction->new(
    amount     => $self->amount * $sign,
    chart_id   => $params{chart}->id,
    chart_link => $params{chart}->link,
    transdate  => $self->transdate,
    taxkey     => $tax->taxkey,
    tax_id     => $tax->id,
  );
  $self->add_transactions( $acc );
  push( @$acc_trans, $acc );
  return $acc_trans;
}

sub add_ap_amount_row {
  my ($self, %params ) = @_;

  # only allow this method for ap invoices (Kreditorenbuchung)
  die "not an ap invoice" if $self->invoice and not $self->vendor_id;

  die "add_ap_amount_row needs a chart object as chart param" unless $params{chart} && $params{chart}->isa('SL::DB::Chart');
  die unless $params{chart}->link =~ /AP_amount/;

  my $acc_trans = [];

  my $roundplaces = 2;
  my ($netamount,$taxamount);

  $netamount = $params{amount} * 1;
  my $tax = SL::DB::Manager::Tax->find_by(id => $params{tax_id}) || die "Can't find tax with id " . $params{tax_id};

  if ( $tax and $tax->rate != 0 ) {
    ($netamount, $taxamount) = Form->calculate_tax($params{amount}, $tax->rate, $self->taxincluded, $roundplaces);
  }

  return unless $netamount; # netamount mustn't be zero

  my $sign = $self->vendor_id ? -1 : 1;
  my $acc = SL::DB::AccTransaction->new(
    amount     => $netamount * $sign,
    chart_id   => $params{chart}->id,
    chart_link => $params{chart}->link,
    transdate  => $self->transdate,
    gldate     => $self->gldate,
    taxkey     => $tax->taxkey,
    tax_id     => $tax->id,
    project_id => $params{project_id},
  );

  $self->add_transactions( $acc );
  push( @$acc_trans, $acc );

  if ( $taxamount ) {
     my $acc = SL::DB::AccTransaction->new(
       amount     => $taxamount * $sign,
       chart_id   => $tax->chart_id,
       chart_link => $tax->chart->link,
       transdate  => $self->transdate,
       gldate     => $self->gldate,
       taxkey     => $tax->taxkey,
       tax_id     => $tax->id,
       project_id => $params{project_id},
     );
     $self->add_transactions( $acc );
     push( @$acc_trans, $acc );
  }
  return $acc_trans;
}

sub validate_acc_trans {
  my ($self, %params) = @_;
  # should be able to check unsaved invoice objects with several acc_trans lines

  die "validate_acc_trans can't check invoice object with empty transactions" unless $self->transactions;

  my @transactions = @{$self->transactions};
  # die "invoice has no acc_transactions" unless scalar @transactions > 0;

  return 0 unless scalar @transactions > 0;
  return 0 unless $self->has_loaded_related('transactions');

  $::lxdebug->message(LXDebug->DEBUG1(), sprintf("starting validatation of purchase invoice %s with trans_id %s and taxincluded %s\n", $self->invnumber // '', $self->id // '', $self->taxincluded // ''));
  foreach my $acc ( @transactions ) {
    $::lxdebug->message(LXDebug->DEBUG1(), sprintf("chart: %s  amount: %s   tax_id: %s  link: %s\n", $acc->chart->accno, $acc->amount, $acc->tax_id, $acc->chart->link));
  }

  my $acc_trans_sum = sum map { $_->amount } @transactions;

  unless ( $::form->round_amount($acc_trans_sum, 10) == 0 ) {
    my $string = "sum of acc_transactions isn't 0: $acc_trans_sum\n";

    foreach my $trans ( @transactions ) {
      $string .= sprintf("  %s %s %s\n", $trans->chart->accno, $trans->taxkey, $trans->amount);
    }
    $::lxdebug->message(LXDebug->DEBUG1(), $string);
    return 0;
  }

  # only use the first AP entry, so it also works for paid invoices
  my @ap_transactions = map { $_->amount } grep { $_->chart_link eq 'AP' } @transactions;
  my $ap_sum = $ap_transactions[0];
  # my $ap_sum = sum map { $_->amount } grep { $_->chart_link eq 'AP' } @transactions;

  my $sign = $self->vendor_id ? 1 : -1;

  unless ( $::form->round_amount($ap_sum * $sign, 2) == $::form->round_amount($self->amount, 2) ) {

    $::lxdebug->message(LXDebug->DEBUG1(), sprintf("debug: (ap_sum) %s = %s (amount)\n",  $::form->round_amount($ap_sum * $sign, 2) , $::form->round_amount($self->amount, 2) ) );
    foreach my $trans ( @transactions ) {
      $::lxdebug->message(LXDebug->DEBUG1(), sprintf("  %s %s %s %s\n", $trans->chart->accno, $trans->taxkey, $trans->amount, $trans->chart->link));
    }

    die sprintf("sum of ap (%s) isn't equal to invoice amount (%s)", $::form->round_amount($ap_sum * $sign, 2), $::form->round_amount($self->amount, 2));
  }

  return 1;
}

sub recalculate_amounts {
  my ($self, %params) = @_;
  # calculate and set amount and netamount from acc_trans objects

  croak ("Can only recalculate amounts for ap transactions") if $self->invoice;

  return undef unless $self->has_loaded_related('transactions');

  my ($netamount, $taxamount);

  my @transactions = @{$self->transactions};

  foreach my $acc ( @transactions ) {
    $netamount += $acc->amount if $acc->chart->link =~ /AP_amount/;
    $taxamount += $acc->amount if $acc->chart->link =~ /AP_tax/;
  }

  my $sign = $self->vendor_id ? -1 : 1;
  $self->amount   (($netamount + $taxamount) * $sign);
  $self->netamount(($netamount)              * $sign);
}

sub mark_as_paid {
  my ($self) = @_;

  $self->update_attributes(paid => $self->amount);
}

sub effective_tax_point {
  my ($self) = @_;

  return $self->tax_point || $self->deliverydate || $self->transdate;
}

sub netamount_base_currency {
  my ($self) = @_;

  return $self->netamount; # already matches base currency
}

1;


__END__

=pod

=encoding UTF-8

=head1 NAME

SL::DB::PurchaseInvoice: Rose model for purchase invoices (table "ap")

=head1 FUNCTIONS

=over 4

=item C<create_ap_row>

=item C<add_ap_amount_row>

=item C<validate_acc_trans>

=item C<recalculate_amounts>

These functions are similar to the ones in the C<SL::DB::Invoice> module. See
there for more information.

=item C<mark_as_paid>

Marks the invoice as paid by setting its C<paid> member to the value of C<amount>.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
