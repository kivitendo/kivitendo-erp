# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Shipto;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('shipto');

__PACKAGE__->meta->columns(
  trans_id           => { type => 'integer' },
  shiptoname         => { type => 'varchar', length => 75 },
  shiptodepartment_1 => { type => 'varchar', length => 75 },
  shiptodepartment_2 => { type => 'varchar', length => 75 },
  shiptostreet       => { type => 'varchar', length => 75 },
  shiptozipcode      => { type => 'varchar', length => 75 },
  shiptocity         => { type => 'varchar', length => 75 },
  shiptocountry      => { type => 'varchar', length => 75 },
  shiptocontact      => { type => 'varchar', length => 75 },
  shiptophone        => { type => 'varchar', length => 30 },
  shiptofax          => { type => 'varchar', length => 30 },
  shiptoemail        => { type => 'text' },
  itime              => { type => 'timestamp', default => 'now()' },
  mtime              => { type => 'timestamp' },
  module             => { type => 'text' },
  shipto_id          => { type => 'integer', not_null => 1, sequence => 'id' },
  shiptocp_gender    => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'shipto_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->relationships(
  ar => {
    class      => 'SL::DB::Invoice',
    column_map => { shipto_id => 'shipto_id' },
    type       => 'one to many',
  },

  delivery_orders => {
    class      => 'SL::DB::DeliveryOrder',
    column_map => { shipto_id => 'shipto_id' },
    type       => 'one to many',
  },

  oe => {
    class      => 'SL::DB::Order',
    column_map => { shipto_id => 'shipto_id' },
    type       => 'one to many',
  },
);

# __PACKAGE__->meta->initialize;

1;
;
