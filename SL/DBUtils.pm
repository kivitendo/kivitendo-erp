package SL::DBUtils;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(conv_i conv_date conv_dateq do_query selectrow_query do_statement
             dump_query quote_db_date
             selectfirst_hashref_query selectfirst_array_query
             selectall_hashref_query selectall_array_query
             selectall_as_map
             prepare_execute_query prepare_query);

sub conv_i {
  my ($value, $default) = @_;
  return (defined($value) && "$value" ne "") ? $value * 1 : $default;
}

sub conv_date {
  my ($value) = @_;
  return (defined($value) && "$value" ne "") ? $value : undef;
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

  dump_query(LXDebug::QUERY, '', $query, @_);

  if (0 == scalar(@_)) {
    $dbh->do($query) || $form->dberror($query);
  } else {
    $dbh->do($query, undef, @_) ||
      $form->dberror($query . " (" . join(", ", @_) . ")");
  }

  $main::lxdebug->leave_sub(2);
}

sub selectrow_query { &selectfirst_array_query }

sub do_statement {
  $main::lxdebug->enter_sub(2);

  my ($form, $sth, $query) = splice(@_, 0, 3);

  dump_query(LXDebug::QUERY, '', $query, @_);

  if (0 == scalar(@_)) {
    $sth->execute() || $form->dberror($query);
  } else {
    $sth->execute(@_) ||
      $form->dberror($query . " (" . join(", ", @_) . ")");
  }

  $main::lxdebug->leave_sub(2);
}

sub dump_query {
  my ($level, $msg, $query) = splice(@_, 0, 3);

  my $filename = $self_filename = 'SL/DBUtils.pm';
  my $caller_level;
  while ($filename eq $self_filename) {
    (undef, $filename, $line, $subroutine) = caller $caller_level++;
  }

  while ($query =~ /\?/) {
    my $value = shift(@_);
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

  $str =~ s/'/''/g;
  return "'$str'";
}

sub prepare_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  dump_query(LXDebug::QUERY, '', $query, @_);

  my $sth = $dbh->prepare($query) || $form->dberror($query);

  $main::lxdebug->leave_sub(2);

  return $sth;
}

sub prepare_execute_query {
  $main::lxdebug->enter_sub(2);

  my ($form, $dbh, $query) = splice(@_, 0, 3);

  dump_query(LXDebug::QUERY, '', $query, @_);

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

  my $sth = prepare_execute_query($form, $dbh, $query, @_);
  my $result = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{ $result }, $ref);
  }
  $sth->finish();

  $main::lxdebug->leave_sub(2);

  return $result;
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
      $hash{$ref->{$key_col}} = $ref->{$value_col};
    }
  } else {
    while (my $ref = $sth->fetchrow_hashref()) {
      $hash{$ref->{$key_col}} = { map { $_ => $ref->{$_} } @{ $value_col } };
    }
  }

  $sth->finish();

  $main::lxdebug->leave_sub(2);

  return %hash;
}

1;


__END__

=head1 NAME

SL::DBUTils.pm: All about Databaseconections in Lx

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
  
    
=head1 DESCRIPTION

DBUtils is the attempt to reduce the amount of overhead it takes to retrieve information from the database in Lx-Office. Previously it would take about 15 lines of code just to get one single integer out of the database, including failure procedures and importing the necessary packages. Debugging would take even more.

Using DBUtils most database procedures can be reduced to defining the query, executing it, and retrieving the result. Let DBUtils handle the rest. Whenever there is a database operation not covered in DBUtils, add it here, rather than working around it in the backend code.

DBUtils relies heavily on two parameters which have to be passed to almost every function: $form and $dbh.
  - $form is used for error handling only. It can be omitted in theory, but should not.
  - $dbh is a handle to the databe, as returned by the DBI::connect routine. If you don't have an active connectiong, you can query $form->get_standard_dbh() to get a generic no_auto connection. Don't forget to commit in this case!


