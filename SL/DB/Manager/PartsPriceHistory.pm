package SL::DB::Manager::PartsPriceHistory;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use SL::DB::Helper::Paginated;

sub object_class { 'SL::DB::PartsPriceHistory' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  (
    default  => [ 'valid_from', 0 ],
    columns  => {
      SIMPLE => 'ALL',
    },
  );
}

1;
