package SL::DB::ProjectStatus;

use strict;

use SL::DB::MetaSetup::ProjectStatus;
use SL::DB::Manager::ProjectStatus;

use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->add_relationship(
  projects => {
    type         => 'many to one',
    class        => 'SL::DB::Project',
    column_map   => { id => 'project_status_id' },
  },
);

__PACKAGE__->meta->initialize;

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The description is missing.') if !$self->description;

  return @errors;
}

1;
