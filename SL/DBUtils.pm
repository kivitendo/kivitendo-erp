package SL::DBUtils;

use SL::Util qw(trim);

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(conv_i conv_date conv_dateq do_query selectrow_query do_statement
             dump_query quote_db_date like
             selectfirst_hashref_query selectfirst_array_query
             selectall_hashref_query selectall_array_query
             selectall_as_map
             selectall_ids
             prepare_execute_query prepare_query
             create_sort_spec does_table_exist
             add_token);

use strict;

sub conv_i {
  my ($value, $default) = @_;
  return (defined($value) && "$value" ne "") ? $value * 1 : $default;
}

# boolean escape
sub conv_b {
  my ($value, $default) = @_;
  return !defined $value && defined $default ? $default
       :          $value                     ? 't'
       :                                       'f';
}

sub conv_date {
  my ($value) = @_;
  return undef if !defined $value;
  $value = trim($value);
  return $value eq "" ? undef : $value;
}

sub conv_dateq {
  my ($value) = @_;
  if (defined($value) && "$value" ne "") {
    $value =~ s/\'/\'\'/g;
    return "'$value'";
  }
  return "NULL";
}

sub do_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  dump_query(LXDebug->QUERY(), '', $query, @_);

  my $result;
  if (0 == scalar(@_)) {
    $result = $dbh->do($query)            || $form->dberror($query);
  } else {
    $result = $dbh->do($query, undef, @_) || $form->dberror($query . " (" . join(", ", @_) . ")");
  }

  $main::lxdebug->leave_sub(2);

  return $result;
}

sub selectrow_query { &selectfirst_array_query }

sub do_statement {
  $main::lxdebug->enter_sub(2);

  my ($form, $sth, $query) = splice(@_, 0, 3);

  dump_query(LXDebug->QUERY(), '', $query, @_);

  my $result;
  if (0 == scalar(@_)) {
    $result = $sth->execute()   || $form->dberror($query);
  } else {
    $result = $sth->execute(@_) || $form->dberror($query . " (" . join(", ", @_) . ")");
  }

  $main::lxdebug->leave_sub(2);

  return $result;
}

sub dump_query {
  my ($level, $msg, $query) = splice(@_, 0, 3);

  my $self_filename = 'SL/DBUtils.pm';
  my $filename      = $self_filename;
  my ($caller_level, $line, $subroutine);
  while ($filename eq $self_filename) {
    (undef, $filename, $line, $subroutine) = caller $caller_level++;
  }

  while ($query =~ /\?/) {
    my $value = shift || '';
    $value =~ s/\'/\\\'/g;
    $value = "'${value}'";
    $query =~ s/\?/$value/;
  }

  $query =~ s/[\n\s]+/ /g;

  $msg .= " " if ($msg);

  my $info = "$subroutine called from $filename:$line\n";

  $main::lxdebug->message($level, $info . $msg . $query);
}

sub quote_db_date {
  my ($str) = @_;

  return "NULL" unless defined $str;
  return "current_date" if $str =~ /current_date/;

  $str =~ s/\'/\'\'/g;
  return "'$str'";
}

sub prepare_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  dump_query(LXDebug->QUERY(), '', $query, @_);

  my $sth = $dbh->prepare($query) || $form->dberror($query);

  $main::lxdebug->leave_sub(2);

  return $sth;
}

sub prepare_execute_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  dump_query(LXDebug->QUERY(), '', $query, @_);

  my $sth = $dbh->prepare($query) || $form->dberror($query);
  if (scalar(@_) != 0) {
    $sth->execute(@_) || $form->dberror($query . " (" . join(", ", @_) . ")");
  } else {
    $sth->execute() || $form->dberror($query);
  }

  $main::lxdebug->leave_sub(2);

  return $sth;
}

