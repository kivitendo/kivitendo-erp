package SL::DB::Manager::Pricegroup;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Pricegroup' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'pricegroup', 1 ],
           columns => { SIMPLE => 'ALL',
                        map { ( $_ => "lower(pricegroup.${_})" ) } qw(pricegroup),
                      });
}

1;
