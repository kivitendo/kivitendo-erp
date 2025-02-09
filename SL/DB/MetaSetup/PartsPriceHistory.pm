# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartsPriceHistory;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('parts_price_history');

__PACKAGE__->meta->columns(
  ap_id        => { type => 'integer' },
  ar_id        => { type => 'integer' },
  customer_id  => { type => 'integer' },
  id           => { type => 'serial', not_null => 1 },
  lastcost     => { type => 'numeric', precision => 15, scale => 5 },
  listprice    => { type => 'numeric', precision => 15, scale => 5 },
  part_id      => { type => 'integer', not_null => 1 },
  price_factor => { type => 'numeric', default => 1, precision => 15, scale => 5 },
  sellprice    => { type => 'numeric', precision => 15, scale => 5 },
  valid_from   => { type => 'timestamp', not_null => 1 },
  vendor_id    => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(

# compile tests fail? why?
#  ap => {
#    class       => 'SL::DB::PurchaseInvoice',
#    key_columns => { ap_id => 'id' },
#  },

#  ar => {
#    class       => 'SL::DB::Invoice',
#    key_columns => { ar_id => 'id' },
#  },

  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },

  vendor => {
    class       => 'SL::DB::Vendor',
    key_columns => { vendor_id => 'id' },
  },
);

1;
;
