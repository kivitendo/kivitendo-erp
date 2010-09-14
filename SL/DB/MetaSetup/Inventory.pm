# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Inventory;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'inventory',

  columns => [
    warehouse_id  => { type => 'integer', not_null => 1 },
    parts_id      => { type => 'integer', not_null => 1 },
    oe_id         => { type => 'integer' },
    orderitems_id => { type => 'integer' },
    shippingdate  => { type => 'date' },
    employee_id   => { type => 'integer', not_null => 1 },
    itime         => { type => 'timestamp', default => 'now()' },
    mtime         => { type => 'timestamp' },
    bin_id        => { type => 'integer', not_null => 1 },
    qty           => { type => 'numeric', precision => 5, scale => 25 },
    trans_id      => { type => 'integer', not_null => 1 },
    trans_type_id => { type => 'integer', not_null => 1 },
    project_id    => { type => 'integer' },
    chargenumber  => { type => 'text' },
    comment       => { type => 'text' },
    bestbefore    => { type => 'date' },
    id            => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    bin => {
      class       => 'SL::DB::Bin',
      key_columns => { bin_id => 'id' },
    },

    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { employee_id => 'id' },
    },

    parts => {
      class       => 'SL::DB::Part',
      key_columns => { parts_id => 'id' },
    },

    project => {
      class       => 'SL::DB::Project',
      key_columns => { project_id => 'id' },
    },

    trans_type => {
      class       => 'SL::DB::TransferType',
      key_columns => { trans_type_id => 'id' },
    },

    warehouse => {
      class       => 'SL::DB::Warehouse',
      key_columns => { warehouse_id => 'id' },
    },
  ],
);

1;
;
