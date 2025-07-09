package SL::InstanceState;

use strict;

use SL::DB::Manager::Employee;

use parent qw(Rose::Object);


sub has_employee_project_invoices {
  SL::DB::Manager::Employee->current && @{SL::DB::Manager::Employee->current->project_invoice_permissions};
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
