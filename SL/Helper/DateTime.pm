package DateTime;

use strict;

sub now_local {
  return shift->now(time_zone => $::locale->get_local_time_zone);
}

sub today_local {
  return shift->now(time_zone => $::locale->get_local_time_zone)->truncate(to => 'day');
}

sub to_lxoffice {
  return $::locale->format_date(\%::myconfig, $_[0]);
}

sub from_lxoffice {
  return $::locale->parse_date_to_object(\%::myconfig, $_[1]);
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

=item C<to_lxoffice>

Formats the date according to the current Lx-Office user's date
format.

=item C<from_lxoffice>

Parses a date string formatted in the current Lx-Office user's date
format and returns an instance of L<DateTime>.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
