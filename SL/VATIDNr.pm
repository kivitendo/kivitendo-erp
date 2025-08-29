package SL::VATIDNr;

use strict;
use warnings;

use Algorithm::CheckDigits;

sub clean {
  my ($class, $ustid) = @_;

  $ustid //= '';
  $ustid   =~ s{[[:space:].-]+}{}g;

  return $ustid;
}

sub normalize {
  my ($class, $ustid) = @_;

  $ustid = $class->clean($ustid);

  if ($ustid =~ m{^CHE(\d{3})(\d{3})(\d{3})$}) {
    return sprintf('CHE-%s.%s.%s', $1, $2, $3);
  }

  return $ustid;
}

sub _validate_switzerland {
  my ($ustid) = @_;

  return $ustid =~ m{^CHE\d{9}$} ? 1 : 0;
}

sub _validate_european_union {
  my ($ustid) = @_;

  # 1. Two upper-case letters with the ISO 3166-1 Alpha-2 country code (exception: Greece uses EL instead of GR)
  # 2. Up to twelve alphanumeric characters

  return 0 unless $ustid =~ m{^(?:AT|BE|BG|CY|CZ|DE|DK|EE|EL|ES|FI|FR|GB|HR|HU|IE|IT|LT|LU|LV|MT|NL|PL|PT|RO|SE|SI|SK|SM|XI)[[:alnum:]]{1,12}$};

  my $algo_name = "ustid_" . lc(substr($ustid, 0, 2));
  my $checker   = eval { CheckDigits($algo_name) };

  return $checker->is_valid(substr($ustid, 2)) if $checker;
  return 1;
}

sub validate {
  my ($class, $ustid) = @_;

  $ustid = $class->clean($ustid);

  return _validate_switzerland($ustid) if $ustid =~ m{^CHE};
  return _validate_european_union($ustid);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::VATIDNr - Helper routines for dealing with VAT ID numbers
("Umsatzsteuer-Identifikationsnummern", "UStID-Nr" in German) and
Switzerland's enterprise identification numbers (UIDs)

=head1 SYNOPSIS

    my $is_valid = SL::VATIDNr->validate($ustid);

=head1 FUNCTIONS

=over 4

=item C<clean> C<$ustid>

Returns the number with all spaces, dashes & points removed.

=item C<normalize> C<$ustid>

Normalizes the given number to the format usually used in the country
given by the country code at the start of the number
(e.g. C<CHE-123.456.789> for a Swiss UID or DE123456789 for a German
VATIDNr).

=item C<validate> C<$ustid>

Returns whether or not a number is valid. Depending on the country
code at the start several tests are done including check digit
validation.

The number in question is first run through the L</clean> function and
may therefore contain certain ignored characters.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
