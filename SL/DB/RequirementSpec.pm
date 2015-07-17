package SL::DB::RequirementSpec;

use strict;

use Carp;
use List::Util qw(max reduce);
use Rose::DB::Object::Helpers;

use SL::DB::MetaSetup::RequirementSpec;
use SL::DB::Manager::RequirementSpec;
use SL::DB::Helper::AttrDuration;
use SL::DB::Helper::CustomVariables (
  module      => 'RequirementSpecs',
  cvars_alias => 1,
);
use SL::DB::Helper::LinkedRecords;
use SL::Locale::String;
use SL::Util qw(_hashify);

__PACKAGE__->meta->add_relationship(
  items            => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpecItem',
    column_map     => { id => 'requirement_spec_id' },
  },
  text_blocks      => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpecTextBlock',
    column_map     => { id => 'requirement_spec_id' },
  },
  versioned_copies => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpec',
    column_map     => { id => 'working_copy_id' },
  },
  versions         => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpecVersion',
    column_map     => { id => 'requirement_spec_id' },
  },
  working_copy_versions => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpecVersion',
    column_map     => { id => 'working_copy_id' },
  },
  orders           => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpecOrder',
    column_map     => { id => 'requirement_spec_id' },
  },
  parts            => {
    type           => 'one to many',
    class          => 'SL::DB::RequirementSpecPart',
    column_map     => { id => 'requirement_spec_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_duration(qw(time_estimation));

__PACKAGE__->before_save('_before_save_initialize_not_null_columns');

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, t8('The title is missing.') if !$self->title;

  return @errors;
}

sub _before_save_initialize_not_null_columns {
  my ($self) = @_;

  for (qw(previous_section_number previous_fb_number previous_picture_number)) {
    $self->$_(0) if !defined $self->$_;
  }

  return 1;
}

sub version {
  my ($self) = @_;

  croak "Not a writer" if scalar(@_) > 1;

  return $self->is_working_copy ? $self->working_copy_versions->[0] : $self->versions->[0];
}

sub text_blocks_sorted {
  my ($self, %params) = _hashify(1, @_);

  my @text_blocks = @{ $self->text_blocks };
  @text_blocks    = grep { $_->output_position == $params{output_position} } @text_blocks if exists $params{output_position};
  @text_blocks    = sort { $a->position        <=> $b->position            } @text_blocks;

  return \@text_blocks;
}

sub sections_sorted {
  my ($self, @rest) = @_;

  croak "This sub is not a writer" if @rest;

  return [ sort { $a->position <=> $b->position } grep { !$_->parent_id } @{ $self->items } ];
}

sub sections { &sections_sorted; }

sub orders_sorted {
  my ($self, %params) = _hashify(1, @_);
  my $by              = $params{by} || 'itime';

  return [ sort { $a->$by cmp $b->$by } @{ $self->orders } ];
}

sub displayable_name {
  my ($self) = @_;

  return sprintf('%s: "%s"', $self->type->description, $self->title);
}

sub versioned_copies_sorted {
  my ($self, %params) = _hashify(1, @_);

  my @copies = @{ $self->versioned_copies };
  @copies    = grep { $_->version->version_number <=  $params{max_version_number} } @copies if $params{max_version_number};
  @copies    = sort { $a->version->version_number <=> $b->version->version_number } @copies;

  return \@copies;
}

sub parts_sorted {
  my ($self, @rest) = @_;

  croak "This sub is not a writer" if @rest;

  return [ sort { $a->position <=> $b->position } @{ $self->parts } ];
}

sub create_copy {
  my ($self, %params) = @_;

  return $self->_create_copy(%params) if $self->db->in_transaction;

  my $copy;
  if (!$self->db->do_transaction(sub { $copy = $self->_create_copy(%params) })) {
    $::lxdebug->message(LXDebug->WARN(), "create_copy failed: " . join("\n", (split(/\n/, $self->db->error))[0..2]));
    return undef;
  }

  return $copy;
}

sub _create_copy {
  my ($self, %params) = @_;

  my $copy = $self->clone_and_reset;
  $copy->copy_from($self, %params);

  return $copy;
}

sub _copy_from {
  my ($self, $params, %attributes) = @_;

  my $source = $params->{source};

  croak "Missing parameter 'source'" unless $source;

  # Copy attributes.
  if (!$params->{paste_template}) {
    $self->assign_attributes(map({ ($_ => $source->$_) } qw(type_id status_id customer_id project_id title hourly_rate time_estimation previous_section_number previous_fb_number previous_picture_number is_template)),
                             %attributes);
  }

  # Copy custom variables.
  foreach my $var (@{ $source->cvars_by_config }) {
    $self->cvar_by_name($var->config->name)->value($var->value);
  }

  my %paste_template_result;

  # Clone text blocks and pictures.
  my $clone_and_reset_position = sub {
    my ($src_obj) = @_;
    my $cloned    = $src_obj->clone_and_reset;
    $cloned->position(undef);
    return $cloned;
  };

  my $clone_text_block = sub {
    my ($text_block) = @_;
    my $cloned       = $text_block->clone_and_reset;
    $cloned->position(undef);
    $cloned->pictures([ map { $clone_and_reset_position->($_) } @{ $text_block->pictures_sorted } ]);
    return $cloned;
  };

  $paste_template_result{text_blocks} = [ map { $clone_text_block->($_) } @{ $source->text_blocks_sorted } ];

  if (!$params->{paste_template}) {
    $self->text_blocks($paste_template_result{text_blocks});
  } else {
    $self->add_text_blocks($paste_template_result{text_blocks});
  }

  # Clone additional parts.
  $paste_template_result{parts} = [ map { $clone_and_reset_position->($_) } @{ $source->parts } ];
  my $accessor                  = $params->{paste_template} ? "add_parts" : "parts";
  $self->$accessor($paste_template_result{parts});

  # Save new object -- we need its ID for the items.
  $self->save(cascade => 1);

  my %id_to_clone;

  # Clone items.
  my $clone_item;
  $clone_item = sub {
    my ($item) = @_;
    my $cloned = $item->clone_and_reset;
    $cloned->requirement_spec_id($self->id);
    $cloned->position(undef);
    $cloned->fb_number(undef) if $params->{paste_template};
    $cloned->children(map { $clone_item->($_) } @{ $item->children });

    $id_to_clone{ $item->id } = $cloned;

    return $cloned;
  };

  $paste_template_result{sections} = [ map { $clone_item->($_) } @{ $source->sections_sorted } ];

  if (!$params->{paste_template}) {
    $self->items($paste_template_result{sections});
  } else {
    $self->add_items($paste_template_result{sections});
  }

  # Save the items -- need to do that before setting dependencies.
  $self->save;

  # Set dependencies.
  foreach my $item (@{ $source->items }) {
    next unless @{ $item->dependencies };
    $id_to_clone{ $item->id }->update_attributes(dependencies => [ map { $id_to_clone{$_->id} } @{ $item->dependencies } ]);
  }

  $self->update_attributes(%attributes) unless $params->{paste_template};

  return %paste_template_result;
}

sub copy_from {
  my ($self, $source, %attributes) = @_;

  $self->db->with_transaction(sub { $self->_copy_from({ source => $source, paste_template => 0 }, %attributes); });
}

sub paste_template {
  my ($self, $template) = @_;

  $self->db->with_transaction(sub { $self->_copy_from({ source => $template, paste_template => 1 }); });
}

sub highest_version {
  my ($self) = @_;

  return reduce { $a->version->version_number > $b->version->version_number ? $a : $b } @{ $self->versioned_copies };
}

sub is_working_copy {
  my ($self) = @_;

  return !$self->working_copy_id;
}

sub next_version_number {
  my ($self) = @_;

  return 1 if !$self->id;

  my ($max_number) = $self->db->dbh->selectrow_array(<<SQL, {}, $self->id, $self->id);
    SELECT MAX(v.version_number)
    FROM requirement_spec_versions v
    WHERE v.requirement_spec_id IN (
      SELECT rs.id
      FROM requirement_specs rs
      WHERE (rs.id              = ?)
         OR (rs.working_copy_id = ?)
    )
SQL

  return ($max_number // 0) + 1;
}

sub create_version {
  my ($self, %attributes) = @_;

  croak "Cannot work on a versioned copy" if $self->working_copy_id;

  my ($copy, $version);
  my $ok = $self->db->with_transaction(sub {
    delete $attributes{version_number};

    SL::DB::Manager::RequirementSpecVersion->update_all(
      set   => [ working_copy_id     => undef     ],
      where => [ requirement_spec_id => $self->id ],
    );

    $copy    = $self->create_copy(working_copy_id => $self->id);
    $version = SL::DB::RequirementSpecVersion->new(%attributes, version_number => $self->next_version_number, requirement_spec_id => $copy->id, working_copy_id => $self->id)->save;

    1;
  });

  return $ok ? ($copy, $version) : ();
}

sub invalidate_version {
  my ($self, %params) = @_;

  croak "Cannot work on a versioned copy" if $self->working_copy_id;

  return if !$self->id;

  SL::DB::Manager::RequirementSpecVersion->update_all(
    set   => [ working_copy_id => undef     ],
    where => [ working_copy_id => $self->id ],
  );
}

sub compare_to {
  my ($self, $other) = @_;

  return $self->id <=> $other->id;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::RequirementSpec - RDBO model for requirement specs

=head1 OVERVIEW

The database structure behind requirement specs is a bit involved. The
important thing is how working copy/versions are handled.

The table contains three important columns: C<id> (which is also the
primary key) and C<working_copy_id>. C<working_copy_id> is a
self-referencing column: it can be C<NULL>, but if it isn't then it
contains another requirement spec C<id>.

Versions are represented similarly. The C<requirement_spec_versions>
table has three important columns: C<id> (the primary key),
C<requirement_spec_id> (references C<requirement_specs.id> and must
not be C<NULL>) and C<working_copy_id> (references
C<requirement_specs.id> as well but can be
C<NULL>). C<working_copy_id> points to the working copy if and only if
the working copy is currently equal to a versioned copy.

The design is as follows:

=over 2

=item * The user is always working on a working copy. The working copy
is identified in the database by having C<working_copy_id> set to
C<NULL>.

=item * All other entries in this table are referred to as I<versioned
copies>. A versioned copy is a copy of a working frozen at the moment
in time it was created. Each versioned copy refers back to the working
copy it belongs to: each has its C<working_copy_id> set.

=item * Each versioned copy must be referenced from an entry in the
table C<requirement_spec_versions> via
C<requirement_spec_id>.

=item * Directly after creating a versioned copy even the working copy
itself is referenced from a version via that table's
C<working_copy_id> column. However, any modification that will be
visible to the customer (text, positioning etc but not internal things
like time/cost estimation changes) will cause the version to be
disassociated from the working copy. This is achieved via before save
hooks in Perl.

=back

=head1 DATABASE TRIGGERS AND CHECKS

Several database triggers and consistency checks exist that manage
requirement specs, their items and their dependencies. These are
described here instead of in the individual files for the other RDBO
models.

=head2 DELETION

When you delete a requirement spec all of its dependencies (items,
text blocks, versions etc.) are deleted by triggers.

When you delete an item (either a section or a (sub-)function block)
all of its children will be deleted as well. This will trigger the
same trigger resulting in a recursive deletion with the bottom-most
items being deleted first. Their item dependencies are deleted as
well.

=head2 UPDATING

Whenever you update a requirement spec item a trigger will fire that
will update the parent's C<time_estimation> column. This also happens
when an item is deleted or updated.

=head2 CONSISTENCY CHECKS

Several consistency checks are applied to requirement spec items:

=over 2

=item * Column C<requirement_spec_item.item_type> can only contain one of
the values C<section>, C<function-block> or C<sub-function-block>.

=item * Column C<requirement_spec_item.parent_id> must be C<NULL> if
C<requirement_spec_item.item_type> is set to C<section> and C<NOT
NULL> otherwise.

=back

=head1 FUNCTIONS

=over 4

=item C<copy_from $source, %attributes>

Copies everything (basic attributes like type/title/customer, items,
text blocks, time/cost estimation) save for the versions from the
other requirement spec object C<$source> into C<$self> and saves
it. This is done within a transaction.

C<%attributes> are attributes that are assigned to C<$self> after all
the basic attributes from C<$source> have been assigned.

This function can be used for resetting a working copy to a specific
version. Example:

  my $requirement_spec = SL::DB::RequirementSpec->new(id => $::form->{id})->load;
  my $versioned_copy   = SL::DB::RequirementSpec->new(id => $::form->{versioned_copy_id})->load;

  $requirement_spec->copy_from($versioned_copy);
  $versioned_copy->version->update_attributes(working_copy_id => $requirement_spec->id);

=item C<create_copy>

Creates and returns a copy of C<$self>. The copy is already
saved. Creating the copy happens within a transaction.

=item C<create_version %attributes>

Prerequisites: C<$self> must be a working copy (see the overview),
not a versioned copy.

This function creates a new version for C<$self>. This involves
several steps:

=over 2

=item 1. The next version number is calculated using
L</next_version_number>.

=item 2. A copy of C<$self> is created with L</create_copy>.

=item 3. An instance of L<SL::DB::RequirementSpecVersion> is
created. Its attributes are copied from C<%attributes> save for the
version number which is taken from step 1.

=item 4. The version instance created in step 3 is referenced to the
the copy from step 2 via C<requirement_spec_id> and to the working
copy for which the version was created via C<working_copy_id>.

=back

All this is done within a transaction.

In case of success a two-element list is returned consisting of the
copy & version objects created in steps 3 and 2 respectively. In case
of a failure an empty list will be returned.

=item C<displayable_name>

Returns a human-readable name for this instance consisting of the type
and the title.

=item C<highest_version>

Given a working copy C<$self> this function returns the versioned copy
of C<$self> with the highest version number. If such a version exist
its instance is returned. Otherwise C<undef> is returned.

This can be used for calculating the difference between the working
copy and the last version created for it.

=item C<invalidate_version>

Prerequisites: C<$self> must be a working copy (see the overview),
not a versioned copy.

Sets any C<working_copy_id> field in the C<requirement_spec_versions>
table containing C<$self-E<gt>id> to C<undef>.

=item C<is_working_copy>

Returns trueish if C<$self> is a working copy and not a versioned
copy. The condition for this is that C<working_copy_id> is C<undef>.

=item C<next_version_number>

Calculates and returns the next version number for this requirement
spec. Version numbers start at 1 and are incremented by one for each
version created for it, no matter whether or not it has been reverted
to a previous version since. It boils down to this pseudo-code:

  if (has_never_had_a_version)
    return 1
  else
    return max(version_number for all versions for this requirement spec) + 1

=item C<sections>

An alias for L</sections_sorted>.

=item C<sections_sorted>

Returns an array reference of requirement spec items that do not have
a parent -- meaning that are sections.

This is not a writer. Use the C<items> relationship for that.

=item C<text_blocks_sorted %params>

Returns an array reference of text blocks sorted by their positional
column in ascending order. If the C<output_position> parameter is
given then only the text blocks belonging to that C<output_position>
are returned.

=item C<parts_sorted>

Returns an array reference of additional parts sorted by their
positional column in ascending order.

=item C<validate>

Validate values before saving. Returns list or human-readable error
messages (if any).

=item C<versioned_copies_sorted %params>

Returns an array reference of versioned copies sorted by their version
number in ascending order. If the C<max_version_number> parameter is
given then only the versioned copies whose version number is less than
or equal to C<max_version_number> are returned.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
