package SL::DB::RequirementSpecTextBlock;

use strict;

use Carp;
use List::MoreUtils qw(any);
use Rose::DB::Object::Helpers;
use Rose::DB::Object::Util;

use SL::Common ();
use SL::DB::MetaSetup::RequirementSpecTextBlock;
use SL::DB::Manager::RequirementSpecTextBlock;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::AttrHTML;
use SL::Locale::String;

__PACKAGE__->meta->add_relationship(
  pictures => {
    type         => 'one to many',
    class        => 'SL::DB::RequirementSpecPicture',
    column_map   => { id => 'text_block_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(requirement_spec_id output_position)]);
__PACKAGE__->attr_html('text');

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

sub pictures_sorted {
  my ($self, @args) = @_;

  croak "Not a writer" if @args;

  return [ sort { $a->position <=> $b->position } $self->pictures ];
}

sub content_excerpt {
  my ($self) = @_;

  return Common::truncate($self->text_as_stripped_html // '', at => 200);
}

1;
