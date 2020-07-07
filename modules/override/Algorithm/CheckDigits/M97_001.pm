package Algorithm::CheckDigits::M97_001;

use 5.006;
use strict;
use warnings;
use integer;

use version; our $VERSION = 'v1.3.2';

our @ISA = qw(Algorithm::CheckDigits);

sub new {
	my $proto = shift;
	my $type  = shift;
	my $class = ref($proto) || $proto;
	my $self  = bless({}, $class);
	$self->{type} = lc($type);
	return $self;
} # new()

sub is_valid {
	my ($self,$number) = @_;
	if ($number =~ /^(\d{7,8})?(\d\d)$/i) {
		return $2 eq $self->_compute_checkdigit($1);
	}
	return ''
} # is_valid()

sub complete {
	my ($self,$number) = @_;
	if ($number =~ /^(\d{7,8})$/i) {
		return sprintf('%08d', $number) . $self->_compute_checkdigit($1);
	}
	return '';
} # complete()

sub basenumber {
	my ($self,$number) = @_;
	if ($number =~ /^(\d{7,8})(\d\d)$/i) {
		return sprintf('%08d', $1) if ($2 eq $self->_compute_checkdigit($1));
	}
	return '';
} # basenumber()

sub checkdigit {
	my ($self,$number) = @_;
	if ($number =~ /^(\d{7,8})(\d\d)$/i) {
		return $2 if (uc($2) eq $self->_compute_checkdigit($1));
	}
	return '';
} # checkdigit()

sub _compute_checkdigit {
	my $self   = shift;
	my $number = shift;

	if ($number =~ /^\d{7,8}$/i) {
		return sprintf("%2.2d",97 - ($number % 97));
	}
	return -1;
} # _compute_checkdigit()

# Preloaded methods go here.

1;
__END__

=head1 NAME

CheckDigits::M97_001 - compute check digits for VAT Registration Number (BE)

=head1 SYNOPSIS

  use Algorithm::CheckDigits;

  $ustid = CheckDigits('ustid_be');

  if ($ustid->is_valid('136695962')) {
	# do something
  }

  $cn = $ustid->complete('1366959');
  # $cn = '136695962'

  $cd = $ustid->checkdigit('136695962');
  # $cd = '62'

  $bn = $ustid->basenumber('136695962');
  # $bn = '1366959'

=head1 DESCRIPTION

=head2 ALGORITHM

=over 4

=item 1

The whole number (without checksum) is taken modulo 97.

=item 2

The checksum is difference of the remainder from step 1 to 97.

=back

=head2 METHODS

=over 4

=item is_valid($number)

Returns true only if C<$number> consists solely of numbers and the last digit
is a valid check digit according to the algorithm given above.

Returns false otherwise,

=item complete($number)

The check digit for C<$number> is computed and concatenated to the end
of C<$number>.

Returns the complete number with check digit or '' if C<$number>
does not consist solely of digits and spaces.

=item basenumber($number)

Returns the basenumber of C<$number> if C<$number> has a valid check
digit.

Return '' otherwise.

=item checkdigit($number)

Returns the checkdigits of C<$number> if C<$number> has a valid check
digit.

Return '' otherwise.

=back

=head2 EXPORT

None by default.

=head1 AUTHOR

Mathias Weidner, C<< <mamawe@cpan.org> >>

=head1 SEE ALSO

L<perl>,
L<CheckDigits>,
F<www.pruefziffernberechnung.de>.

=cut
