# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DeliveryOrder;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'delivery_orders',

  columns => [
    id                      => { type => 'integer', not_null => 1, sequence => 'id' },
    donumber                => { type => 'text', not_null => 1 },
    ordnumber               => { type => 'text' },
    transdate               => { type => 'date', default => 'now()' },
    vendor_id               => { type => 'integer' },
    customer_id             => { type => 'integer' },
    reqdate                 => { type => 'date' },
    shippingpoint           => { type => 'text' },
    notes                   => { type => 'text' },
    intnotes                => { type => 'text' },
    employee_id             => { type => 'integer' },
    closed                  => { type => 'boolean', default => 'false' },
    delivered               => { type => 'boolean', default => 'false' },
    cusordnumber            => { type => 'text' },
    oreqnumber              => { type => 'text' },
    department_id           => { type => 'integer' },
    shipvia                 => { type => 'text' },
    cp_id                   => { type => 'integer' },
    language_id             => { type => 'integer' },
    shipto_id               => { type => 'integer' },
    globalproject_id        => { type => 'integer' },
    salesman_id             => { type => 'integer' },
    transaction_description => { type => 'text' },
    is_sales                => { type => 'boolean' },
    itime                   => { type => 'timestamp', default => 'now()' },
    mtime                   => { type => 'timestamp' },
    notes_bottom            => { type => 'text' },
    taxzone_id              => { type => 'integer' },
    taxincluded             => { type => 'boolean' },
    terms                   => { type => 'integer' },
    curr                    => { type => 'character', length => 3 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    contact => {
      class       => 'SL::DB::Contact',
      key_columns => { cp_id => 'cp_id' },
    },

    customer => {
      class       => 'SL::DB::Customer',
      key_columns => { customer_id => 'id' },
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

    vendor => {
      class       => 'SL::DB::Vendor',
      key_columns => { vendor_id => 'id' },
    },
  ],
);

1;
;
