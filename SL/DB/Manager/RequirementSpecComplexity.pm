package SL::DB::Manager::RequirementSpecComplexity;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::RequirementSpecComplexity' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'position', 1 ],
    columns => {
      SIMPLE => 'ALL',
      map { ( $_ => "lower(requirement_spec_complexities.${_})" ) } qw(description),
    });
}

1;
