package SL::DB::RequirementSpecTextBlock;

use strict;

use SL::DB::MetaSetup::RequirementSpecTextBlock;
use SL::DB::Manager::RequirementSpecTextBlock;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

__PACKAGE__->meta->add_relationships(
  requirement_spec => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpec',
    column_map     => { requirement_spec_id => 'id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(requirement_spec_id output_position)]);

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->title;

  return @errors;
}

1;
