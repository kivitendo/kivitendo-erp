package SL::HTML::Util;

use strict;
use warnings;

use HTML::Parser;

my %stripper;
my %entities = (
  'lt'   => '<',
  'gt'   => '>',
  'amp'  => '&',
  'nbsp' => ' ',   # should be => "\x{00A0}", but this can lead to problems with
                   # a non-visible character in csv-exports for example
);

sub strip {
  my ($class_or_value) = @_;

  my $value = !ref($class_or_value) && (($class_or_value // '') eq 'SL::HTML::Util') ? $_[1] : $class_or_value;

  return '' unless defined $value;

  # Remove HTML comments.
  $value =~ s{ <!-- .*? --> }{}gx;

  if (!%stripper) {
    %stripper = ( parser => HTML::Parser->new );

    $stripper{parser}->handler(text => sub { $stripper{text} .= ' ' . $_[1]; });
  }

  $stripper{text} = '';
  $stripper{parser}->parse($value);
  $stripper{parser}->eof;

  $stripper{text} =~ s{\&([^;]+);}{ $entities{$1} || "\&$1;" }eg;
  $stripper{text} =~ s{^ +| +$}{}g;
  $stripper{text} =~ s{ {2,}}{ }g;

  return delete $stripper{text};
}

sub plain_text_to_html {
  my ($class_or_text) = @_;

  my $text = !ref($class_or_text) && (($class_or_text // '') eq 'SL::HTML::Util') ? $_[1] : $class_or_text;

  return $text if $text =~ m{^<p>.*</p>$};

  $text =~ s{\r+}{}g;
  $text =~ s{^[[:space:]]+|[[:space:]]+$}{}g;

  return '' if $text eq '';

  my @paragraphs;

  foreach my $paragraph (split m{\n{2,}}, $text) {
    no warnings 'once';
    $paragraph =  $::locale->quote_special_chars('HTML', $paragraph);
    $paragraph =~ s{\n}{<br>}g;

    push @paragraphs, $paragraph;
  }

  return '<p>' . join('</p><p>', @paragraphs) . '</p>';
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::HTML::Util - Utility functions dealing with HTML

=head1 SYNOPSIS

  my $plain_text = SL::HTML::Util->strip('<h1>Hello World</h1>');

=head1 FUNCTIONS

=over 4

=item C<strip $html_content>

Removes all HTML elements and tags from C<$html_content> and returns
the remaining plain text.

=item C<plain_text_to_html $text>

Converts a plain text to HTML: paragraphs will be recognized by empty
lines; remaining newlines will be converted into forced line breaks;
the rest will be HTML escaped.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
