package SL::DB::PeriodicInvoice;

use strict;

use SL::DB::MetaSetup::PeriodicInvoice;

__PACKAGE__->meta->add_relationships(
  invoice      => {
    type       => 'many to one',
    class      => 'SL::DB::Invoice',
    column_map => { ar_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

1;
