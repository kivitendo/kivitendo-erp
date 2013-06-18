package SL::Iconv;

use Encode;
use English qw(-no_match_vars);
use Text::Iconv;

use SL::Common;

my %converters;

use strict;

sub new {
  my $class = shift;
  my $self  = bless { }, $class;

  $self->_init(@_);

  return $self;
}

sub _get_converter {
  my ($from_charset, $to_charset) = @_;

  my $index             = join $SUBSCRIPT_SEPARATOR, $from_charset, $to_charset;
  $converters{$index} ||= Text::Iconv->new($from_charset, $to_charset) || die;

  return $converters{$index};
}

sub convert {
  return _convert(@_) if ref $_[0];

  my ($from_charset, $to_charset, $text) = @_;

  $from_charset ||= 'UTF-8';
  $to_charset   ||= 'UTF-8';

  my $converter = _get_converter($from_charset, $to_charset);
  $text         = $converter->convert($text);
  $text         = decode("utf-8-strict", $text) if ($to_charset =~ m/^utf-?8$/i) && !Encode::is_utf8($text);

  return $text;
}

sub _convert {
  my $self = shift;
  my $text = shift;

  $text    = convert($self->{from}, $self->{to}, $text) if !$self->{to_is_utf8} || !Encode::is_utf8($text);
  $text    = decode("utf-8-strict", $text)              if  $self->{to_is_utf8} && !Encode::is_utf8($text);

  return $text;
}

sub _init {
  my $self = shift;
  $self->{from}       = shift;
  $self->{to}         = shift;
  $self->{to}         = 'UTF-8' if lc $self->{to} eq 'unicode';
  $self->{to_is_utf8} = $self->{to} =~ m/^utf-?8$/i;

  return $self;
}

sub is_utf8 {
  return shift->{to_is_utf8};
}

1;

__END__

=head1 NAME

SL::Iconv -- Thin layer on top of Text::Iconv including decode_utf8 usage

=head1 SYNOPSIS

Usage:

  use SL::Iconv;

  # Conversion without creating objects:
  my $text_utf8 = SL::Iconv::convert("ISO-8859-15", "UTF-8", $text_iso);

  # Conversion with an object:
  my $converter = SL::Iconv->new("ISO-8859-15", "UTF-8");
  my $text_utf8 = $converter->convert($text_iso);

=head1 DESCRIPTION

A thin layer on top of L<Text::Iconv>. Special handling is implemented
if the target charset is UTF-8: The resulting string has its UTF8 flag
set via a call to C<Encode::decode("utf-8-strict", ...)>.

=head1 CLASS FUNCTIONS

=over 4

=item C<new $from_charset, $to_charset>

Create a new object for conversion from C<$from_charset> to
C<$to_charset>.

=item C<convert $from_charset, $to_charset, $text>

Converts the string C<$text> from charset C<$from_charset> to charset
C<$to_charset>. See the instance method C<convert> for further
discussion.

The object used for this conversion is cached. Therefore multiple
calls to C<convert> do not result in multiple initializations of the
iconv library.

=back

=head1 INSTANCE FUNCTIONS

=over 4

=item C<convert $text>

Converts the string C<$text> from one charset to another (see C<new>).

Special handling is implemented if the target charset is UTF-8: The
resulting string has its UTF8 flag set via a call to
C<Encode::decode("utf-8-strict", ...)>. It is also safe to call
C<convert> multiple times for the same string in such cases as the
conversion is only done if the UTF8 flag hasn't been set yet.

=item C<is_utf8>

Returns true if the handle converts into UTF8.

=back

=head1 MODULE AUTHORS

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

L<http://linet-services.de>
