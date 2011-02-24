package SL::DB::Manager::Buchungsgruppe;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Buchungsgruppe' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE      => 'ALL',
                        description => 'lower(description)',
                      });
}

1;
