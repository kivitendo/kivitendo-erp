package SL::DB::RequirementSpec;

use strict;

use SL::DB::MetaSetup::RequirementSpec;
use SL::DB::Manager::RequirementSpec;
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

__PACKAGE__->meta->initialize;

__PACKAGE__->before_save('_before_save_initialize_not_null_columns');

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->title;

  return @errors;
}

sub _before_save_initialize_not_null_columns {
  my ($self) = @_;

  $self->previous_section_number(0) if !defined $self->previous_section_number;
  $self->previous_fb_number(0)      if !defined $self->previous_fb_number;

  return 1;
}

1;
