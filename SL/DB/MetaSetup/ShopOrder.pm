# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ShopOrder;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('shop_orders');

__PACKAGE__->meta->columns(
  amount                 => { type => 'numeric', precision => 15, scale => 5 },
  billing_city           => { type => 'text' },
  billing_company        => { type => 'text' },
  billing_country        => { type => 'text' },
  billing_department     => { type => 'text' },
  billing_email          => { type => 'text' },
  billing_fax            => { type => 'text' },
  billing_firstname      => { type => 'text' },
  billing_greeting       => { type => 'text' },
  billing_lastname       => { type => 'text' },
  billing_phone          => { type => 'text' },
  billing_street         => { type => 'text' },
  billing_vat            => { type => 'text' },
  billing_zipcode        => { type => 'text' },
  customer_city          => { type => 'text' },
  customer_company       => { type => 'text' },
  customer_country       => { type => 'text' },
  customer_department    => { type => 'text' },
  customer_email         => { type => 'text' },
  customer_fax           => { type => 'text' },
  customer_firstname     => { type => 'text' },
  customer_greeting      => { type => 'text' },
  customer_lastname      => { type => 'text' },
  customer_newsletter    => { type => 'boolean' },
  customer_phone         => { type => 'text' },
  customer_street        => { type => 'text' },
  customer_vat           => { type => 'text' },
  customer_zipcode       => { type => 'text' },
  delivery_city          => { type => 'text' },
  delivery_company       => { type => 'text' },
  delivery_country       => { type => 'text' },
  delivery_department    => { type => 'text' },
  delivery_email         => { type => 'text' },
  delivery_fax           => { type => 'text' },
  delivery_firstname     => { type => 'text' },
  delivery_greeting      => { type => 'text' },
  delivery_lastname      => { type => 'text' },
  delivery_phone         => { type => 'text' },
  delivery_street        => { type => 'text' },
  delivery_vat           => { type => 'text' },
  delivery_zipcode       => { type => 'text' },
  host                   => { type => 'text' },
  id                     => { type => 'serial', not_null => 1 },
  itime                  => { type => 'timestamp', default => 'now()' },
  kivi_customer_id       => { type => 'integer' },
  mtime                  => { type => 'timestamp' },
  netamount              => { type => 'numeric', precision => 15, scale => 5 },
  obsolete               => { type => 'boolean', default => 'false', not_null => 1 },
  order_date             => { type => 'timestamp' },
  payment_description    => { type => 'text' },
  payment_id             => { type => 'integer' },
  positions              => { type => 'integer' },
  remote_ip              => { type => 'text' },
  sepa_account_holder    => { type => 'text' },
  sepa_bic               => { type => 'text' },
  sepa_iban              => { type => 'text' },
  shipping_costs         => { type => 'numeric', precision => 15, scale => 5 },
  shipping_costs_id      => { type => 'integer' },
  shipping_costs_net     => { type => 'numeric', precision => 15, scale => 5 },
  shop_c_billing_id      => { type => 'integer' },
  shop_c_billing_number  => { type => 'text' },
  shop_c_delivery_id     => { type => 'integer' },
  shop_c_delivery_number => { type => 'text' },
  shop_customer_comment  => { type => 'text' },
  shop_customer_id       => { type => 'integer' },
  shop_customer_number   => { type => 'text' },
  shop_id                => { type => 'integer' },
  shop_ordernumber       => { type => 'text' },
  shop_trans_id          => { type => 'integer', not_null => 1 },
  tax_included           => { type => 'boolean' },
  transfer_date          => { type => 'date' },
  transferred            => { type => 'boolean', default => 'false' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  kivi_customer => {
    class       => 'SL::DB::Customer',
    key_columns => { kivi_customer_id => 'id' },
  },

  shop => {
    class       => 'SL::DB::Shop',
    key_columns => { shop_id => 'id' },
  },
);

1;
;
