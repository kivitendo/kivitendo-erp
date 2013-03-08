package SL::DB::RequirementSpecItem;

use strict;

use SL::DB::MetaSetup::RequirementSpecItem;
use SL::DB::Manager::RequirementSpecItem;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::AttrDuration;

__PACKAGE__->meta->add_relationship(
  children     => {
    type       => 'one to many',
    class      => 'SL::DB::RequirementSpecItem',
    column_map => { id => 'parent_id' },
  },
  dependencies => {
    map_class  => 'SL::DB::RequirementSpecDependency',
    map_from   => 'depending_item',
    map_to     => 'depended_item',
    type       => 'many to many',
  },
  dependents   => {
    map_class  => 'SL::DB::RequirementSpecDependency',
    map_from   => 'depended_item',
    map_to     => 'depending_item',
    type       => 'many to many',
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(requirement_spec_id parent_id)]);
__PACKAGE__->attr_duration(qw(time_estimation));

__PACKAGE__->before_delete(\&_before_delete_delete_children);

sub _before_delete_delete_children {
  my ($self) = @_;

  foreach my $child (@{ SL::DB::Manager::RequirementSpecItem->get_all(where => [ parent_id => $self->id ]) }) {
    my $result = $child->delete;
    return $result if !$result;
  }

  1;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->parent_id && !$self->title;

  return @errors;
}

sub sorted_children {
  my ($self) = @_;

  return [ sort { $a->position <=> $b->position } @{ $self->children } ];
}

sub get_section {
  my ($self) = @_;

  $self = $self->parent while $self->parent_id;

  return $self;
}

sub get_type {
  my ($self) = @_;

  return 'section' if !$self->parent_id;
  return $self->parent->parent_id ? 'sub-function-block' : 'function-block';
}

1;
