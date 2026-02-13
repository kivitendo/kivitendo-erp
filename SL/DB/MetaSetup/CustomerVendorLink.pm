# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomerVendorLink;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('customer_vendor_links');

__PACKAGE__->meta->columns(
  customer_id => { type => 'integer', not_null => 1 },
  vendor_id   => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'customer_id', 'vendor_id' ]);

__PACKAGE__->meta->unique_keys(
  [ 'customer_id' ],
  [ 'vendor_id' ],
);

__PACKAGE__->meta->foreign_keys(
  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
    rel_type    => 'one to one',
  },

  vendor => {
    class       => 'SL::DB::Vendor',
    key_columns => { vendor_id => 'id' },
    rel_type    => 'one to one',
  },
);

1;
;
