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
  unit_obj       => {
    type         => 'many to one',
    class        => 'SL::DB::Unit',
    column_map   => { unit => 'name' },
  },
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

sub part {
  # canonial alias for parts.
  goto &parts;
}

1;
