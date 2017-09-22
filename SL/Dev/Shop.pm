package SL::Dev::Shop;

use strict;
use base qw(Exporter);
use Data::Dumper;
our @EXPORT_OK = qw(new_shop new_shop_part new_shop_order);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::Shop;

sub new_shop {
  my (%params) = @_;

  my $shop = SL::DB::Shop->new(
    description => delete $params{description} || 'testshop',
    %params
  );
  return $shop;
}

sub new_shop_part {
  my (%params) = @_;

  my $part = delete $params{part};
  my $shop = delete $params{shop};

  my $shop_part = SL::DB::ShopPart->new(
    part => $part,
    shop => $shop,
    %params
  )->save;
  return $shop_part;
}

sub new_shop_order {
  my (%params) = @_;

  my $shop_order = SL::DB::ShopOrder->new(
    shop => $params{shop},
    %params
  );
  return $shop_order;
}


1;

__END__

=head1 NAME

SL::Dev::Shop - create shop objects for testing, with minimal defaults

=head1 FUNCTIONS

=head2 C<create_shop %PARAMS>

Creates a new shop object.

  my $shop = SL::Dev::Shop::create_shop();

Add a part as a shop part to the shop:

  my $part = SL::Dev::Part::create_part();
  $shop->add_shop_parts( SL::DB::ShopPart->new(part => $part, shop_description => 'Simply the best part!' ) );
  $shop->save;


=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
