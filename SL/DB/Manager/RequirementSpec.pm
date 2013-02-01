package SL::DB::Manager::RequirementSpec;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::RequirementSpec' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'title', 1 ],
    columns => {
      SIMPLE => 'ALL',
      customer      => 'lower(customer.name)',
      type          => 'type.position',
      status        => 'status.position',
      projectnumber => 'project.projectnumber',
      map { ( $_ => "lower(requirement_specs.${_})" ) } qw(title),
    });
}

1;
