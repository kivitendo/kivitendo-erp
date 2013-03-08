package SL::Presenter::Text;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(simple_format truncate);

use Carp;

sub truncate {
  my ($self, $text, %params) = @_;

  $params{at}             ||= 50;
  $params{at}               =  3 if 3 > $params{at};
  $params{at}              -= 3;

  return $text if length($text) < $params{at};
  return substr($text, 0, $params{at}) . '...';
}

sub simple_format {
  my ($self, $text, %params) = @_;

  $text =  $::locale->quote_special_chars('HTML', $text || '');

  $text =~ s{\r\n?}{\n}g;                    # \r\n and \r -> \n
  $text =~ s{\n\n+}{</p>\n\n<p>}g;           # 2+ newline  -> paragraph
  $text =~ s{([^\n]\n)(?=[^\n])}{$1<br />}g; # 1 newline   -> br

  return '<p>' . $text;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Text - Presenter module for assorted text helpers

=head1 SYNOPSIS

  my $long_text = "This is very, very long. Need shorter, surely.";
  my $truncated = $::request->presenter->truncate($long_text, at => 10);
  # Result: "This is..."

=head1 FUNCTIONS

=over 4

=item C<truncate $text, [%params]>

Returns the C<$text> truncated after a certain number of
characters.

The number of characters to truncate at is determined by the parameter
C<at> which defaults to 50. If the text is longer than C<$params{at}>
then it will be truncated and postfixed with '...'. Otherwise it will
be returned unmodified.

=item C<simple_format $text>

Applies simple formatting rules to C<$text>: The text is put into
paragraph HTML tags. Two consecutive newlines are interpreted as a
paragraph change: they close the current paragraph tag and start a new
one. Single newlines are converted to line breaks. Carriage returns
are removed.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
