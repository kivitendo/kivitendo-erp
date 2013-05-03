package SL::DB::RequirementSpec;

use strict;

use Carp;
use Rose::DB::Object::Helpers;

use SL::DB::MetaSetup::RequirementSpec;
use SL::DB::Manager::RequirementSpec;
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

sub text_blocks_sorted {
  my ($self, %params) = _hashify(1, @_);

  my @text_blocks = @{ $self->text_blocks };
  @text_blocks    = grep { $_->output_position == $params{output_position} } @text_blocks if exists $params{output_position};
  @text_blocks    = sort { $a->position        <=> $b->position            } @text_blocks;

  return wantarray ? @text_blocks : \@text_blocks;
}

sub sections_sorted {
  my ($self, @rest) = @_;

  croak "This sub is not a writer" if @rest;

  my @sections = sort { $a->position <=> $b->position } grep { !$_->parent_id } @{ $self->items };
  return wantarray ? @sections : \@sections;
}

sub sections { &sections_sorted; }

sub displayable_name {
  my ($self) = @_;

  return sprintf('%s: "%s"', $self->type->description, $self->title);
}

sub versioned_copies_sorted {
  my ($self, %params) = _hashify(1, @_);

  my @copies = @{ $self->versioned_copies };
  @copies    = grep { $_->version->version_number <=  $params{max_version_number} } @copies if $params{max_version_number};
  @copies    = sort { $a->version->version_number <=> $b->version->version_number } @copies;

  return wantarray ? @copies : \@copies;
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

  my $copy = Rose::DB::Object::Helpers::clone_and_reset($self);
  $copy->copy_from($self, %params);

  return $copy;
}

sub copy_from {
  my ($self, $source, %attributes) = @_;

  croak "Missing parameter 'source'" unless $source;

  # Copy attributes.
  $self->assign_attributes(map({ ($_ => $source->$_) } qw(type_id status_id customer_id project_id title hourly_rate net_sum previous_section_number previous_fb_number is_template)),
                           %attributes);

  # Clone text blocks.
  $self->text_blocks(map { Rose::DB::Object::Helpers::clone_and_reset($_) } @{ $source->text_blocks });

  # Save new object -- we need its ID for the items.
  $self->save;

  my %id_to_clone;

  # Clone items.
  my $clone_item;
  $clone_item = sub {
    my ($item) = @_;
    my $cloned = Rose::DB::Object::Helpers::clone_and_reset($item);
    $cloned->requirement_spec_id($self->id);
    $cloned->children(map { $clone_item->($_) } @{ $item->children });

    $id_to_clone{ $item->id } = $cloned;

    return $cloned;
  };

  $self->items(map { $clone_item->($_) } @{ $source->sections });

  # Save the items -- need to do that before setting dependencies.
  $self->save;

  # Set dependencies.
  foreach my $item (@{ $source->items }) {
    next unless @{ $item->dependencies };
    $id_to_clone{ $item->id }->update_attributes(dependencies => [ map { $id_to_clone{$_->id} } @{ $item->dependencies } ]);
  }

  $self->update_attributes(%attributes);

  return $self;
}

sub previous_version {
  my ($self) = @_;

  my $and    = $self->version_id ? " AND (version_id <> ?)" : "";
  my $id     = $self->db->dbh->selectrow_array(<<SQL, undef, $self->id, ($self->version_id) x !!$self->version_id);
   SELECT MAX(id)
   FROM requirement_specs
   WHERE (working_copy_id = ?) $and
SQL

  return $id ? SL::DB::RequirementSpec->new(id => $id)->load : undef;
}

sub is_working_copy {
  my ($self) = @_;

  return !$self->working_copy_id;
}

sub next_version_number {
  my ($self) = @_;
  my $max_number = $self->db->dbh->selectrow_array(<<SQL, undef, $self->id);
    SELECT COALESCE(MAX(ver.version_number), 0)
    FROM requirement_spec_versions ver
    JOIN requirement_specs rs ON (rs.version_id = ver.id)
    WHERE rs.working_copy_id = ?
SQL

  return $max_number + 1;
}

sub create_version {
  my ($self, %attributes) = @_;

  croak "Cannot work on a versioned copy" if $self->working_copy_id;

  my ($copy, $version);
  my $ok = $self->db->do_transaction(sub {
    delete $attributes{version_number};

    $version = SL::DB::RequirementSpecVersion->new(%attributes, version_number => $self->next_version_number)->save;
    $copy    = $self->create_copy;
    $copy->update_attributes(version_id => $version->id, working_copy_id => $self->id);
    $self->update_attributes(version_id => $version->id);

    1;
  });

  return $ok ? ($copy, $version) : ();
}

sub invalidate_version {
  my ($self, %params) = @_;

  croak "Cannot work on a versioned copy" if $self->working_copy_id;

  return if !$self->id || !$self->version_id;
  $self->update_attributes(version_id => undef);
}

1;
