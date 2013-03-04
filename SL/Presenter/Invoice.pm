package SL::Presenter::Invoice;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(sales_invoice ar_transaction purchase_invoice ap_transaction);

use Carp;

sub sales_invoice {
  my ($self, $invoice, %params) = @_;

  return _is_ir_record($self, $invoice, 'is', %params);
}

sub ar_transaction {
  my ($self, $invoice, %params) = @_;

  return _is_ir_record($self, $invoice, 'ar', %params);
}

sub purchase_invoice {
  my ($self, $invoice, %params) = @_;

  return _is_ir_record($self, $invoice, 'ir', %params);
}

sub ap_transaction {
  my ($self, $invoice, %params) = @_;

  return _is_ir_record($self, $invoice, 'ap', %params);
}

sub _is_ir_record {
  my ($self, $invoice, $controller, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="' . $controller . '.pl?action=edit&amp;type=invoice&amp;id=' . $self->escape($invoice->id) . '">',
    $self->escape($invoice->invnumber),
    $params{no_link} ? '' : '</a>',
  );
  return $self->escaped_text($text);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Invoice - Presenter module for sales invoice, AR
transaction, purchase invoice and AP transaction Rose::DB objects

=head1 SYNOPSIS

  # Sales invoices:
  my $object = SL::DB::Manager::Invoice->get_first(where => [ invoice => 1 ]);
  my $html   = SL::Presenter->get->sales_invoice($object, display => 'inline');

  # AR transactions:
  my $object = SL::DB::Manager::Invoice->get_first(where => [ or => [ invoice => undef, invoice => 0 ]]);
  my $html   = SL::Presenter->get->ar_transaction($object, display => 'inline');

  # Purchase invoices:
  my $object = SL::DB::Manager::PurchaseInvoice->get_first(where => [ invoice => 1 ]);
  my $html   = SL::Presenter->get->purchase_invoice($object, display => 'inline');

  # AP transactions:
  my $object = SL::DB::Manager::PurchaseInvoice->get_first(where => [ or => [ invoice => undef, invoice => 0 ]]);
  my $html   = SL::Presenter->get->ar_transaction($object, display => 'inline');

=head1 FUNCTIONS

=over 4

=item C<sales_invoice $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sales invoice object C<$object>
.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the invoice number linked
to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the invoice number will be linked to the
"edit invoice" dialog from the sales menu.

=back

=item C<ar_transaction $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the AR transaction object C<$object>
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

=item C<purchase_invoice $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the purchase invoice object
C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the invoice number name
linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the invoice number will be linked to
the "edit invoice" dialog from the purchase menu.

=back

=item C<ap_transaction $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the AP transaction object C<$object>
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
