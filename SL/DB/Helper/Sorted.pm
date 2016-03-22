package SL::DB::Helper::Sorted;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(get_all_sorted make_sort_string);

my %sort_spec;

sub make_sort_string {
  my ($class, %params) = @_;

  my $sort_spec        = _get_sort_spec($class);

  my $sort_dir         = defined($params{sort_dir}) ? $params{sort_dir} * 1 : $sort_spec->{default}->[1];
  my $sort_dir_str     = $sort_dir ? 'ASC' : 'DESC';

  my $sort_by          = $params{sort_by} || { };
  $sort_by             = $sort_spec->{default}->[0] unless $sort_spec->{columns}->{$sort_by};

  my $nulls_str        = '';
  if ($sort_spec->{nulls}) {
    $nulls_str = ref($sort_spec->{nulls}) ? ($sort_spec->{nulls}->{$sort_by} || $sort_spec->{nulls}->{default}) : $sort_spec->{nulls};
    $nulls_str = " NULLS ${nulls_str}" if $nulls_str;
  }

  my $sort_by_str = $sort_spec->{columns}->{$sort_by};
  $sort_by_str    = [ $sort_by_str ] unless ref($sort_by_str) eq 'ARRAY';

  # generaate tiebreaker
  push @$sort_by_str, @{ $sort_spec->{tiebreaker} };

  $sort_by_str    = join(', ', map { "${_} ${sort_dir_str}${nulls_str}" } @{ $sort_by_str });

  return wantarray ? ($sort_by, $sort_dir, $sort_by_str) : $sort_by_str;
}

sub get_all_sorted {
  my ($class, %params) = @_;
  my $sort_str         = $class->make_sort_string(sort_by => delete($params{sort_by}), sort_dir => delete($params{sort_dir}));

  return $class->get_all(sort_by => $sort_str, %params);
}

sub _get_sort_spec {
  my ($class) = @_;
  return $sort_spec{$class} ||= _make_sort_spec($class);
}

sub _make_sort_spec {
  my ($class) = @_;

  my %sort_spec = defined &{ "${class}::_sort_spec" } ? $class->_sort_spec : ();

  my $meta = $class->object_class->meta;
  my $table = $meta->table;

  if (!$sort_spec{default}) {
    my @primary_keys = $meta->primary_key;
    $sort_spec{default} = [ "" . $primary_keys[0], 1 ];
  }

  $sort_spec{columns} ||= { SIMPLE => [ map { "$_" } $meta->columns ] };

  if ($sort_spec{columns}->{SIMPLE}) {
    if (!ref($sort_spec{columns}->{SIMPLE}) && ($sort_spec{columns}->{SIMPLE} eq 'ALL')) {
      map { $sort_spec{columns}->{"$_"} ||= "${table}.${_}"} @{ $meta->columns };
      delete $sort_spec{columns}->{SIMPLE};
    } else {
      map { $sort_spec{columns}->{$_} = "${table}.${_}" } @{ delete($sort_spec{columns}->{SIMPLE}) };
    }
  }

  $sort_spec{tiebreaker} ||= [ map { "${table}.${_}" } $meta->primary_key ];

  return \%sort_spec;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::DB::Helper::Sorted - Mixin for a manager class that handles
sorting of database records

=head1 SYNOPSIS

  package SL::DB::Manager::Message;

  use SL::DB::Helper::Sorted;

  sub _sort_spec {
    return ( columns => { recipient_id => [ 'CASE
                                             WHEN recipient_group_id IS NULL THEN lower(recipient.name)
                                             ELSE                                 lower(recipient_group.name)
                                             END',                                      ],
                          sender_id    => [ 'lower(sender.name)',                       ],
                          created_at   => [ 'created_at',                               ],
                          subject      => [ 'lower(subject)',                           ],
                          status       => [ 'NOT COALESCE(unread, FALSE)', 'created_at' ],
                        },
             default => [ 'status', 1 ],
             nulls   => { default => 'LAST',
                          subject => 'FIRST',
                        }
           );
  }

  package SL::Controller::Message;

  sub action_list {
    my $messages = SL::DB::Manager::Message->get_all_sorted(sort_by  => $::form->{sort_by},
                                                            sort_dir => $::form->{sort_dir});
  }

=head1 CLASS FUNCTIONS

=over 4

=item C<make_sort_string %params>

Evaluates C<$params{sort_by}> and C<$params{sort_dir}> and returns an
SQL string suitable for sorting. The package this package is mixed
into has to provide a method L</_sort_spec> that returns a hash whose
structure is explained below. That hash is authoritative in which
columns may be sorted, which column to sort by by default and how to
handle C<NULL> values.

Returns the SQL string in scalar context. In array context it returns
three values: the actual column it sorts by (suitable for another call
to L</make_sort_string>), the actual sort direction (either 0 or 1)
and the SQL string.

=item C<get_all_sorted %params>

Returns C<< $class->get_all >> with C<sort_by> set to the value
returned by c<< $class->make_sort_string(%params) >>.

=back

=head1 CLASS FUNCTIONS PROVIDED BY THE MIXING PACKAGE

=over 4

=item C<_sort_spec>

This method is actually not part of this package but can be provided
by the package this helper is mixed into. If it isn't then all columns
of the corresponding table (as returned by the model's meta data) will
be eligible for sorting.

Returns a hash with the following keys:

=over 2

=item C<default>

A two-element array containing the name and direction by which to sort
in default cases. Example:

  default => [ 'name', 1 ],

Defaults to the table's primary key column (the first column if the
primary key is composited).

=item C<columns>

A hash reference. Its keys are column names, and its values are SQL
strings by which to sort. Example:

  columns => { SIMPLE                  => [ 'transaction_description', 'orddate' ],
               the_date                => 'CASE WHEN oe.quotation THEN oe.quodate ELSE oe.orddate END',
               customer_name           => 'lower(customer.name)',
             },

If sorting is requested for a column that is not a key in this hash
then the default column name will be used.

The value can be either a scalar or an array reference. If it's the
latter then both the sort direction as well as the null handling will
be appended to each of its members.

The special key C<SIMPLE> can be a scalar or an array reference. If it
is an array reference then it contains column names that are mapped
1:1 onto the table's columns. If it is the scalar 'ALL' then all
columns in that model's meta data are mapped 1:1 unless the C<columns>
hash already contains a key for that column.

If C<columns> is missing then all columns of the model will be
eligible for sorting. The list of columns is looked up in the model's
meta data.

=item C<nulls>

Either a scalar or a hash reference determining where C<NULL> values
will be sorted. If undefined then the decision is left to the
database.

If it is a scalar then the same value will be used for all
classes. The value is either C<FIRST> or C<LAST>.

If it is a hash reference then its keys are column names (not SQL
names). The values are either C<FIRST> or C<LAST>. If a column name is
not found in this hash then the special key C<default> will be looked
up and used if it is found.

Example:

  nulls => { transaction_description => 'FIRST',
             customer_name           => 'FIRST',
             default                 => 'LAST',
           },

=item C<tiebreaker>

Optional tiebreaker sorting that gets appended to any user requested sorting.
Needed to make sorting by non unique columns deterministic.

If present must be an arrayref of column sort specs (see C<column>).

Defaults to primary keys.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
