package SL::DB::RequirementSpecItem;

use strict;

use SL::DB::MetaSetup::RequirementSpecItem;
use SL::DB::Manager::RequirementSpecItem;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->add_relationship(
  children       => {
    type         => 'one to many',
    class        => 'SL::DB::RequirementSpecItem',
    column_map   => { id => 'parent_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(requirement_spec_id parent_id)]);

__PACKAGE__->before_delete(\&_before_delete_delete_children);

sub _before_delete_delete_children {
  my ($self) = @_;

  foreach my $child (@{ SL::DB::Manager::RequirementSpecItem->get_all(where => [ parent_id => $self->id ]) }) {
    my $result = $child->delete;
    return $result if !$result;
  }

  1;
}

sub sorted_children {
  my ($self) = @_;

  return [ sort { $a->position <=> $b->position } @{ $self->children } ];
}

1;
