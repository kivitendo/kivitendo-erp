use strict;
use Test::More;

use lib 't';
use Support::TestSetup;
use Carp;
use Test::Exception;
use SL::Dev::ALL;
use SL::Dev::Part qw(new_part);
use SL::Dev::Shop qw(new_shop new_shop_part);
use SL::Dev::CustomerVendor qw(new_customer);
use SL::DB::Shop;
use SL::DB::ShopOrder;
use SL::DB::ShopOrderItem;
use SL::Controller::ShopOrder;
use SL::Shop;
use Data::Dumper;
use SL::JSON;
use SL::ShopConnector::Shopware;
my ($shop, $shopware, $shop_order, $shop_part, $part, $customer, $employee, $json_import);

sub reset_state {
  my %params = @_;

  clear_up();

  $shop = new_shop( connector         => 'shopware',
                    last_order_number => 20000,
                    pricetype         => 'brutto',
                    price_source      => 'master_data',
                    taxzone_id        => 1,
                  );
  $shopware = SL::Shop->new( config => $shop );
  $part = new_part( partnumber   => 'SW10002',
                    description  => 'TITANIUM CARBON GS 12m cm',
                  );
  $shop_part = new_shop_part(part => $part, shop => $shop);

  $employee = SL::DB::Manager::Employee->current || croak "No employee";

  $customer = new_customer( name    => 'Evil Inc',
                            street  => 'Evil Street',
                            zipcode => '66666',
                            email   => 'evil@evilinc.com'
                          )->save;
}

sub get_json {
  local $/;
  my $file = "t/shop/json_ok.json";
  my $json_text = do {
    open(my $json_fh, "<:encoding(UTF-8)", $file)
         or die("Can't open \"$file\": $!\n");
    local $/;
    <$json_fh>
  };

  return $json_text;
}

sub test_import {

  my $json_import = get_json();
  note('testing shoporder mapping json good');
  my $import = SL::JSON::decode_json($json_import);
  $shop_order = $shopware->connector->import_data_to_shop_order($import);
  is($shop_order->shop_id , $shop->id  , "shop_id ok");
}

Support::TestSetup::login();

reset_state();

test_import();

done_testing;

clear_up();

1;

sub clear_up {
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(OrderItem Order);
  "SL::DB::Manager::${_}"->delete_all(all => 1) for qw(ShopPart Part ShopOrderItem ShopOrder Shop Customer);
}
