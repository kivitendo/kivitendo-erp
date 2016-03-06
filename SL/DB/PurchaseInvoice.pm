package SL::DB::PurchaseInvoice;

use strict;

use Carp;

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

sub link {
  my ($self) = @_;

  my $html;
  $html   = SL::Presenter->get->purchase_invoice($self, display => 'inline') if $self->invoice;
  $html   = SL::Presenter->get->ap_transaction($self, display => 'inline') if !$self->invoice;

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

1;
