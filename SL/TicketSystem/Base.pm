package SL::TicketSystem::Base;

use strict;

sub title {
  die "needs to be implemented";
}

sub ticket_columns {
  die "needs to be implemented";
}

sub options_with_defaults {
  die "needs to be implemented";
}

sub get_tickets {
  die "needs to be implemented";
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::TicketSystem::Base - Base class for ticket system providers

=head1 FUNCTIONS

=over 4

=item C<title>

This function returns a human readable description of the ticket system.

=item C<ticket_columns>

This function returns an array reference of hash references, each
describing one column of the ticket report.

=item C<options_with_defaults>

This function returs a hash where the keys denote parameters understood
by C<get_tickets> and the values represent the default values of these
parameters.

=item C<get_tickets>

This class method retrieves the tickets corresponding to the parameters
given as a hash reference as the argument.  The return value is
a two-element list of an array reference to the tickets and a human
readable message string.

=back

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
