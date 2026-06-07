package SL::InstanceState;

use strict;

use SL::DB;
use SL::DBUtils;

use parent qw(Rose::Object);


sub has_employee_project_invoices {
  return !!0 unless $::myconfig{login};

  # We can't use Rose here because this is used in the menu.
  # The menu is set up before any DB upgrade scripts are running and
  # if there is a DB upgrade affecting the employee table
  # (adding/deleting rows), we will get an error because Rose metadata
  # and the DB table are out of sync.
  # So do this with an SQL query.
  my $query = <<SQL;
    SELECT COUNT(id) FROM employee_project_invoices LEFT JOIN employee ON (employee.id = employee_id) WHERE login = ?;
SQL

  my ($count) = selectrow_query($::form, SL::DB->client->dbh, $query, $::myconfig{login});

  return !!$count;
}


1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::InstanceState - Provides instance-specific status information

=head1 SYNOPSIS

While instance configuration settings are provided via C<SL::InstanceConf>,
this module provides non-configuration information of the instance.

The intention is to use the state information in the menu, e.g. to enable
or disable some menu entries if some condition is met.

Example: If a user has no right to see invoices, the menu entry for this report
was shown anyway, because the user may has the right to access project invoices.
Now, the display of the menu entry can be made dependent on the status.
See C<SL::Menu>.

=head1 FUNCTIONS

=over 4

=item C<has_employee_project_invoices>

Returns trueish if the current employee has the right to access
some project invoices.

=back

=head1 TODO

As for now, no global instance of this class is provided. If this information
should be used in e.g. templates or some other programm code, then a global
instance may should be provided.

=head1 BUGS

none so far

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
