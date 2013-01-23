package DateTime;

use strict;

sub now_local {
  return shift->now(time_zone => $::locale->get_local_time_zone);
}

sub today_local {
  return shift->now(time_zone => $::locale->get_local_time_zone)->truncate(to => 'day');
}

sub to_kivitendo {
  my $self   = shift;
  my %params = (scalar(@_) == 1) && (ref($_[0]) eq 'HASH') ? %{ $_[0] } : @_;
  return $::locale->format_date_object($self, %params);
}

sub to_lxoffice {
  # Legacy name.
  goto &to_kivitendo;
}

sub from_kivitendo {
  return $::locale->parse_date_to_object(\%::myconfig, $_[1]);
}

sub from_lxoffice {
  # Legacy name.
  gofrom &from_kivitendo;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::Helpers::DateTime - helper functions for L<DateTime>

=head1 FUNCTIONS

=over 4

=item C<now_local>

Returns the current time with the time zone set to the local time zone.

=item C<today_local>

Returns the current date with the time zone set to the local time zone.

=item C<to_kivitendo %param>

Formats the date and time according to the current kivitendo user's
date format with L<Locale::format_datetime_object>.

The legacy name C<to_lxoffice> is still supported.

=item C<from_kivitendo $string>

Parses a date string formatted in the current kivitendo user's date
format and returns an instance of L<DateTime>.

Note that only dates can be parsed at the moment, not the time
component (as opposed to L<to_kivitendo>).

The legacy name C<from_lxoffice> is still supported.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
