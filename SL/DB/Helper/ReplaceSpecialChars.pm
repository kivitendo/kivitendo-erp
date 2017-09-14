package SL::DB::Helper::ReplaceSpecialChars;

use strict;
use utf8;

use parent qw(Exporter);
our @EXPORT = qw(replace_special_chars);

use Carp;
use Text::Unidecode qw(unidecode);




sub replace_special_chars {
  my $text = shift;

  return unless $text;

  my %special_chars = (
    'ä' => 'ae',
    'ö' => 'oe',
    'ü' => 'ue',
    'Ä' => 'Ae',
    'Ö' => 'Oe',
    'Ü' => 'Ue',
    'ß' => 'ss',
    '&' => '+',
    '`' => '\'',
    );

  map { $text =~ s/$_/$special_chars{$_}/g; } keys %special_chars;

  # for all other non ascii chars 'OLÉ S.L.' and 'Årdberg AB'!
  $text = unidecode($text);

  return $text;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::ReplaceSpecialChars - Helper functions for replacing non-ascii characaters

=head1 SYNOPSIS

  use SL::DB::Helper::ReplaceSpecialChars qw(replace_special_chars);
  my $ansi_string = replace_special_chars("Überhaupt, with Olé \x{5317}\x{4EB0}"); # hint perldoc may already convert
  print $ansi_string;
  # Ueberhaupt, with Ole Bei Jing

=head1 FUNCTIONS

=over 4

=item C<replace_special_chars $text>

Given a text string this method replaces the most common german umlaute,
transforms '&' to '+' and escapes a single quote (').
If there are still some non-ascii chars, we use unidecode to guess
a sensible ascii presentation, C<perldoc Text::Unidecode>

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

M.Bunkus
J.Büren (Unidecode added)

=cut


