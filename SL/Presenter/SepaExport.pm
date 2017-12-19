package SL::Presenter::SepaExport;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(sepa_export);

use Carp;

sub sepa_export {
  my ($sepa_export, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="sepa.pl?action=bank_transfer_edit&amp;vc=' . escape($sepa_export->vc) . '&amp;id=' . escape($sepa_export->id) . '">',
    escape($sepa_export->id),
    $params{no_link} ? '' : '</a>',
  );
  is_escaped($text);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::SepaExport - Presenter module for Rose::DB objects
for SEPA transfers and collections

=head1 SYNOPSIS

  # Collections from an invoice:
  my $invoice = SL::DB::Invoice->new(id => 123)->load;
  my $object  = $invoice->sepa_export_items->[0]->sepa_export;
  my $html    = SL::Presenter->get->sepa_export($object, display => 'inline');

  # Transfers from a purchase invoice:
  my $invoice = SL::DB::PurchaseInvoice->new(id => 123)->load;
  my $object  = $invoice->sepa_export_items->[0]->sepa_export;
  my $html    = SL::Presenter->get->sepa_export($object, display => 'inline');

=head1 FUNCTIONS

=over 4

=item C<sepa_export $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the SEPA collection/transfer object
C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the objects's delivery
order number linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the delivery order number will be linked
to the "edit SEPA transfer" dialog from the 'cash' menu.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
