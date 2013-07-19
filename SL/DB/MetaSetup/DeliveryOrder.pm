# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DeliveryOrder;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('delivery_orders');

__PACKAGE__->meta->columns(
  closed                  => { type => 'boolean', default => 'false' },
  cp_id                   => { type => 'integer' },
  currency_id             => { type => 'integer', not_null => 1 },
  cusordnumber            => { type => 'text' },
  customer_id             => { type => 'integer' },
  delivered               => { type => 'boolean', default => 'false' },
  department_id           => { type => 'integer' },
  donumber                => { type => 'text', not_null => 1 },
  employee_id             => { type => 'integer' },
  globalproject_id        => { type => 'integer' },
  id                      => { type => 'integer', not_null => 1, sequence => 'id' },
  intnotes                => { type => 'text' },
  is_sales                => { type => 'boolean' },
  itime                   => { type => 'timestamp', default => 'now()' },
  language_id             => { type => 'integer' },
  mtime                   => { type => 'timestamp' },
  notes                   => { type => 'text' },
  ordnumber               => { type => 'text' },
  oreqnumber              => { type => 'text' },
  reqdate                 => { type => 'date' },
  salesman_id             => { type => 'integer' },
  shippingpoint           => { type => 'text' },
  shipto_id               => { type => 'integer' },
  shipvia                 => { type => 'text' },
  taxincluded             => { type => 'boolean' },
  taxzone_id              => { type => 'integer' },
  terms                   => { type => 'integer' },
  transaction_description => { type => 'text' },
  transdate               => { type => 'date', default => 'now()' },
  vendor_id               => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  contact => {
    class       => 'SL::DB::Contact',
    key_columns => { cp_id => 'cp_id' },
  },

  currency => {
    class       => 'SL::DB::Currency',
    key_columns => { currency_id => 'id' },
  },

  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  department => {
    class       => 'SL::DB::Department',
    key_columns => { department_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  globalproject => {
    class       => 'SL::DB::Project',
    key_columns => { globalproject_id => 'id' },
  },

  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },

  salesman => {
    class       => 'SL::DB::Employee',
    key_columns => { salesman_id => 'id' },
  },

  shipto => {
    class       => 'SL::DB::Shipto',
    key_columns => { shipto_id => 'shipto_id' },
  },

  vendor => {
    class       => 'SL::DB::Vendor',
    key_columns => { vendor_id => 'id' },
  },
);

1;
;
