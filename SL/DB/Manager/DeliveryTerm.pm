package SL::DB::Manager::DeliveryTerm;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::DeliveryTerm' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL',
                        map { ( $_ => "lower(delivery_terms.${_})" ) } qw(description description_long),
                      });
}

sub get_valid {
  my ($class, $with_this_id) = @_;

  my @conditions = (obsolete => 0);

  if ($with_this_id) {
    @conditions = (
      or => [
        id => $with_this_id,
        @conditions,
      ]);
  }

  return $class->get_all_sorted(query => \@conditions);
}

1;