Every function here should accomplish the follwing things:
  - Easy debugging. Every handled query gets dumped via LXDebug, if specified there.
  - Safe value binding. Although DBI is far from perfect in terms of binding, the rest of the bindings should happen here.
  - Error handling. Should a query fail, an error message will be generated here instead of in the backend code invoking DBUtils.

Note that binding is not perfect here either... 
  
=head2 QUOTING FUNCTIONS

=over 4

=item conv_i STR

=item conv_i STR,DEFAULT

Converts STR to an integer. If STR is empty, returns DEFAULT. If no DEFAULT is given, returns undef.

=item conv_date STR

Converts STR to a date string. If STR is emptry, returns undef.

=item conv_dateq STR

Database version of conv_date. Quotes STR before returning. Returns 'NULL' if STR is empty.

=item quote_db_date STR

Treats STR as a database date, quoting it. If STR equals current_date returns an escaped version which is treated as the current date by Postgres.
Returns 'NULL' if STR is empty.

=back

=head2 QUERY FUNCTIONS

=over 4

=item do_query FORM,DBH,QUERY,ARRAY

Uses DBI::do to execute QUERY on DBH using ARRAY for binding values. FORM is only needed for error handling, but should always be passed nevertheless. Use this for insertions or updates that don't need to be prepared.

=item do_statement FORM,STH,QUERY,ARRAY

Uses DBI::execute to execute QUERY on DBH using ARRAY for binding values. As with do_query, FORM is only used for error handling. If you are unsure what to use, refer to the documentation of DBI::do and DBI::execute.

=item prepare_execute_query FORM,DBH,QUERY,ARRAY

Prepares and executes QUERY on DBH using DBI::prepare and DBI::execute. ARRAY is passed as binding values to execute.

=back

=head2 RETRIEVAL FUNCTIONS

=over 4

=item selectfirst_array_query FORM,DBH,QUERY,ARRAY

=item selectrow_query FORM,DBH,QUERY,ARRAY

Prepares and executes a query using DBUtils functions, retireves the first row from the database, and returns it as an arrayref of the first row. 

=item selectfirst_hashref_query FORM,DBH,QUERY,ARRAY

Prepares and executes a query using DBUtils functions, retireves the first row from the database, and returns it as a hashref of the first row. 

=item selectall_hashref_query FORM,DBH,QUERY,ARRAY

Prepares and executes a query using DBUtils functions, retireves all data from the database, and returns it in hashref mode. This is slightly confusing, as the data structure will actually be a reference to an array, containing hashrefs for each row.

=item selectall_as_map FORM,DBH,QUERY,KEY_COL,VALUE_COL,ARRAY

Prepares and executes a query using DBUtils functions, retireves all data from the database, and creates a hash from the results using KEY_COL as the column for the hash keys and VALUE_COL for its values.

=back

=head2 DEBUG FUNCTIONS

=over 4

=item dump_query LEVEL,MSG,QUERY,ARRAY

Dumps a query using LXDebug->message, using LEVEL for the debug-level of LXDebug. If MSG is given, it preceeds the QUERY dump in the logfiles. ARRAY is used to interpolate the '?' placeholders in QUERY, the resulting QUERY can be copy-pasted into a database frontend for debugging. Note that this method is also automatically called by each of the other QUERY FUNCTIONS, so there is in general little need to invoke it manually.

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
    $query = qq|SELECT l.id, l.description, tr.translation, tr.longdescription
                  FROM language l
                  LEFT OUTER JOIN translation tr ON (tr.language_id = l.id) AND (tr.parts_id = ?)|;
    @values = (conv_i($form->{id}));
  } else {
    $query = qq|SELECT id, description FROM language|;
  }
  
  my $languages = selectall_hashref_query($form, $dbh, $query, @values);

=back

=head1 SEE ALSO

=head1 MODULE AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>
Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>
 
=head1 DOCUMENTATION AUTHORS

Udo Spallek E<lt>udono@gmx.netE<gt>
Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Lx-Office Community

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
