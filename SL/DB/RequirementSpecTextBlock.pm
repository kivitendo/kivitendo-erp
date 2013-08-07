package SL::DB::RequirementSpecTextBlock;

use strict;

use List::MoreUtils qw(any);
use Rose::DB::Object::Helpers;
use Rose::DB::Object::Util;

use SL::DB::MetaSetup::RequirementSpecTextBlock;
use SL::DB::Manager::RequirementSpecTextBlock;
use SL::DB::Helper::ActsAsList;
use SL::Locale::String;

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(requirement_spec_id output_position)]);

__PACKAGE__->before_save(\  &_before_save_invalidate_requirement_spec_version);
__PACKAGE__->before_delete(\&_before_delete_invalidate_requirement_spec_version);

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->title;

  return @errors;
}

sub _before_save_invalidate_requirement_spec_version {
  my ($self, %params) = @_;

  return 1 if !$self->requirement_spec_id || $self->requirement_spec->working_copy_id;

  my %changed_columns = map { $_ => 1 } (Rose::DB::Object::Helpers::dirty_columns($self));

  $self->requirement_spec->invalidate_version
    if !Rose::DB::Object::Util::is_in_db($self) || any { $changed_columns{$_} } qw(title text position output_position);

  return 1;
}

sub _before_delete_invalidate_requirement_spec_version {
  my ($self, %params) = @_;

  $self->requirement_spec->invalidate_version if $self->requirement_spec_id;

  return 1;
}

1;