sub selectall_hashref_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  dump_query(LXDebug->QUERY(), '', $query, @_);

  # this works back 'til at least DBI 1.46 on perl 5.8.4 on Debian Sarge (2004)
  my $result = $dbh->selectall_arrayref($query, { Slice => {} }, @_)
    or $form->dberror($query . (@_ ? " (" . join(", ", @_) . ")" : ''));

  $main::lxdebug->leave_sub(2);

  return wantarray ? @{ $result } : $result;
}

sub selectall_array_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  my $sth = prepare_execute_query($form, $dbh, $query, @_);
  my @result;
  while (my ($value) = $sth->fetchrow_array()) {
    push(@result, $value);
  }
  $sth->finish();

  $main::lxdebug->leave_sub(2);

  return @result;
}

sub selectfirst_hashref_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  my $sth = prepare_execute_query($form, $dbh, $query, @_);
  my $ref = $sth->fetchrow_hashref();
  $sth->finish();

  $main::lxdebug->leave_sub(2);

  return $ref;
}

sub selectfirst_array_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  my $sth = prepare_execute_query($form, $dbh, $query, @_);
  my @ret = $sth->fetchrow_array();
  $sth->finish();

  $main::lxdebug->leave_sub(2);

  return @ret;
}

sub selectall_as_map {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query, $key_col, $value_col) = splice(@_, 0, 5);

  my $sth = prepare_execute_query($form, $dbh, $query, @_);

  my %hash;
  if ('' eq ref $value_col) {
    while (my $ref = $sth->fetchrow_hashref()) {
      $hash{$ref->{$key_col} // ''} = $ref->{$value_col};
    }
  } else {
    while (my $ref = $sth->fetchrow_hashref()) {
      $hash{$ref->{$key_col} // ''} = { map { $_ => $ref->{$_} } @{ $value_col } };
    }
  }

  $sth->finish();

  $main::lxdebug->leave_sub(2);

  return %hash;
}

sub selectall_ids {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query, $key_col) = splice(@_, 0, 4);

  my $sth = prepare_execute_query($form, $dbh, $query, @_);

  my @ids;
  while (my $ref = $sth->fetchrow_arrayref()) {
    push @ids, $ref->[$key_col];
  }

  $sth->finish;

  $main::lxdebug->leave_sub(2);

  return @ids;
}

sub create_sort_spec {
  $main::lxdebug->enter_sub(2);

  my %params = @_;

  # Safety check:
  $params{defs}    || die;
  $params{default} || die;

  # The definition of valid columns to sort by.
  my $defs        = $params{defs};

  # The column name to sort by. Use the default column name if none was given.
  my %result      = ( 'column' => $params{column} || $params{default} );

  # Overwrite the column name with the default column name if the other one is not valid.
  $result{column} = $params{default} unless ($defs->{ $result{column} });

  # The sort direction. true means 'sort ascending', false means 'sort descending'.
  $result{dir}    = defined $params{dir}         ? $params{dir}
                  : defined $params{default_dir} ? $params{default_dir}
                  :                                1;
  $result{dir}    = $result{dir} ?     1 :      0;
  my $asc_desc    = $result{dir} ? 'ASC' : 'DESC';

  # Create the SQL code.
  my $cols        = $defs->{ $result{column} };
  $result{sql}    = join ', ', map { "${_} ${asc_desc}" } @{ ref $cols eq 'ARRAY' ? $cols : [ $cols ] };

  $main::lxdebug->leave_sub(2);

  return %result;
}

sub does_table_exist {
  $main::lxdebug->enter_sub(2);

  my $dbh    = shift;
  my $table  = shift;

  my $result = 0;

  if ($dbh) {
    my $sth = $dbh->table_info('', '', $table, 'TABLE');
    if ($sth) {
      $result = $sth->fetchrow_hashref();
      $sth->finish();
    }
  }

  $main::lxdebug->leave_sub(2);

  return $result;
}

