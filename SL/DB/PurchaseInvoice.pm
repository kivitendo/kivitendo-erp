package SL::DB::PurchaseInvoice;

use strict;

use Carp;

use SL::DB::MetaSetup::PurchaseInvoice;
use SL::DB::Manager::PurchaseInvoice;
use SL::DB::Helper::LinkedRecords;
# The calculator hasn't been adjusted for purchase invoices yet.
# use SL::DB::Helper::PriceTaxCalculator;

__PACKAGE__->meta->add_relationship(
  invoiceitems   => {
    type         => 'one to many',
    class        => 'SL::DB::InvoiceItem',
    column_map   => { id => 'trans_id' },
    manager_args => { with_objects => [ 'part' ] }
  },
);

__PACKAGE__->meta->initialize;

sub items { goto &invoiceitems; }

sub is_sales {
  # For compatibility with Order, DeliveryOrder
  croak 'not an accessor' if @_ > 1;
  return 0;
}

sub date {
  goto &transdate;
}

1;
