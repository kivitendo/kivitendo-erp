# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Order;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'oe',

  columns => [
    id                      => { type => 'integer', not_null => 1, sequence => 'id' },
    ordnumber               => { type => 'text', not_null => 1 },
    transdate               => { type => 'date', default => 'now' },
    vendor_id               => { type => 'integer' },
    customer_id             => { type => 'integer' },
    amount                  => { type => 'numeric', precision => 5, scale => 15 },
    netamount               => { type => 'numeric', precision => 5, scale => 15 },
    reqdate                 => { type => 'date' },
    taxincluded             => { type => 'boolean' },
    shippingpoint           => { type => 'text' },
    notes                   => { type => 'text' },
    curr                    => { type => 'character', length => 3 },
    employee_id             => { type => 'integer' },
    closed                  => { type => 'boolean', default => 'false' },
    quotation               => { type => 'boolean', default => 'false' },
    quonumber               => { type => 'text' },
    cusordnumber            => { type => 'text' },
    intnotes                => { type => 'text' },
    department_id           => { type => 'integer', default => '0' },
    itime                   => { type => 'timestamp', default => 'now()' },
    mtime                   => { type => 'timestamp' },
    shipvia                 => { type => 'text' },
    cp_id                   => { type => 'integer' },
    language_id             => { type => 'integer' },
    payment_id              => { type => 'integer' },
    delivery_customer_id    => { type => 'integer' },
    delivery_vendor_id      => { type => 'integer' },
    taxzone_id              => { type => 'integer' },
    proforma                => { type => 'boolean', default => 'false' },
    shipto_id               => { type => 'integer' },
    delivered               => { type => 'boolean', default => 'false' },
    globalproject_id        => { type => 'integer' },
    salesman_id             => { type => 'integer' },
    transaction_description => { type => 'text' },
    marge_total             => { type => 'numeric', precision => 5, scale => 15 },
    marge_percent           => { type => 'numeric', precision => 5, scale => 15 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { employee_id => 'id' },
    },

    globalproject => {
      class       => 'SL::DB::Project',
      key_columns => { globalproject_id => 'id' },
    },

    salesman => {
      class       => 'SL::DB::Employee',
      key_columns => { salesman_id => 'id' },
    },
  ],
);

1;
;