# add token to values.
# usage:
#  add_token(
#    \@where_tokens,
#    \@where_values,
#    col => 'id',
#    val => [ 23, 34, 17 ]
#    esc => \&conf_i
#  )
#  will append to the given arrays:
#   -> 'id IN (?, ?, ?)'
#   -> (conv_i(23), conv_i(34), conv_i(17))
#
#  features:
#   - don't care if one or multiple values are given. singlewill result in 'col = ?'
#   - pass escape routines
#   - expand for future method
#   - no need to type "push @where_tokens, 'id = ?'" over and over again
sub add_token {
  my $tokens = shift() || [];
  my $values = shift() || [];
  my %params = @_;
  my $col    = $params{col};
  my $val    = $params{val};
  my $escape = $params{esc} || sub { $_ };
  my $method = $params{esc} =~ /^start|end|substr$/ ? 'ILIKE' : $params{method} || '=';

  $val = [ $val ] unless ref $val eq 'ARRAY';

  my %escapes = (
    id     => \&conv_i,
    bool   => \&conv_b,
    date   => \&conv_date,
    start  => sub { trim($_[0]) . '%' },
    end    => sub { '%' . trim($_[0]) },
    substr => sub { like($_[0]) },
  );

  my $_long_token = sub {
    my $op = shift;
    sub {
      my $col = shift;
      return scalar @_ ? join ' OR ', ("$col $op ?") x scalar @_,
           :             undef;
    }
  };

  my %methods = (
    '=' => sub {
      my $col = shift;
      return scalar @_ >  1 ? sprintf '%s IN (%s)', $col, join ', ', ("?") x scalar @_
           : scalar @_ == 1 ? sprintf '%s = ?',     $col
           :                  undef;
    },
    map({ $_ => $_long_token->($_) } qw(LIKE ILIKE >= <= > <)),
  );

  $method = $methods{$method} || $method;
  $escape = $escapes{$escape} || $escape;

  my $token = $method->($col, @{ $val });
  my @vals  = map { $escape->($_) } @{ $val };

  return unless $token;

  push @{ $tokens }, $token;
  push @{ $values }, @vals;

  return ($token, @vals);
}

