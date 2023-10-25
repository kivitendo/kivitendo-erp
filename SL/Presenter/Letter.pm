package SL::Presenter::Letter;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(show letter);

use Carp;

sub show {goto &letter};

sub letter {
  my ($letter, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($letter->letternumber);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=Letter/edit'
               . '&letter.id=' . escape($letter->id);
    $text = link_tag($href, $text, %params);
  }

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
  # or
  my $html   = $letter->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object>

Alias for C<letter $object %params>.

=item C<letter $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the letter object C<$object>
.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

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
