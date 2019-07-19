package DateTime;

use strict;

use DateTime::Format::Strptime;

use SL::Util qw(_hashify);

my ($ymd_parser, $ymdhms_parser);

sub new_local {
  my ($class, %params) = @_;
  return $class->new(hour => 0, minute => 0, second => 0, time_zone => $::locale->get_local_time_zone, %params);
}

sub now_local {
  return shift->now(time_zone => $::locale->get_local_time_zone);
}

sub today_local {
  return shift->now(time_zone => $::locale->get_local_time_zone)->truncate(to => 'day');
}

sub to_kivitendo_time {
  my ($self, %params) = _hashify(1, @_);
  return $::locale->format_date_object_to_time($self, %params);
}

sub to_kivitendo {
  my ($self, %params) = _hashify(1, @_);
  return $::locale->format_date_object($self, %params);
}

sub to_lxoffice {
  # Legacy name.
  goto &to_kivitendo;
}

sub from_kivitendo {
  return $::locale->parse_date_to_object($_[1]);
}

sub from_lxoffice {
  # Legacy name.
  goto &from_kivitendo;
}

sub add_business_duration {
  my ($self, %params) = @_;

  my $abs_days = abs $params{days};
  my $neg      = $params{days} < 0;
  my $bweek    = $params{businessweek} || 5;
  my $weeks    = int ($abs_days / $bweek);
  my $days     = $abs_days % $bweek;

  if ($neg) {
    $self->subtract(weeks => $weeks);
    $self->add(days => 8 - $self->day_of_week) if $self->day_of_week > $bweek;
    $self->subtract(days => $self->day_of_week > $days ? $days : $days + (7 - $bweek));
  } else {
    $self->add(weeks => $weeks);
    $self->subtract(days => $self->day_of_week - $bweek) if $self->day_of_week > $bweek;
    $self->add(days => $self->day_of_week + $days <= $bweek ? $days : $days + (7 - $bweek));
  }

  $self;
}

sub add_businessdays {
  my ($self, %params) = @_;

  $self->add_business_duration(%params);
}

sub subtract_businessdays {
  my ($self, %params) = @_;

  $params{days} *= -1;

  $self->add_business_duration(%params);
}

sub end_of_month {
  my ($self) = @_;
  return $self->truncate(to => 'month')->add(months => 1)->subtract(days => 1);
}

sub next_workday {
  my ($self, %params) = @_;

  my $extra_days = $params{extra_days} // 1;
  $self->add(days => $extra_days);

  my $day_of_week = $self->day_of_week;
  $self->add(days => (8 - $day_of_week)) if $day_of_week >= 6;

  return $self;
}

sub from_ymd {
  my ($class, $ymd_string) = @_;

  if (!$ymd_parser) {
    $ymd_parser = DateTime::Format::Strptime->new(
      pattern   => '%Y-%m-%d',
      locale    => 'de_DE',
      time_zone => 'local'
    );
  }

  return $ymd_parser->parse_datetime($ymd_string // '');
}

sub from_ymdhms {
  my ($class, $ymdhms_string) = @_;

  if (!$ymdhms_parser) {
    $ymdhms_parser = DateTime::Format::Strptime->new(
      pattern   => '%Y-%m-%dT%H:%M:%S',
      locale    => 'de_DE',
      time_zone => 'local'
    );
  }

  $ymdhms_string //= '';
  $ymdhms_string   =~ s{ }{T};

  return $ymdhms_parser->parse_datetime($ymdhms_string);
}

1;

__END__

=encoding utf8

=head1 NAME

SL::Helpers::DateTime - helper functions for L<DateTime>

=head1 FUNCTIONS

=over 4

=item C<new_local %params>

Returns the time given in C<%params> with the time zone set to the
local time zone.

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

=item C<from_ymd $string>

Parses a date string in the ISO 8601 format C<YYYY-MM-DD> and returns
an instance of L<DateTime>. The time is set to midnight (00:00:00).

=item C<from_ymdhms $string>

Parses a date/time string in the ISO 8601 format
C<YYYY-MM-DDTHH:MM:SS> (a space instead of C<T> is also supported) and
returns an instance of L<DateTime>.

=item C<end_of_month>

Sets the object to the last day of object's month at midnight. Returns
the object itself.

=item C<next_workday %params>

Sets the object to the next workday. The recognized parameter is:

=over 2

=item * C<extra_days> - optional: If C<extra_days> is given, then
that amount of days is added to the objects date and if the resulting
date is not a workday, the object is set to the next workday.
Defaults to 1.

=back

Returns the object itself.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
