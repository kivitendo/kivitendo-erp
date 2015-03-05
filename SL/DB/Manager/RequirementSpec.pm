package SL::DB::Manager::RequirementSpec;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Filtered;
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

sub working_copy_filter {
  return (working_copy_id => undef);
}

sub not_empty_filter {
  my @tables = qw(requirement_spec_items requirement_spec_text_blocks requirement_spec_parts);
  my @filter = map { \"id IN (SELECT nef_${_}.requirement_spec_id FROM ${_} nef_${_})" } @tables;

  return (or => \@filter);
}

1;
