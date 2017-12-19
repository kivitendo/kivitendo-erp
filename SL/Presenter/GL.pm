package SL::Presenter::GL;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(gl_transaction);

use Carp;

sub gl_transaction {
  my ($gl_transaction, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="gl.pl?action=edit&amp;id=' . escape($gl_transaction->id) . '">',
    escape($gl_transaction->reference),
    $params{no_link} ? '' : '</a>',
  );

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

=head1 FUNCTIONS

=over 4

=item C<gl_transaction $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of a gl object C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the trans_id number linked
to the corresponding 'edit' action.

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
