package SL::DBUtils;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(conv_i conv_date do_query selectrow_query do_statement dump_query);

sub conv_i {
  my ($value, $default) = @_;
  return (defined($value) && "$value" ne "") ? $value * 1 : $default;
}

sub conv_date {
  my ($value) = @_;
  return (defined($value) && "$value" ne "") ? $value : undef;
}

sub do_query {
  my ($form, $dbh, $query) = splice(@_, 0, 3);

  if (0 == scalar(@_)) {
    $dbh->do($query) || $form->dberror($query);
  } else {
    $dbh->do($query, undef, @_) ||
      $form->dberror($query . " (" . join(", ", @_) . ")");
  }
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

1;
