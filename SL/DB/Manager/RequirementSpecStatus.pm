package SL::DB::Manager::RequirementSpecStatus;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::RequirementSpecStatus' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'position', 1 ],
    columns => {
      SIMPLE => 'ALL',
      map { ( $_ => "lower(requirement_spec_statuses.${_})" ) } qw(name description),
    });
}

1;
