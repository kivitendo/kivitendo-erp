# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::StockCounting;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('stock_countings');

__PACKAGE__->meta->columns(
  bin_id        => { type => 'integer' },
  description   => { type => 'text' },
  employee_id   => { type => 'integer', not_null => 1 },
  id            => { type => 'integer', not_null => 1, sequence => 'id' },
  itime         => { type => 'timestamp', default => 'now()' },
  mtime         => { type => 'timestamp' },
  name          => { type => 'text', not_null => 1 },
  part_id       => { type => 'integer' },
  partsgroup_id => { type => 'integer' },
  vendor_id     => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'name' ]);

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

  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },

  partsgroup => {
    class       => 'SL::DB::PartsGroup',
    key_columns => { partsgroup_id => 'id' },
  },

  vendor => {
    class       => 'SL::DB::Vendor',
    key_columns => { vendor_id => 'id' },
  },
);

1;
;
