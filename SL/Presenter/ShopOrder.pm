package SL::Presenter::ShopOrder;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(shop_order);

use Carp;

sub shop_order {
  my ($self, $shop_order, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=ShopOrder/show&amp;id='.$self->escape($shop_order->id).'">',
    $self->escape($shop_order->shop_ordernumber),
    $params{no_link} ? '' : '</a>',
  );
  return $self->escaped_text($text);
}
1;
