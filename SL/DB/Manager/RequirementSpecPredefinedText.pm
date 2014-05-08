package SL::DB::Manager::RequirementSpecPredefinedText;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::RequirementSpecPredefinedText' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'position', 1 ],
    columns => {
      SIMPLE => 'ALL',
      map { ( $_ => "lower(requirement_spec_predefined_texts.${_})" ) } qw(description title),
    });
}

1;
