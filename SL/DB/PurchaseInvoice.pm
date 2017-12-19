package SL::DB::PurchaseInvoice;

use strict;

use Carp;
use Data::Dumper;

use SL::DB::MetaSetup::PurchaseInvoice;
use SL::DB::Manager::PurchaseInvoice;
use SL::DB::Helper::AttrHTML;
use SL::DB::Helper::AttrSorted;
use SL::DB::Helper::LinkedRecords;
use SL::DB::Helper::Payment qw(:ALL);
use SL::Locale::String qw(t8);
use Rose::DB::Object::Helpers qw(has_loaded_related forget_related);

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

sub items { goto &invoiceitems; }
sub add_items { goto &add_invoiceitems; }
sub record_number { goto &invnumber; };

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

};

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

  return 'ap_transaction' if !$self->invoice;
  return 'purchase_invoice';
}

sub displayable_type {
  my ($self) = @_;

  return t8('AP Transaction')    if $self->invoice_type eq 'ap_transaction';
  return t8('Purchase Invoice');
}

sub displayable_name {
  join ' ', grep $_, map $_[0]->$_, qw(displayable_type record_number);
};

sub create_ap_row {
  my ($self, %params) = @_;
  # needs chart as param
  # to be called after adding all AP_amount rows

  # only allow this method for ap invoices (Kreditorenbuchung)
  die if $self->invoice and not $self->vendor_id;

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
};

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
  };
  next unless $netamount; # netamount mustn't be zero

  my $sign = $self->vendor_id ? -1 : 1;
  my $acc = SL::DB::AccTransaction->new(
    amount     => $netamount * $sign,
    chart_id   => $params{chart}->id,
    chart_link => $params{chart}->link,
    transdate  => $self->transdate,
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
       taxkey     => $tax->taxkey,
       tax_id     => $tax->id,
       project_id => $params{project_id},
     );
     $self->add_transactions( $acc );
     push( @$acc_trans, $acc );
  };
  return $acc_trans;
};

sub mark_as_paid {
  my ($self) = @_;

  $self->update_attributes(paid => $self->amount);
}

1;


__END__

=pod

=encoding UTF-8

=head1 NAME

SL::DB::PurchaseInvoice: Rose model for purchase invoices (table "ap")

=head1 FUNCTIONS

=over 4

=item C<mark_as_paid>

Marks the invoice as paid by setting its C<paid> member to the value of C<amount>.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
