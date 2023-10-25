package SL::Presenter::GL;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(show gl_transaction);

use Carp;

sub show {goto &gl_transaction};

sub gl_transaction {
  my ($gl_transaction, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($gl_transaction->reference);
  if (! delete $params{no_link}) {
    my $href = 'gl.pl?action=edit&id=' . escape($gl_transaction->id);
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::GL - Presenter module for GL transaction

=head1 SYNOPSIS

  my $object = SL::DB::Manager::GLTransaction->get_first();
  my $html   = SL::Presenter::GL::gl_transaction($object, display => 'inline');
  # or
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object %params>

Alias for C<gl_transaction $object %params>.

=item C<gl_transaction $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of a gl object C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the trans_id number will be linked to the
"edit gl" dialog.


=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>information@kivitendo-premium.deE<gt>

=cut