sub like {
  my ($string) = @_;

  return "%" . SL::Util::trim($string // '') . "%";
}

sub role_is_superuser {
  my ($dbh, $login)  = @_;
  my ($is_superuser) = $dbh->selectrow_array(qq|SELECT usesuper FROM pg_user WHERE usename = ?|, undef, $login);

  return $is_superuser;
}

1;


__END__

=encoding utf-8

=head1 NAME

SL::DBUTils.pm: All about database connections in kivitendo

=head1 SYNOPSIS

  use DBUtils;

  conv_i($str, $default)
  conv_date($str)
  conv_dateq($str)
  quote_db_date($date)

  do_query($form, $dbh, $query)
  do_statement($form, $sth, $query)

  dump_query($level, $msg, $query)
  prepare_execute_query($form, $dbh, $query)

  my $all_results_ref       = selectall_hashref_query($form, $dbh, $query)
  my $first_result_hash_ref = selectfirst_hashref_query($form, $dbh, $query);

  my @first_result =  selectfirst_array_query($form, $dbh, $query);  # ==
  my @first_result =  selectrow_query($form, $dbh, $query);

  my %sort_spec = create_sort_spec(%params);

=head1 DESCRIPTION

DBUtils provides wrapper functions for low level database retrieval. It saves
you the trouble of mucking around with statement handles for small database
queries and does exception handling in the common cases for you.

Query and retrieval functions share the parameter scheme:

  query_or_retrieval(C<FORM, DBH, QUERY[, BINDVALUES]>)

=over 4

=item *

C<FORM> is used for error handling only. It can be omitted in theory, but should
not. In most cases you will call it with C<$::form>.

=item *

C<DBH> is a handle to the database, as returned by the C<DBI::connect> routine.
If you don't have an active connection, you can use
C<<$::form->get_standard_dbh>> to get a generic no_auto connection or get a
C<Rose::DB::Object> handle from any RDBO class with
C<<SL::DB::Part->new->db->dbh>>. The former will be without autocommit, the
latter with autocommit.

See C<PITFALLS AND CAVEATS> for common errors.

=item *

C<QUERY> must be exactly one query. You don't need to include the terminal
C<;>. There must be no tainted data interpolated into the string. Instead use
the DBI placeholder syntax.

=item *

All additional parameters will be used as C<BINDVALUES> for the query. Note
that DBI can't bind arrays to a C<id IN (?)>, so you will need to generate a
statement with exactly one C<?> for each bind value. DBI can however bind
DateTime objects, and you should always pass these for date selections.

=back

=head1 PITFALLS AND CAVEATS

=head2 Locking

As mentioned above, there are two sources of database handles in the program:
C<<$::form->get_standard_dbh>> and C<<SL::DB::Object->new->db->dbh>>. It's easy
to produce deadlocks when using both of them. To reduce the likelyhood of
locks, try to obey these rules:

=over 4

=item *

In a controller that uses Rose objects, never use C<get_standard_dbh>.

=item *

In backend code, that has no preference, always accept the database handle as a
parameter from the controller.

=back

=head2 Exports

C<DBUtils> is one of the last modules in the program to use C<@EXPORT> instead
of C<@EXPORT_OK>. This means it will flood your namespace with its functions,
causing potential clashes. When writing new code, always either export nothing
and call directly:

  use SL::DBUtils ();
  DBUtils::selectall_hashref_query(...)

or export only what you need:

  use SL::DBUtils qw(selectall_hashref_query);
  selectall_hashref_query(...)


=head2 Peformance

Since it is really easy to write something like

  my $all_parts = selectall_hashref_query($::form, $dbh, 'SELECT * FROM parts');

people do so from time to time. When writing code, consider this a ticking
timebomb. Someone out there has a database with 1mio parts in it, and this
statement just shovelled ate 2GB of memory and timeouted the request.

Parts may be the obvious example, but the same applies to customer, vendors,
records, projects or custom variables.


=head1 QUOTING FUNCTIONS

=over 4

=item conv_i STR

=item conv_i STR,DEFAULT

Converts STR to an integer. If STR is empty, returns DEFAULT. If no DEFAULT is
given, returns undef.

=item conv_date STR

Converts STR to a date string. If STR is emptry, returns undef.

=item conv_dateq STR

Database version of conv_date. Quotes STR before returning. Returns 'NULL' if
STR is empty.

=item quote_db_date STR

Treats STR as a database date, quoting it. If STR equals current_date returns
an escaped version which is treated as the current date by Postgres.

Returns C<'NULL'> if STR is empty.

=item like STR

Turns C<STR> into an argument suitable for SQL's C<LIKE> and C<ILIKE>
operators by Trimming the string C<STR> (removes leading and trailing
whitespaces) and prepending and appending C<%>.

=back

=head1 QUERY FUNCTIONS

=over 4

=item do_query FORM,DBH,QUERY,ARRAY

Uses DBI::do to execute QUERY on DBH using ARRAY for binding values. FORM is
only needed for error handling, but should always be passed nevertheless. Use
this for insertions or updates that don't need to be prepared.

Returns the result of DBI::do which is -1 in case of an error and the number of
affected rows otherwise.

=item do_statement FORM,STH,QUERY,ARRAY

Uses DBI::execute to execute QUERY on DBH using ARRAY for binding values. As
with do_query, FORM is only used for error handling. If you are unsure what to
use, refer to the documentation of DBI::do and DBI::execute.

Returns the result of DBI::execute which is -1 in case of an error and the
number of affected rows otherwise.

=item prepare_execute_query FORM,DBH,QUERY,ARRAY

Prepares and executes QUERY on DBH using DBI::prepare and DBI::execute. ARRAY
is passed as binding values to execute.

=back

=head1 RETRIEVAL FUNCTIONS

=over 4

=item selectfirst_array_query FORM,DBH,QUERY,ARRAY

=item selectrow_query FORM,DBH,QUERY,ARRAY

Prepares and executes a query using DBUtils functions, retrieves the first row
from the database, and returns it as an arrayref of the first row.

=item selectfirst_hashref_query FORM,DBH,QUERY,ARRAY

Prepares and executes a query using DBUtils functions, retrieves the first row
from the database, and returns it as a hashref of the first row.

=item selectall_hashref_query FORM,DBH,QUERY,ARRAY

Prepares and executes a query using DBUtils functions, retrieves all data from
the database, and returns it in hashref mode. This is slightly confusing, as
the data structure will actually be a reference to an array, containing
hashrefs for each row.

=item selectall_as_map FORM,DBH,QUERY,KEY_COL,VALUE_COL,ARRAY

Prepares and executes a query using DBUtils functions, retrieves all data from
the database, and creates a hash from the results using KEY_COL as the column
for the hash keys and VALUE_COL for its values.

=back

=head1 UTILITY FUNCTIONS

=over 4

=item create_sort_spec

  params:
    defs        => { },         # mandatory
    default     => 'name',      # mandatory
    column      => 'name',
    default_dir => 0|1,
    dir         => 0|1,

  returns hash:
    column      => 'name',
    dir         => 0|1,
    sql         => 'SQL code',

This function simplifies the creation of SQL code for sorting
columns. It uses a hashref of valid column names, the column name and
direction requested by the user, the application defaults for the
column name and the direction and returns the actual column name,
direction and SQL code that can be used directly in a query.

The parameter 'defs' is a hash reference. The keys are the column
names as they may come from the application. The values are either
scalars with SQL code or array references of SQL code. Example:

  defs => {
    customername => 'lower(customer.name)',
    address      => [ 'lower(customer.city)', 'lower(customer.street)' ],
  }

'default' is the default column name to sort by. It must be a key of
'defs' and should not be come from user input.

The 'column' parameter is the column name as requested by the
application (e.g. if the user clicked on a column header in a
report). If it is invalid then the 'default' parameter will be used
instead.

'default_dir' is the default sort direction. A true value means 'sort
ascending', a false one 'sort descending'. 'default_dir' defaults to
'1' if undefined.

The 'dir' parameter is the sort direction as requested by the
application (e.g. if the user clicked on a column header in a
report). If it is undefined then the 'default_dir' parameter will be
used instead.

=back

=head1 DEBUG FUNCTIONS

=over 4

=item dump_query LEVEL,MSG,QUERY,ARRAY

Dumps a query using LXDebug->message, using LEVEL for the debug-level of
LXDebug. If MSG is given, it preceeds the QUERY dump in the logfiles. ARRAY is
used to interpolate the '?' placeholders in QUERY, the resulting QUERY can be
copy-pasted into a database frontend for debugging. Note that this method is
also automatically called by each of the other QUERY FUNCTIONS, so there is in
general little need to invoke it manually.

=back

=head1 EXAMPLES

=over 4

=item Retrieving a whole table:

  $query = qq|SELECT id, pricegroup FROM pricegroup|;
  $form->{PRICEGROUPS} = selectall_hashref_query($form, $dbh, $query);

=item Retrieving a single value:

  $query = qq|SELECT nextval('glid')|;
  ($new_id) = selectrow_query($form, $dbh, $query);

=item Using binding values:

  $query = qq|UPDATE ar SET paid = amount + paid, storno = 't' WHERE id = ?|;
  do_query($form, $dbh, $query, $id);

=item A more complicated example, using dynamic binding values:

  my @values;

  if ($form->{language_values} ne "") {
    $query = qq|
      SELECT l.id, l.description, tr.translation, tr.longdescription
      FROM language l
      LEFT JOIN translation tr ON (tr.language_id = l.id AND tr.parts_id = ?)
    |;
    @values = (conv_i($form->{id}));
  } else {
    $query = qq|SELECT id, description FROM language|;
  }

  my $languages = selectall_hashref_query($form, $dbh, $query, @values);

=back

=head1 MODULE AUTHORS

  Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>
  Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=head1 DOCUMENTATION AUTHORS

  Udo Spallek E<lt>udono@gmx.netE<gt>
  Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by kivitendo Community

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
