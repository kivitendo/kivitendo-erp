package SL::DB::PeriodicInvoicesConfig;

use strict;

use SL::DB::MetaSetup::PeriodicInvoicesConfig;

__PACKAGE__->meta->add_relationships(
  order        => {
    type       => 'one to one',
    class      => 'SL::DB::Order',
    column_map => { oe_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
