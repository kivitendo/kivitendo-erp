package SL::DB::Helper::ActsAsList;

use strict;

use parent qw(Exporter);
our @EXPORT = qw(move_position_up move_position_down add_to_list remove_from_list reorder_list configure_acts_as_list
                 get_previous_in_list get_next_in_list get_full_list);

use Carp;
use SL::X;

my %list_spec;

sub import {
  my ($class, @params)   = @_;
  my $importing = caller();

  configure_acts_as_list($importing, @params);

  $importing->before_save(  sub { SL::DB::Helper::ActsAsList::set_position(@_)    });
  $importing->before_delete(sub { SL::DB::Helper::ActsAsList::remove_position(@_) });

  # Don't 'goto' to Exporters import, it would try to parse @params
  __PACKAGE__->export_to_level(1, $class, @EXPORT);
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

sub remove_from_list {
  my ($self) = @_;

  return $self->db->with_transaction(sub {
    remove_position($self);

    # Set to -1 manually because $self->update_attributes() would
    # trigger the before_save() hook from this very plugin assigning a
    # number at the end of the list again.
    my $table           = $self->meta->table;
    my $column          = column_name($self);
    my $primary_key_col = ($self->meta->primary_key)[0];
    my $sql             = <<SQL;
      UPDATE ${table}
      SET ${column} = -1
      WHERE ${primary_key_col} = ?
SQL
    $self->db->dbh->do($sql, undef, $self->$primary_key_col);
    $self->$column(undef);
  });
}

sub add_to_list {
  my ($self, %params) = @_;

  croak "Invalid parameter 'position'" unless ($params{position} || '') =~ m/^ (?: before | after | first | last ) $/x;

  my $column = column_name($self);

  $self->remove_from_list if ($self->$column // -1) != -1;

  if ($params{position} eq 'last') {
    set_position($self);
    $self->save;
    return;
  }

  my $table               = $self->meta->table;
  my $primary_key_col     = ($self->meta->primary_key)[0];
  my ($group_by, @values) = get_group_by_where($self);
  $group_by               = " AND ${group_by}" if $group_by;
  my $new_position;

  if ($params{position} eq 'first') {
    $new_position = 1;

  } else {
    # Can only be 'before' or 'after' -- 'last' has been checked above
    # already.

    my $reference = $params{reference};
    croak "Missing parameter 'reference'" if !$reference;

    my $reference_pos;
    if (ref $reference) {
      $reference_pos = $reference->$column;
    } else {
      ($reference_pos) = $self->db->dbh->selectrow_array(qq|SELECT ${column} FROM ${table} WHERE ${primary_key_col} = ?|, undef, $reference);
    }

    $new_position = $params{position} eq 'before' ? $reference_pos : $reference_pos + 1;
  }

  my $query = <<SQL;
    UPDATE ${table}
    SET ${column} = ${column} + 1
    WHERE (${column} > ?)
      ${group_by}
SQL

  return $self->db->with_transaction(sub {
    $self->db->dbh->do($query, undef, $new_position - 1, @values);
    $self->update_attributes($column => $new_position);
  });
}

sub get_next_in_list {
  my ($self) = @_;
  return get_previous_or_next($self, 'next');
}

sub get_previous_in_list {
  my ($self) = @_;
  return get_previous_or_next($self, 'previous');
}

sub get_full_list {
  my ($self) = @_;

  my $group_by = get_spec(ref $self, 'group_by') || [];
  $group_by    = [ $group_by ] if $group_by && !ref $group_by;
  my @where    = map { ($_ => $self->$_) } @{ $group_by };

  return $self->_get_manager_class->get_all(where => \@where, sort_by => column_name($self) . ' ASC');
}

sub reorder_list {
  my ($class_or_self, @ids) = @_;

  return 1 unless @ids;

  my $self   = ref($class_or_self) ? $class_or_self : $class_or_self->new;
  my $column = column_name($self);
  my $result = $self->db->with_transaction(sub {
    my $query = qq|UPDATE | . $self->meta->table . qq| SET ${column} = ? WHERE id = ?|;
    my $sth   = $self->db->dbh->prepare($query) || SL::X::DBUtilsError->throw(msg => 'reorder_list error', db_error => $self->db->dbh->errstr);

    foreach my $new_position (1 .. scalar(@ids)) {
      $sth->execute($new_position, $ids[$new_position - 1]) || SL::X::DBUtilsError->throw(msg => 'reorder_list error', db_error => $sth->errstr);
    }

    $sth->finish;

    1;
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

  my (@where, @values);
  foreach my $column (@{ $group_by }) {
    my $value = $self->$column;
    push @values, $value if defined $value;
    push @where,  defined($value) ? "(${column} = ?)" : "(${column} IS NULL)";
  }

  return (join(' AND ', @where), @values);
}

sub set_position {
  my ($self) = @_;
  my $column = column_name($self);
  my $value  = $self->$column;

  return 1 if defined($value) && ($value != -1);

  my $table               = $self->meta->table;
  my ($group_by, @values) = get_group_by_where($self);
  $group_by               = " AND ${group_by}" if $group_by;
  my $sql                 = <<SQL;
    SELECT COALESCE(MAX(${column}), 0)
    FROM ${table}
    WHERE (${column} <> -1)
      ${group_by}
SQL

  my $max_position = $self->db->dbh->selectrow_arrayref($sql, undef, @values)->[0];
  $self->$column($max_position + 1);

  return 1;
}

sub remove_position {
  my ($self) = @_;
  my $column = column_name($self);

  $self->load;
  my $value = $self->$column;
  return 1 unless defined($value) && ($value != -1);

  my $table               = $self->meta->table;
  my ($group_by, @values) = get_group_by_where($self);
  $group_by               = ' AND ' . $group_by if $group_by;
  my $sql                 = <<SQL;
    UPDATE ${table}
    SET ${column} = ${column} - 1
    WHERE (${column} > ?)
     ${group_by}
SQL

  $self->db->dbh->do($sql, undef, $value, @values);

  return 1;
}

sub do_move {
  my ($self, $direction) = @_;

  croak "Object has not been saved yet" unless $self->id;

  my $column       = column_name($self);
  my $old_position = $self->$column;
  croak "No position set yet" unless defined($old_position) && ($old_position != -1);

  my $table                                        = $self->meta->table;
  my ($comp_sel, $comp_upd, $min_max, $plus_minus) = $direction eq 'up' ? ('<', '>=', 'MAX', '+') : ('>', '<=', 'MIN', '-');
  my ($group_by, @values)                          = get_group_by_where($self);
  $group_by                                        = ' AND ' . $group_by if $group_by;
  my $sql                                          = <<SQL;
    SELECT ${min_max}(${column})
    FROM ${table}
    WHERE (${column} <>          -1)
      AND (${column} ${comp_sel} ?)
      ${group_by}
SQL

  my $new_position = $self->db->dbh->selectrow_arrayref($sql, undef, $old_position, @values)->[0];

  return undef unless defined $new_position;

  $sql = <<SQL;
    UPDATE ${table}
    SET ${column} = ?
    WHERE (${column} = ?)
     ${group_by};
SQL

  $self->db->dbh->do($sql, undef, $old_position, $new_position, @values);

  $self->update_attributes($column => $new_position);
}

sub get_previous_or_next {
  my ($self, $direction)  = @_;

  my $asc_desc            = $direction eq 'next' ? 'ASC' : 'DESC';
  my $comparator          = $direction eq 'next' ? '>'   : '<';
  my $table               = $self->meta->table;
  my $column              = column_name($self);
  my $primary_key_col     = ($self->meta->primary_key)[0];
  my ($group_by, @values) = get_group_by_where($self);
  $group_by               = " AND ${group_by}" if $group_by;
  my $sql                 = <<SQL;
    SELECT ${primary_key_col}
    FROM ${table}
    WHERE (${column} ${comparator} ?)
      ${group_by}
    ORDER BY ${column} ${asc_desc}
    LIMIT 1
SQL

  my $id = ($self->db->dbh->selectrow_arrayref($sql, undef, $self->$column, @values) || [])->[0];

  return $id ? $self->_get_manager_class->find_by(id => $id) : undef;
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
  use SL::DB::Helper::ActsAsList [ PARAMS ];

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

C<PARAMS> will be given to L<configure_acts_as_list> and can be used to
set the column name.

=head1 CLASS FUNCTIONS

=over 4

=item C<configure_acts_as_list %params>

Configures the mixin's behaviour. Will get called automatically with the
include parameters. C<%params> can contain the following values:

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

=item C<add_to_list %params>

Adds this item to the list. The parameter C<position> is required and
can be one of C<first>, C<last>, C<before> and C<after>. With C<first>
the item is inserted as the first item in the list and all other
item's positions are shifted up by one. For C<position = last> the
item is inserted at the end of the list.

For C<before> and C<after> an additional parameter C<reference> is
required. This is either a Rose model instance or the primary key of
one. The current item will then be inserted either before or after the
referenced item by shifting all the appropriate item positions up by
one.

If C<$self>'s positional column is already set when this function is
called then L</remove_from_list> will be called first before anything
else is done.

After this function C<$self>'s positional column has been set and
saved to the database.

=item C<remove_from_list>

Sets this items positional column to C<-1>, saves it and moves all
following items up by 1.

=item C<get_previous_in_list>

Fetches the previous item in the list. Returns C<undef> if C<$self> is
already the first one.

=item C<get_next_in_list>

Fetches the next item in the list. Returns C<undef> if C<$self> is
already the last one.

=item C<get_full_list>

Fetches all items in the same list as C<$self> and returns them as an
array reference.

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
