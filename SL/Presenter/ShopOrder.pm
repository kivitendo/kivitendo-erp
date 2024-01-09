package SL::Presenter::ShopOrder;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag         qw(link_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(show shop_order);

use Carp;

sub show {goto &shop_order};

sub shop_order {
  my ($shop_order, %params) = @_;

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

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::ShopOrder - Presenter module for SL::DB::ShopOrder objects

=head1 SYNOPSIS

  my $object = SL::DB::Manager::ShopOrder->get_first();
  my $html   = SL::Presenter::ShopOrder::shop_order($object);
  # or
  my $html   = $object->presenter->show();

=head1 FUNCTIONS

=over 4

=item C<show $object>

Alias for C<shop_order $object %params>.

=item C<shop_order $object %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the shop order object
C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * no_link

If falsish (the default) then the shop order will be linked to the "show" dialog.

=back

C<%params> gets passed to L<SL::Presenter::Tag/link_tag>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
