package SL::Iconv;

use Text::Iconv;

use SL::Common;

use vars qw(%converters);

sub get_converter {
  my ($from_charset, $to_charset) = @_;

  my $index = "${from_charset}::${to_charset}";
  if (!$converters{$index}) {
    $converters{$index} = Text::Iconv->new($from_charset, $to_charset) || die;
  }

  return $converters{$index};
}

sub convert {
  my ($from_charset, $to_charset, $text) = @_;

  $from_charset ||= Common::DEFAULT_CHARSET;
  $to_charset   ||= Common::DEFAULT_CHARSET;

  my $converter = get_converter($from_charset, $to_charset);
  return $converter->convert($text);
}

1;

