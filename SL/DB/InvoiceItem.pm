package SL::DB::InvoiceItem;

use strict;

use SL::DB::MetaSetup::InvoiceItem;
use SL::DB::Helper::CustomVariables (
  sub_module  => 'invoice',
  cvars_alias => 1,
  overloads   => {
    parts_id => 'SL::DB::Part',
  },
);

__PACKAGE__->meta->add_relationship(
  part => {
    type         => 'one to one',
    class        => 'SL::DB::Part',
    column_map   => { parts_id => 'id' },
  },
  price_factor_obj => {
    type           => 'one to one',
    class          => 'SL::DB::PriceFactor',
    column_map     => { price_factor_id => 'id' },
  },
  unit_obj       => {
    type         => 'one to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

1;
