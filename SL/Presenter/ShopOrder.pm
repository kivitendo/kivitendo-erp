package SL::Presenter::ShopOrder;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(shop_order);

use Carp;

sub shop_order {
  my ($shop_order, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($shop_order->shop_ordernumber);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=ShopOrder/show'
               . '&id='. escape($shop_order->id);
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}
1;
