package SL::DBUtils;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(conv_i conv_date do_query dump_query);

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
