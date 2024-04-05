package SL::Presenter::DeliveryOrder;

use strict;

use SL::DB::DeliveryOrder::TypeData ();
use SL::Locale::String qw(t8);
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(
  show delivery_order delivery_order_status_line
  sales_delivery_order purchase_delivery_order
  rma_delivery_order supplier_delivery_order
);

use Carp;

sub show {goto &delivery_order};

sub sales_delivery_order {goto &delivery_order}

sub rma_delivery_order {goto &delivery_order};

sub purchase_delivery_order {goto &delivery_order};

sub supplier_delivery_order {goto &delivery_order};

sub delivery_order {
  my ($delivery_order, %params) = @_;
  my $type = $delivery_order->record_type;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($delivery_order->donumber);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=DeliveryOrder/edit'
               . '&type=' . $type
               . '&id=' . escape($delivery_order->id);
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

sub stock_status {
  my ($delivery_order) = @_;

  my $in_out = SL::DB::DeliveryOrder::TypeData::get3($delivery_order->type, "properties", "transfer");

  if ($in_out eq 'in') {
    return escape($delivery_order->delivered ? t8('transferred in') : t8('not transferred in yet'));
  }

  if ($in_out eq 'out') {
    return escape($delivery_order->delivered ? t8('transferred out') : t8('not transferred out yet'));
  }
}

sub closed_status {
  my ($delivery_order) = @_;

  return escape($delivery_order->closed ? t8('Closed') : t8('Open'))
}

sub status_line {
  my ($delivery_order) = @_;

  return "" unless $delivery_order->id;

  stock_status($delivery_order) . " ; " . closed_status($delivery_order)
}

sub delivery_order_status_line { goto &status_line };

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::DeliveryOrder - Presenter module for Rose::DB objects
for sales and purchase delivery orders

=head1 SYNOPSIS

  # Sales delivery orders:
  my $object = SL::DB::Manager::DeliveryOrder->get_first(where => [ record_type  => SALES_DELIVERY_ORDER_TYPE ]);
  my $html   = SL::Presenter::DeliveryOrder::sales_delivery_order($object, display => 'inline');

  # Purchase delivery orders:
  my $object = SL::DB::Manager::DeliveryOrder->get_first(where => [ record_type  => PURCHASE_DELIVERY_ORDER_TYPE ]);
  my $html   = SL::Presenter::DeliveryOrder::purchase_delivery_order($object, display => 'inline');

  #...

  # or for all types:
  my $html   = SL::Presenter::DeliveryOrder::delivery_order($object);
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object %params>

Alias for C<delivery_order $object %params>.

=item C<sales_delivery_order $object, %params>

Alias for C<delivery_order $object %params>.

=item C<purchase_delivery_order $object, %params>

Alias for C<delivery_order $object %params>.

=item C<rma_delivery_order $object, %params>

Alias for C<delivery_order $object %params>.

=item C<supplier_delivery_order $object, %params>

Alias for C<delivery_order $object %params>.

=item C<delivery_order $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the sales delivery order object
C<$object>.

Remaining C<%params> are passed to the function
L<SL::Presenter::Tag/link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the delivery order number will be linked
to the "edit delivery order" dialog from the sales menu.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
