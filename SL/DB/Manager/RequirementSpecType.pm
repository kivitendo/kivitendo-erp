package SL::DB::Manager::RequirementSpecType;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::RequirementSpecType' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'position', 1 ],
    columns => {
      SIMPLE => 'ALL',
      map { ( $_ => "lower(requirement_spec_types.${_})" ) } qw(description),
    });
}

1;
