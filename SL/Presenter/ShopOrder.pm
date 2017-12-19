package SL::Presenter::ShopOrder;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);

use Exporter qw(import);
our @EXPORT_OK = qw(shop_order);

use Carp;

sub shop_order {
  my ($shop_order, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=ShopOrder/show&amp;id='. escape($shop_order->id) .'">',
    escape($shop_order->shop_ordernumber),
    $params{no_link} ? '' : '</a>',
  );

  is_escaped($text);
}
1;
