# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::TSEterminal;

use strict;

use SL::DB::Helper::Sorted;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::TSEterminal' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'name', 1 ],
  );
}

1;
