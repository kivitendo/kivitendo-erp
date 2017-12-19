package SL::Presenter::Order;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(sales_quotation sales_order request_quotation purchase_order);

use Carp;

sub sales_quotation {
  my ($order, %params) = @_;

  return _oe_record($order, 'sales_quotation', %params);
}

sub sales_order {
  my ($order, %params) = @_;

  return _oe_record($order, 'sales_order', %params);
}

sub request_quotation {
  my ($order, %params) = @_;

  return _oe_record($order, 'request_quotation', %params);
}

sub purchase_order {
  my ($order, %params) = @_;

  return _oe_record($order, 'purchase_order', %params);
}

sub _oe_record {
  my ($order, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $number_method = $order->quotation ? 'quonumber' : 'ordnumber';

  my $text = join '', (
    $params{no_link} ? '' : '<a href="oe.pl?action=edit&amp;type=' . $type . '&amp;id=' . escape($order->id) . '">',
    escape($order->$number_method),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Order - Presenter module for Rose::DB objects for sales
quotations, sales orders, requests for quotations and purchase orders

=head1 SYNOPSIS

  # Sales quotations:
  my $object = SL::DB::Manager::Order->get_first(where => [ SL::DB::Manager::Order->type_filter('sales_quotation') ]);
  my $html   = SL::Presenter::Order::sales_quotation($object, display => 'inline');

  # Sales orders:
  my $object = SL::DB::Manager::Order->get_first(where => [ SL::DB::Manager::Order->type_filter('sales_order') ]);
  my $html   = SL::Presenter::Order::sales_order($object, display => 'inline');

  # Requests for quotations:
  my $object = SL::DB::Manager::Order->get_first(where => [ SL::DB::Manager::Order->type_filter('request_quotation') ]);
  my $html   = SL::Presenter::Order::request_quotation($object, display => 'inline');

  # Purchase orders:
  my $object = SL::DB::Manager::Order->get_first(where => [ SL::DB::Manager::Order->type_filter('purchase_order') ]);
  my $html   = SL::Presenter::Order::purchase_order($object, display => 'inline');

=head1 FUNCTIONS

=over 4

=item C<sales_quotation $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sales quotation object
C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the objects's
quotation number linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the order number will be linked to the
"edit quotation" dialog from the sales menu.

=back

=item C<sales_order $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sales order object C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the objects's
order number linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the  order number will be linked
to the "edit order" dialog from the sales menu.

=back

=item C<request_quotation $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the request for quotation object
C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the objects's
quotation number linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the order number will be linked to the
"edit request for quotation" dialog from the purchase menu.

=back

=item C<purchase_order $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the purchase order object
C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the objects's
order number linked to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the  order number will be linked
to the "edit order" dialog from the purchase menu.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
