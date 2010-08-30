package SL::DB::Customer;

use strict;

use SL::DB::MetaSetup::Customer;

use SL::DB::VC;

__PACKAGE__->meta->add_relationship(
  shipto => {
    type         => 'one to many',
    class        => 'SL::DB::Shipto',
    column_map   => { id      => 'trans_id' },
    manager_args => { sort_by => 'lower(shipto.shiptoname)' },
    query_args   => [ 'shipto.module' => 'CT' ],
  },
  business => {
    type         => 'one to one',
    class        => 'SL::DB::Business',
    column_map   => { business_id => 'id' },
  },
);

__PACKAGE__->meta->make_manager_class;
__PACKAGE__->meta->initialize;

1;
