package SL::DBUtils;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(conv_i conv_date conv_dateq do_query selectrow_query do_statement
             dump_query quote_db_date selectall_hashref_query selectfirst_hashref_query
             prepare_execute_query);

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
  my ($form, $dbh, $query) = splice(@_, 0, 3);

  if (0 == scalar(@_)) {
    $dbh->do($query) || $form->dberror($query);
  } else {
    $dbh->do($query, undef, @_) ||
      $form->dberror($query . " (" . join(", ", @_) . ")");
  }
  dump_query(LXDebug::QUERY, '', $query . " (" . join(", ", @_) . ")");
}

sub selectrow_query {
  my ($form, $dbh, $query) = splice(@_, 0, 3);

  if (0 == scalar(@_)) {
    my @results = $dbh->selectrow_array($query);
    $form->dberror($query) if ($dbh->err);
    return @results;
  } else {
    my @results = $dbh->selectrow_array($query, undef, @_);
    $form->dberror($query . " (" . join(", ", @_) . ")") if ($dbh->err);
    return @results;
  }
}

sub do_statement {
  my ($form, $sth, $query) = splice(@_, 0, 3);

  if (0 == scalar(@_)) {
    $sth->execute() || $form->dberror($query);
  } else {
    $sth->execute(@_) ||
      $form->dberror($query . " (" . join(", ", @_) . ")");
  }
}

sub dump_query {
  my ($level, $msg, $query) = splice(@_, 0, 3);
  while ($query =~ /\?/) {
    my $value = shift(@_);
    $value =~ s/\'/\\\'/g;
    $value = "'${value}'";
    $query =~ s/\?/$value/;
  }

  $msg .= " " if ($msg);

  $main::lxdebug->message($level, $msg . $query);
}

sub quote_db_date {
  my ($str) = @_;
  return "NULL" unless defined $str;
  return "current_date" if $str =~ /current_date/;
  $str =~ s/'/''/g;
  return "'$str'";
}

sub prepare_execute_query {
  my ($form, $dbh, $query) = splice(@_, 0, 3);
  my $sth = $dbh->prepare($query) || $form->dberror($query);
  if (scalar(@_) != 0) {
    $sth->execute(@_) || $form->dberror($query . " (" . join(", ", @_) . ")");
  } else {
    $sth->execute() || $form->dberror($query);
  }

  return $sth;
}

sub selectall_hashref_query {
  my ($form, $dbh, $query) = splice(@_, 0, 3);

  my $sth = prepare_execute_query($form, $dbh, $query, @_);
  my $result = [];
  while (my $ref = $sth->fetchrow_hashref()) {
    push(@{ $result }, $ref);
  }
  $sth->finish();

  return $result;
}

sub selectfirst_hashref_query {
  my ($form, $dbh, $query) = splice(@_, 0, 3);

  my $sth = prepare_execute_query($form, $dbh, $query, @_);
  my $ref = $sth->fetchrow_hashref();
  $sth->finish();

  return $ref;
}

1;
