package SL::DB::InvoiceItem;

use strict;

use SL::DB::MetaSetup::InvoiceItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'invoice',
  cvars_alias => 1,
  overloads   => {
    parts_id => {
     class => 'SL::DB::Part',
     module => 'IC',
    },
  },
);

__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->add_relationships(
  invoice          => {
    type           => 'one to one',
    class          => 'SL::DB::Invoice',
    column_map     => { trans_id => 'id' },
  },

  purchase_invoice => {
    type           => 'one to one',
    class          => 'SL::DB::PurchaseInvoice',
    column_map     => { trans_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

1;
