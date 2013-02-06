package SL::DB::Helper::ActsAsList;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(move_position_up move_position_down reorder_list configure_acts_as_list);

use Carp;

my %list_spec;

sub import {
  my ($class, @params)   = @_;
  my $importing = caller();

  $importing->before_save(  sub { SL::DB::Helper::ActsAsList::set_position(@_)    });
  $importing->before_delete(sub { SL::DB::Helper::ActsAsList::remove_position(@_) });

  # Use 'goto' so that Exporter knows which module to import into via
  # 'caller()'.
  goto &Exporter::import;
}

#
# Exported functions
#

sub move_position_up {
  my ($self) = @_;
  do_move($self, 'up');
}

sub move_position_down {
  my ($self) = @_;
  do_move($self, 'down');
}

sub reorder_list {
  my ($class_or_self, @ids) = @_;

  return 1 unless @ids;

  my $self   = ref($class_or_self) ? $class_or_self : $class_or_self->new;
  my $column = column_name($self);
  my $result = $self->db->do_transaction(sub {
    my $query = qq|UPDATE | . $self->meta->table . qq| SET ${column} = ? WHERE id = ?|;
    my $sth   = $self->db->dbh->prepare($query) || die $self->db->dbh->errstr;

    foreach my $new_position (1 .. scalar(@ids)) {
      $sth->execute($new_position, $ids[$new_position - 1]) || die $sth->errstr;
    }

    $sth->finish;
  });

  return $result;
}

sub configure_acts_as_list {
  my ($class, %params) = @_;

  $list_spec{$class} = {
    group_by    => $params{group_by},
    column_name => $params{column_name},
  };
}

#
# Helper functions
#

sub get_group_by_where {
  my ($self)   = @_;

  my $group_by = get_spec(ref $self, 'group_by') || [];
  $group_by    = [ $group_by ] if $group_by && !ref $group_by;

  my @where    = map { my $value = $self->$_; defined($value) ? "(${_} = " . $value . ")" : "(${_} IS NULL)" } @{ $group_by };

  return join ' AND ', @where;
}

sub set_position {
  my ($self) = @_;
  my $column = column_name($self);

  return 1 if defined $self->$column;

  my $table        = $self->meta->table;
  my $where        = get_group_by_where($self);
  $where           = " WHERE ${where}" if $where;
  my $sql = <<SQL;
    SELECT COALESCE(max(${column}), 0)
    FROM ${table}
    ${where}
SQL

  my $max_position = $self->db->dbh->selectrow_arrayref($sql)->[0];
  $self->$column($max_position + 1);

  return 1;
}

sub remove_position {
  my ($self) = @_;
  my $column = column_name($self);

  $self->load;
  return 1 unless defined $self->$column;

  my $table    = $self->meta->table;
  my $value    = $self->$column;
  my $group_by = get_group_by_where($self);
  $group_by    = ' AND ' . $group_by if $group_by;
  my $sql      = <<SQL;
    UPDATE ${table}
    SET ${column} = ${column} - 1
    WHERE (${column} > ${value}) ${group_by}
SQL

  $self->db->dbh->do($sql);

  return 1;
}

sub do_move {
  my ($self, $direction) = @_;
  my $column             = column_name($self);

  croak "Object has not been saved yet" unless $self->id;
  croak "No position set yet"           unless defined $self->$column;

  my $table                                        = $self->meta->table;
  my $old_position                                 = $self->$column;
  my ($comp_sel, $comp_upd, $min_max, $plus_minus) = $direction eq 'up' ? ('<', '>=', 'max', '+') : ('>', '<=', 'min', '-');
  my $group_by                                     = get_group_by_where($self);
  $group_by                                        = ' AND ' . $group_by if $group_by;
  my $sql                                          = <<SQL;
    SELECT ${min_max}(${column})
    FROM ${table}
    WHERE (${column} ${comp_sel} ${old_position})
      ${group_by}
SQL

  my $new_position = $self->db->dbh->selectrow_arrayref($sql)->[0];

  return undef unless defined $new_position;

  $sql = <<SQL;
    UPDATE ${table}
    SET ${column} = ${old_position}
    WHERE (${column} = ${new_position})
     ${group_by};
SQL

  $self->db->dbh->do($sql);

  $self->update_attributes($column => $new_position);
}

sub column_name {
  my ($self) = @_;
  my $column = get_spec(ref $self, 'column_name');
  return $column if $column;
  return $self->can('sortkey') ? 'sortkey' : 'position';
}

sub get_spec {
  my ($class, $key) = @_;

  return undef unless $list_spec{$class};
  return $list_spec{$class}->{$key};
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::ActsAsList - Mixin for managing ordered items by a
column

=head1 SYNOPSIS

  package SL::DB::SomeObject;
  use SL::DB::Helper::ActsAsList;

  package SL::Controller::SomeController;
  ...
  # Assign a position automatically
  $obj = SL::DB::SomeObject->new(description => 'bla');
  $obj->save;

  # Move items up and down
  $obj = SL::DB::SomeOBject->new(id => 1)->load;
  $obj->move_position_up;
  $obj->move_position_down;

  # Adjust all remaining positions automatically
  $obj->delete

This mixin assumes that the mixing package's table contains a column
called C<position> or C<sortkey> (for legacy tables). This column is
set automatically upon saving the object if it hasn't been set
already. If it hasn't then it will be set to the maximum position used
in the table plus one.

When the object is deleted all positions greater than the object's old
position are decreased by one.

The column name to use can be configured via L<configure_acts_as_list>.

=head1 CLASS FUNCTIONS

=over 4

=item C<configure_acts_as_list %params>

Configures the mixin's behaviour. C<%params> can contain the following
values:

=over 2

=item C<column_name>

The name of the column containing the position. If not set explicitly
then the mixin will use C<sortkey> if the model contains such a column
(only for legacy tables) and C<position> otherwise.

=item C<group_by>

An optional column name (or array reference of column names) by which
to group. If a table contains items for several distinct sets and each
set has its own sorting then this can be used.

An example would be requirement spec text blocks. They have a column
called C<output_position> that selects where to output the text blocks
(either before or after the sections). Furthermore these text blocks
each belong to a single requirement spec document. So each combination
of C<requirement_spec_id> and C<output_position> should have its own
set of C<position> values, which can be achieved by configuring this
mixin with C<group_by = [qw(requirement_spec_id output_position)]>.

=back

=back

=head1 INSTANCE FUNCTIONS

=over 4

=item C<move_position_up>

Swaps the object with the object one step above the current one
regarding their sort order by exchanging their C<position> values.

=item C<move_position_down>

Swaps the object with the object one step below the current one
regarding their sort order by exchanging their C<position> values.

=item C<reorder_list @ids>

Re-orders the objects given in C<@ids> by their position in C<@ids> by
updating all of their positional columns. Each element in
C<@positions> must be the ID of an object. The new position is the
ID's index inside C<@ids> plus one (meaning the first element's new
position will be 1 and not 0).

This works by executing SQL "UPDATE" statements directly.

Returns the result of the whole transaction (trueish in case of
success).

This method can be called both as a class method or an instance
method.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
