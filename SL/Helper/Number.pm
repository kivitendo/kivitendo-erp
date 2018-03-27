package SL::Helper::Number;

use strict;
use Exporter qw(import);
use List::Util qw(max min);
use Config;

our @EXPORT_OK = qw(
  _total       _round_total
  _number      _round_number
  _parse_number
);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub _number {
  my ($myconfig, $amount, $places, $dash) = @_;
  $amount ||= 0;
  $dash   ||= '';
  my $neg = $amount < 0;
  my $force_places = defined $places && $places >= 0;

  $amount = _round_number($amount, abs $places) if $force_places;
  $neg    = 0 if $amount == 0; # don't show negative zero
  $amount = sprintf "%.*f", ($force_places ? $places : 10), abs $amount; # 6 is default for %fa

  # before the sprintf amount was a number, afterwards it's a string. because of the dynamic nature of perl
  # this is easy to confuse, so keep in mind: before this comment no s///, m//, concat or other strong ops on
  # $amount. after this comment no +,-,*,/,abs. it will only introduce subtle bugs.

  $amount =~ s/0*$// unless defined $places && $places == 0;             # cull trailing 0s

  my @d = map { s/\d//g; reverse split // } my $tmp = $myconfig->{numberformat}; # get delim chars
  my @p = split(/\./, $amount);                                          # split amount at decimal point

  $p[0] =~ s/\B(?=(...)*$)/$d[1]/g if $d[1];                             # add 1,000 delimiters
  $amount = $p[0];
  if ($places || $p[1]) {
    $amount .= $d[0]
            .  ( $p[1] || '' )
            .  (0 x max(abs($places || 0) - length ($p[1]||''), 0));     # pad the fraction
  }

  $amount = do {
    ($dash =~ /-/)    ? ($neg ? "($amount)"                            : "$amount" )                              :
    ($dash =~ /DRCR/) ? ($neg ? "$amount " . $main::locale->text('DR') : "$amount " . $main::locale->text('CR') ) :
                        ($neg ? "-$amount"                             : "$amount" )                              ;
  };

  $amount;
}

sub _round_number {
  my ($amount, $places, $adjust) = @_;

  return 0 if !defined $amount;

  $places //= 0;

  if ($adjust) {
    my $precision = $::instance_conf->get_precision || 0.01;
    return _round_number( _round_number($amount / $precision, 0) * $precision, $places);
  }

  # We use Perl's knowledge of string representation for
  # rounding. First, convert the floating point number to a string
  # with a high number of places. Then split the string on the decimal
  # sign and use integer calculation for rounding the decimal places
  # part. If an overflow occurs then apply that overflow to the part
  # before the decimal sign as well using integer arithmetic again.

  my $int_amount = int(abs $amount);
  my $str_places = max(min(10, 16 - length("$int_amount") - $places), $places);
  my $amount_str = sprintf '%.*f', $places + $str_places, abs($amount);

  return $amount unless $amount_str =~ m{^(\d+)\.(\d+)$};

  my ($pre, $post)      = ($1, $2);
  my $decimals          = '1' . substr($post, 0, $places);

  my $propagation_limit = $Config{i32size} == 4 ? 7 : 18;
  my $add_for_rounding  = substr($post, $places, 1) >= 5 ? 1 : 0;

  if ($places > $propagation_limit) {
    $decimals = Math::BigInt->new($decimals)->badd($add_for_rounding);
    $pre      = Math::BigInt->new($decimals)->badd(1) if substr($decimals, 0, 1) eq '2';

  } else {
    $decimals += $add_for_rounding;
    $pre      += 1 if substr($decimals, 0, 1) eq '2';
  }

  $amount  = ("${pre}." . substr($decimals, 1)) * ($amount <=> 0);

  return $amount;
}

sub _parse_number {
  my ($myconfig, $amount) = @_;

  return 0 if !defined $amount || $amount eq '';

  if (   ($myconfig->{numberformat} eq '1.000,00')
      || ($myconfig->{numberformat} eq '1000,00')) {
    $amount =~ s/\.//g;
    $amount =~ s/,/\./g;
  }

  if ($myconfig->{numberformat} eq "1'000.00") {
    $amount =~ s/\'//g;
  }

  $amount =~ s/,//g;

  # Make sure no code wich is not a math expression ends up in eval().
  return 0 unless $amount =~ /^ [\s \d \( \) \- \+ \* \/ \. ]* $/x;

  # Prevent numbers from being parsed as octals;
  $amount =~ s{ (?<! [\d.] ) 0+ (?= [1-9] ) }{}gx;

  return scalar(eval($amount)) * 1 ;
}

sub _total    { _number(\%::myconfig, $_[0], 2)  }

sub _round_total    { _round_number($_[0], 2) }

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::Number - number formating functions formerly sitting in SL::Form

=head1 SYNOPSIS

  use SL::Helper::Number qw(all);

  my $str       = _number(\%::myconfig, $val, 2);
  my $total     = _total($val);     # rounded to 2

  my $val       = _parse_number(\%::myconfig, $str);

  my $str       = _round_number(\%::myconfig, $val, 2);
  my $total     = _round_total($val);     # rounded to 2

=head1 DESCRIPTION

This package contains all the number parsing/formating functions that were previously in SL::Form.

Instead of invoking them as methods on C<$::form> these are pure functions.

=head1 FUNCTIONS

=over 4

=item * C<_number MYCONFIG VALUE PLACES DASH>

The old C<SL::Form::format_amount>. C<MYCONFIG> is expected to be a hashref
with a C<numberformat> entry. Usually C<\%::myconfig> will be passed.

The value is expected to be a numeric value, but undef and empty string will be
vivified to 0 for convinience. Bigints are supported.

For the semantics of places, see L</PLACES>.

The dash parameter allows to change the formatting of positive and negative
numbers to alternative ones. If C<-> is given for dash, negative numbers will
instead be formatted with prentheses. If C<DRCR> is given, the numbers will be
formatted absolute, but suffixed with the localized versions of C<DR> and
C<CR>.

=item * _total

A curried version used for formatting ledger entries. C<myconfig> is set from the
current user, C<places> is set to 2. C<dash> is left empty.

=item * _parse_number MYCONFIG VALUE

Parses expressions into numbers. C<MYCONFIG> is expected to be a hashref
with a C<numberformat> entry.

Also implements basic arithmetic interprtation, so that C<2 * 1400> is
interpreted as 2800.

=item * _round_number VALUE PLACES

Rounds a number. Due to the way Perl handles floating point we take a lot of
precautions that rounding ends up being close to where we want. Usually the
internal floats have more than enough precision to not have any floating point
issues, but the cumulative error can interfere with proper formatting later.

For places, see L</PLACES>

=item * _round_total

A curried version used for rounding ledger entries. C<places> is set to 2.

=back

=head1 PLACES

Places can be:

=over 4

=item * not present

In that case a representation is chosen that looks sufficiently human. For
example C<1/10> equals C<.1000000000000000555> but will be displayed as the
localzed version of 0.1.

=item * 0

The number will be rounded to the nearest integer (towards 0).

=item * a positive integer

The number will be rounded to this many places. Formatting functions will then
make sure to pad the output to this many places.

=item * a negative inteher

The number will not be rounded, but padded to at least this many places.

=back

=head1 ERROR REPORTING

All of these do not thow exceptions and will simply return undef should
something unforeseen happen.

=head1 BUGS AND CAVEATS

Beware that the old C<amount> is now called plain C<number>. C<amount> is
deliberately unused in the new version for that reason.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
