package SL::Presenter::Text;

use strict;

use SL::Presenter::EscapedText qw(escape);

use Exporter qw(import);
our @EXPORT_OK = qw(format_man_days simple_format truncate);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use Carp;

sub truncate {
  my ($text, %params) = @_;

  escape(Common::truncate($text, %params));
}

sub simple_format {
  my ($text, %params) = @_;

  $text =  $::locale->quote_special_chars('HTML', $text || '');

  $text =~ s{\r\n?}{\n}g;                    # \r\n and \r -> \n
  $text =~ s{\n\n+}{</p>\n\n<p>}g;           # 2+ newline  -> paragraph
  $text =~ s{([^\n]\n)(?=[^\n])}{$1<br />}g; # 1 newline   -> br

  return '<p>' . $text;
}

sub format_man_days {
  my ($value, %params) = @_;

  return '---' if $params{skip_zero} && !$value;

  return escape($::locale->text('#1 h', $::form->format_amount(\%::myconfig, $value, 2))) if 8.0 > $value;

  $value     /= 8.0;
  my $output  = $::locale->text('#1 MD', int($value));
  my $rest    = ($value - int($value)) * 8.0;
  $output    .= ' ' . $::locale->text('#1 h', $::form->format_amount(\%::myconfig, $rest)) if $rest > 0.0;

  escape($output);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Text - Presenter module for assorted text helpers

=head1 SYNOPSIS

  use  SL::Presenter::Text qw(truncate);

  my $long_text = "This is very, very long. Need shorter, surely.";
  my $truncated = truncate($long_text, at => 10);
  # Result: "This is..."

=head1 FUNCTIONS

=over 4

=item C<format_man_days $value, [%params]>

C<$value> is interpreted to mean a number of hours (for C<$value> < 8)
/ man days (if >= 8). Returns a translated, human-readable version of
it, e.g. C<2 PT 2 h> for the value C<18> and German.

If the parameter C<skip_zero> is trueish then C<---> is returned
instead of the normal formatting if C<$value> equals 0.

=item C<truncate $text, %params>

Returns the C<$text> truncated after a certain number of
characters. See L<Common/truncate> for the actual implementation and
supported parameters.

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
