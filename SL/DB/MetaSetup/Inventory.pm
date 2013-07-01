# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Inventory;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('inventory');

__PACKAGE__->meta->columns(
  bestbefore    => { type => 'date' },
  bin_id        => { type => 'integer', not_null => 1 },
  chargenumber  => { type => 'text', default => '', not_null => 1 },
  comment       => { type => 'text' },
  employee_id   => { type => 'integer', not_null => 1 },
  id            => { type => 'serial', not_null => 1 },
  itime         => { type => 'timestamp', default => 'now()' },
  mtime         => { type => 'timestamp' },
  oe_id         => { type => 'integer' },
  orderitems_id => { type => 'integer' },
  parts_id      => { type => 'integer', not_null => 1 },
  project_id    => { type => 'integer' },
  qty           => { type => 'numeric', precision => 5, scale => 25 },
  shippingdate  => { type => 'date' },
  trans_id      => { type => 'integer', not_null => 1 },
  trans_type_id => { type => 'integer', not_null => 1 },
  warehouse_id  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
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
);

1;
;
