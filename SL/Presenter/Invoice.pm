package SL::Presenter::Invoice;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(invoice sales_invoice ar_transaction purchase_invoice ap_transaction);

use Carp;

sub invoice {
  my ($invoice, %params) = @_;

  if ( $invoice->is_sales ) {
    if ( $invoice->invoice ) {
      return _is_ir_record($invoice, 'is', %params);
    } else {
      return _is_ir_record($invoice, 'ar', %params);
    }
  } else {
    if ( $invoice->invoice ) {
      return _is_ir_record($invoice, 'ir', %params);
    } else {
      return _is_ir_record($invoice, 'ap', %params);
    }
  };
};

sub sales_invoice {
  my ($invoice, %params) = @_;

  _is_ir_record($invoice, 'is', %params);
}

sub ar_transaction {
  my ($invoice, %params) = @_;

  _is_ir_record($invoice, 'ar', %params);
}

sub purchase_invoice {
  my ($invoice, %params) = @_;

  _is_ir_record($invoice, 'ir', %params);
}

sub ap_transaction {
  my ($invoice, %params) = @_;

  _is_ir_record($invoice, 'ap', %params);
}

sub _is_ir_record {
  my ($invoice, $controller, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="' . $controller . '.pl?action=edit&amp;type=invoice&amp;id=' . escape($invoice->id) . '">',
    escape($invoice->invnumber),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
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
  my $html   = SL::Presenter::Invoice::sales_invoice($object, display => 'inline');

  # AR transactions:
  my $object = SL::DB::Manager::Invoice->get_first(where => [ or => [ invoice => undef, invoice => 0 ]]);
  my $html   = SL::Presenter::Invoice::ar_transaction($object, display => 'inline');

  # Purchase invoices:
  my $object = SL::DB::Manager::PurchaseInvoice->get_first(where => [ invoice => 1 ]);
  my $html   = SL::Presenter::Invoice::purchase_invoice($object, display => 'inline');

  # AP transactions:
  my $object = SL::DB::Manager::PurchaseInvoice->get_first(where => [ or => [ invoice => undef, invoice => 0 ]]);
  my $html   = SL::Presenter::Invoice::ar_transaction($object, display => 'inline');

  # use with any of the above ar/ap/is/ir types:
  my $html   = SL::Presenter::Invoice::invoice($object, display => 'inline');

=head1 FUNCTIONS

=over 4

=item C<invoice $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of an ar/ap/is/ir object C<$object> . Determines
which type (sales or purchase, invoice or not) the object is.

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
