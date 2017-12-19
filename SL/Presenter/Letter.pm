package SL::Presenter::Letter;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(letter);

use Carp;

sub letter {
  my ($letter, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=Letter/edit&amp;letter.id=' . escape($letter->id) . '">',
    escape($letter->letternumber),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Letter - Presenter module for letter objects

=head1 SYNOPSIS

  my $letter = SL::DB::Manager::Letter->get_first(where => [ … ]);
  my $html   = SL::Presenter::Letter::letter($letter, display => 'inline');

=head1 FUNCTIONS

=over 4

=item C<letter $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the letter object C<$object>
.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the invoice number linked
to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the invoice number will be linked to the
"edit invoice" dialog from the general ledger menu.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
