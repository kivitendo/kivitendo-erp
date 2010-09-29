package SL::Printer;

use SL::DBUtils;

sub all_printers {
  $::lxdebug->enter_sub;

  my ($self, %params) = @_;

  my $dbh = $::auth->get_user_dbh($params{login});

  my $query = qq|SELECT * FROM printers ORDER BY printer_description|;
  my @printers = selectall_hashref_query($::form, $dbh, $query);

  $::lxdebug->leave_sub;

  return wantarray ? @printers : \@printers;
}

sub get_printer {
  $::lxdebug->enter_sub;

  my ($self, %params) = @_;

  my $dbh = $::auth->get_user_dbh($params{login});

  my $query = qq|SELECT * FROM printers WHERE id = ?|;
  my ($printer) = selectfirst_hashref_query($::form, $dbh, $query, $params{id});

  $::lxdebug->leave_sub;

  return $printer;
}

sub save_printer {
  $main::lxdebug->enter_sub();

  my ($self, %params) = @_;

  # connect to database
  my $dbh = $::auth->get_user_dbh($params{login});
  my $printer = $params{printer};

  unless ($printer->{id}) {
    ($printer->{id}) = selectfirst_array_query($::form, $dbh, "SELECT nextval('id'::text)");
    do_query($::form, $dbh, "INSERT INTO printers (id, printer_description) VALUES (?, '')", $printer->{id});
  }

  my $query = <<SQL;
    UPDATE printers SET
      printer_description = ?,
      template_code = ?,
      printer_command = ?
    WHERE id = ?
SQL
  do_query($::form, $dbh, $query,
    $printer->{printer_description},
    $printer->{template_code},
    $printer->{printer_command},
    $printer->{id},
  );

  $dbh->commit;

  $::lxdebug->leave_sub;
}

sub delete_printer {
  $::lxdebug->enter_sub;

  my ($self, %params) = @_;

  my $dbh = $::auth->get_user_dbh($params{login});

  my $query = qq|DELETE FROM printers WHERE id = ?|;
  do_query($::form, $dbh, $query, $params{id});

  $dbh->commit;

  $::lxdebug->leave_sub;
}

1;
