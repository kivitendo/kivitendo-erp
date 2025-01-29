package SL::Presenter::Order;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(show order sales_quotation sales_order_intake sales_order request_quotation purchase_quotation_intake purchase_order purchase_order_confirmation);

use Carp;

sub show {goto &order}

sub sales_quotation {goto &order}

sub sales_order_intake {goto &order}

sub sales_order {goto &order}

sub request_quotation {goto &order}

sub purchase_quotation_intake {goto &order}

sub purchase_order {goto &order}

sub purchase_order_confirmation {goto &order}

sub order {
  my ($order, %params) = @_;
  my $type = $order->record_type;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($order->record_number);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=Order/edit'
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
requests for quotations, purchase_quotation_intakes,
purchase orders and purchase order confirmations

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

  # or for all types:
  my $html   = SL::Presenter::Order::order($object);
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object %params>

Alias for C<order $object %params>.

=item C<sales_quotation $object %params>

Alias for C<order $object %params>.

=item C<sales_order_intake $object %params>

Alias for C<order $object %params>.

=item C<sales_order $object %params>

Alias for C<order $object %params>.

=item C<request_quotation $object %params>

Alias for C<order $object %params>.

=item C<purchase_quotation_intake $object %params>

Alias for C<order $object %params>.

=item C<purchase_order $object %params>

Alias for C<order $object %params>.

=item C<order $object %params>

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
to the "edit order" dialog.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
