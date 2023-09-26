package SL::Presenter::Order;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(sales_quotation sales_order request_quotation purchase_order);

use Carp;

sub sales_quotation {
  my ($order, %params) = @_;

  return _oe_record($order, 'sales_quotation', %params);
}

sub sales_order_intake {
  my ($order, %params) = @_;

  return _oe_record($order, 'sales_order_intake', %params);
}

sub sales_order {
  my ($order, %params) = @_;

  return _oe_record($order, 'sales_order', %params);
}

sub request_quotation {
  my ($order, %params) = @_;

  return _oe_record($order, 'request_quotation', %params);
}

sub purchase_quotation_intake {
  my ($order, %params) = @_;

  return _oe_record($order, 'purchase_quotation_intake', %params);
}

sub purchase_order {
  my ($order, %params) = @_;

  return _oe_record($order, 'purchase_order', %params);
}

sub _oe_record {
  my ($order, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($order->record_number);
  if (! delete $params{no_link}) {
    my $action  = $::instance_conf->get_feature_experimental_order
                ? 'controller.pl?action=Order/edit'
                : 'oe.pl?action=edit';
    my $href = $action
               . '&type=' . $type
               . '&id=' . escape($order->id);
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

1;


__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Order - Presenter module for Rose::DB objects for sales
quotations, sales order_intakes, sales orders,
requests for quotations, purchase_quotation_intakes and purchase orders

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

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the order number will be linked to the
"edit quotation" dialog from the sales menu.

=back

=item C<sales_order $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sales order object C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the  order number will be linked
to the "edit order" dialog from the sales menu.

=back

=item C<request_quotation $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the request for quotation object
C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the order number will be linked to the
"edit request for quotation" dialog from the purchase menu.

=back

=item C<purchase_order $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the purchase order object
C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

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
