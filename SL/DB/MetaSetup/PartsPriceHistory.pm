# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartsPriceHistory;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('parts_price_history');

__PACKAGE__->meta->columns(
  id         => { type => 'serial', not_null => 1 },
  lastcost   => { type => 'numeric', precision => 15, scale => 5 },
  listprice  => { type => 'numeric', precision => 15, scale => 5 },
  part_id    => { type => 'integer', not_null => 1 },
  sellprice  => { type => 'numeric', precision => 15, scale => 5 },
  valid_from => { type => 'timestamp', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },
);

1;
;
