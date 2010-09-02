package SL::DB::InvoiceItem;

use strict;

use SL::DB::MetaSetup::InvoiceItem;

__PACKAGE__->meta->add_relationship(
  part => {
    type         => 'one to one',
    class        => 'SL::DB::Part',
    column_map   => { parts_id => 'id' },
  }
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

1;
