package SL::DB::RequirementSpec;

use strict;

use SL::DB::MetaSetup::RequirementSpec;
use SL::Locale::String;

__PACKAGE__->meta->add_relationship(
  items          => {
    type         => 'one to many',
    class        => 'SL::DB::RequirementSpecItem',
    column_map   => { id => 'requirement_spec_id' },
  },
  text_blocks    => {
    type         => 'one to many',
    class        => 'SL::DB::RequirementSpecTextBlock',
    column_map   => { id => 'requirement_spec_id' },
  },
);

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->title;

  return @errors;
}

1;
