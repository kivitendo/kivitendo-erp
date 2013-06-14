package SL::DB::Warehouse;

use strict;

use SL::DB::MetaSetup::Warehouse;
use SL::DB::Manager::Warehouse;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->add_relationship(
  bins => {
    type         => 'one to many',
    class        => 'SL::DB::Bin',
    column_map   => { id => 'warehouse_id' },
  }
);

__PACKAGE__->meta->initialize;

sub bins_sorted {
  return [ sort { $a->id <=> $b->id } @{ shift()->bins || [] } ];
}

sub first_bin {
  return shift()->bins_sorted->[0];
}

1;
