package SL::DB::RequirementSpecItem;

use strict;

use Carp;
use List::MoreUtils qw(any);
use Rose::DB::Object::Helpers;
use Rose::DB::Object::Util;

use SL::Common ();
use SL::DB::MetaSetup::RequirementSpecItem;
use SL::DB::Manager::RequirementSpecItem;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::AttrDuration;
use SL::DB::Helper::AttrHTML;
use SL::DB::Default;
use SL::Locale::String;
use SL::PrefixedNumber;

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
__PACKAGE__->attr_html('description');

__PACKAGE__->before_save(\&_before_save_create_fb_number);
__PACKAGE__->before_save(\&_before_save_invalidate_requirement_spec_version);
__PACKAGE__->before_delete(\&_before_delete_invalidate_requirement_spec_version);

sub _before_save_create_fb_number {
  my ($self) = @_;

  return 1 if  $self->fb_number;
  return 0 if !$self->requirement_spec_id;

  my $method      = 'previous_' . ($self->parent_id ? 'fb' : 'section') . '_number';
  my $next_number = $self->requirement_spec->$method + 1;

  $self->requirement_spec->update_attributes($method => $next_number) || return 0;

  $method    = ($self->parent_id ? 'function_block' : 'section') . '_number_format';
  my $format = $self->requirement_spec->type->$method;

  $self->fb_number(SL::PrefixedNumber->new(number => $format || 0)->set_to($next_number));

  return 1;
}

sub _before_save_invalidate_requirement_spec_version {
  my ($self, %params) = @_;

  return 1 if !$self->requirement_spec_id || $self->requirement_spec->working_copy_id;

  my %changed_columns = map { $_ => 1 } (Rose::DB::Object::Helpers::dirty_columns($self));
  my $has_changed     = !Rose::DB::Object::Util::is_in_db($self);
  $has_changed      ||= any { $changed_columns{$_} } qw(requirement_spec_id parent_id position fb_number title description);

  if (!$has_changed && $self->id) {
    my $old_item = SL::DB::RequirementSpecItem->new(id => $self->id)->load;
    $has_changed = join(':', sort map { $_->id } @{ $self->dependencies }) ne join(':', sort map { $_->id } @{ $old_item->dependencies });
  }

  $self->requirement_spec->invalidate_version if $has_changed;

  return 1;
}

sub _before_delete_invalidate_requirement_spec_version {
  my ($self, %params) = @_;

  $self->requirement_spec->invalidate_version if $self->requirement_spec_id;

  return 1;
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->parent_id && !$self->title;

  return @errors;
}

sub children_sorted {
  my ($self, @args) = @_;

  croak "Not a writer" if @args;

  return [ sort { $a->position <=> $b->position } $self->children ];
}

sub section {
  my ($self, @args) = @_;

  croak "Not a writer" if @args;
  $self = $self->parent while $self->parent_id;

  return $self;
}

sub child_type {
  my ($self, @args) = @_;

  croak "Not a writer" if @args;

  return $self->item_type eq 'section' ? 'function-block' : 'sub-function-block';
}

sub content_excerpt {
  my ($self) = @_;

  return Common::truncate($self->description_as_stripped_html // '', at => 200);
}


1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::RequirementSpecItem - Items for requirement specs

=head1 OVERVIEW

Please see L<SL::DB::RequirementSpec> for the architectual overview.

=head1 FUNCTIONS

=over 4

=item C<child_type>

Returns the C<item_type> for children of C<$self>.

=item C<children_sorted>

Returns an array reference of direct children (not of grandchildren)
for C<$self> ordered by their positional column in ascending order.

=item C<section>

Returns the section this item belongs to. It can be C<$self> if
C<$self> is already a section, its parent or grandparent.

=item C<validate>

Validates before saving and returns an array of human-readable error
messages in case of an error.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
