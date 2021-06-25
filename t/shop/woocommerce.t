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

  $shop = new_shop( connector         => 'woocommerce',
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

sub get_data {

  my %data = (
    '_links' => {
                  'collection' => [
                                    {
                                      'href' => 'https://WOOCOMMERCESHOP/wp-json/wc/v3/orders'
                                    }
                                  ],
                  'self' => [
                              {
                                'href' => 'https://WOOCOMMERCESHOP/wp-json/wc/v3/orders/8163'
                              }
                            ]
                },
    'billing' => {
                   'address_1' => 'Hauptstrasse 52a',
                   'address_2' => '',
                   'city' => 'Halle',
                   'company' => '',
                   'country' => 'DE',
                   'email' => 'test@test.de',
                   'first_name' => 'Heike',
                   'last_name' => 'Mustermann',
                   'phone' => '12345',
                   'postcode' => '06118',
                   'state' => ''
                 },
    'cart_hash' => '4f978421d12277a81e8b6f83c02fba55',
    'cart_tax' => '0.21',
    'coupon_lines' => [],
    'created_via' => 'checkout',
    'currency' => 'EUR',
    'currency_symbol' => "\x{20ac}",
    'customer_id' => 0,
    'customer_ip_address' => '888.888.888.888',
    'customer_note' => '',
    'customer_user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:87.0) Gecko/20100101 Firefox/87.0',
    'date_completed' => '2021-04-13T10:04:12',
    'date_completed_gmt' => '2021-04-13T08:04:12',
    'date_created' => '2021-04-12T11:56:42',
    'date_created_gmt' => '2021-04-12T09:56:42',
    'date_modified' => '2021-04-13T10:04:12',
    'date_modified_gmt' => '2021-04-13T08:04:12',
    'date_paid' => '2021-04-12T11:56:44',
    'date_paid_gmt' => '2021-04-12T09:56:44',
    'discount_tax' => '0.00',
    'discount_total' => '0.00',
    'fee_lines' => [],
    'id' => 8163,
    'line_items' => [
                      {
                        'id' => 33594,
                        'meta_data' => [
                                         {
                                           'display_key' => 'Verpackungseinheit',
                                           'display_value' => "P\x{e4}ckchen mit 12 Samen",
                                           'id' => 323242,
                                           'key' => 'pa_verpackungseinheit',
                                           'value' => 'paeckchen-mit-12-samen'
                                         },
                                         {
                                           'display_key' => '_deliverytime',
                                           'display_value' => '151',
                                           'id' => 323243,
                                           'key' => '_deliverytime',
                                           'value' => '151'
                                         }
                                       ],
                        'name' => "Wassermelone M 11 (Blacktail Mountain) - P\x{e4}ckchen mit 12 Samen",
                        'parent_name' => 'Wassermelone M 11 (Blacktail Mountain)',
                        'price' => '2.95',
                        'product_id' => 4930,
                        'quantity' => 1,
                        'sku' => 'SW10002',
                        'subtotal' => '2.95',
                        'subtotal_tax' => '0.21',
                        'tax_class' => 'reduced-rate',
                        'taxes' => [
                                     {
                                       'id' => 255,
                                       'subtotal' => '0.2065',
                                       'total' => '0.2065'
                                     }
                                   ],
                        'total' => '2.95',
                        'total_tax' => '0.21',
                        'variation_id' => 4931
                      }
                    ],
    'meta_data' => [
                     {
                       'id' => 339538,
                       'key' => '_billing_fax',
                       'value' => ''
                     },
                     {
                       'id' => 339539,
                       'key' => '_shipping_fax',
                       'value' => ''
                     },
                     {
                       'id' => 339540,
                       'key' => 'is_vat_exempt',
                       'value' => 'no'
                     },
                     {
                       'id' => 339541,
                       'key' => 'wpml_language',
                       'value' => 'de'
                     }
                   ],
    'number' => '8163',
    'order_key' => 'wc_order_HjusTgQrJZHFQ',
    'parent_id' => 0,
    'payment_method' => 'german_market_purchase_on_account',
    'payment_method_title' => 'Kauf auf Rechnung',
    'prices_include_tax' => '0',
    'refunds' => [],
    'shipping' => {
                    'address_1' => 'Hauptstrasse 52a',
                    'address_2' => '',
                    'city' => 'Halle',
                    'company' => '',
                    'country' => 'DE',
                    'first_name' => 'Heike',
                    'last_name' => 'Mustermann',
                    'postcode' => '06118',
                    'state' => ''
                  },
    'shipping_lines' => [
                          {
                            'id' => 33595,
                            'instance_id' => '1',
                            'meta_data' => [
                                             {
                                               'display_key' => 'Positionen',
                                               'display_value' => "Wassermelone M 11 (Blacktail Mountain) - P\x{e4}ckchen mit 12 Samen &times; 1",
                                               'id' => 323249,
                                               'key' => 'Positionen',
                                               'value' => "Wassermelone M 11 (Blacktail Mountain) - P\x{e4}ckchen mit 12 Samen &times; 1"
                                             }
                                           ],
                            'method_id' => 'flat_rate',
                            'method_title' => 'Versandkostenpauschale',
                            'taxes' => [
                                         {
                                           'id' => 255,
                                           'subtotal' => '',
                                           'total' => '0.16'
                                         }
                                       ],
                            'total' => '2.34',
                            'total_tax' => '0.16'
                          }
                        ],
    'shipping_tax' => '0.16',
    'shipping_total' => '2.34',
    'status' => 'completed',
    'tax_lines' => [
                     {
                       'compound' => '0',
                       'id' => 33596,
                       'label' => 'MwSt.',
                       'meta_data' => [],
                       'rate_code' => 'DE-MWST.-2',
                       'rate_id' => 255,
                       'rate_percent' => 7,
                       'shipping_tax_total' => '0.16',
                       'tax_total' => '0.21'
                     }
                   ],
    'total' => '5.66',
    'total_tax' => '0.37',
    'transaction_id' => '',
    'version' => '4.9.2'
  );
  return \%data;
}

sub test_import {

  my $import = get_data();
  note('testing shoporder mapping json good');
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
