package SL::DB::Manager::Currency;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Currency' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'id', 1 ],
           columns => { SIMPLE => 'ALL',
                        map { ( $_ => "lower(currencies.$_)" ) } qw(name)
                      });
}

1;
