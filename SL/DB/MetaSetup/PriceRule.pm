# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PriceRule;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('price_rules');

__PACKAGE__->meta->columns(
  discount  => { type => 'numeric', precision => 15, scale => 5 },
  id        => { type => 'serial', not_null => 1 },
  itime     => { type => 'timestamp' },
  mtime     => { type => 'timestamp' },
  name      => { type => 'text' },
  obsolete  => { type => 'boolean', default => 'false', not_null => 1 },
  price     => { type => 'numeric', precision => 15, scale => 5 },
  priority  => { type => 'integer', default => 3, not_null => 1 },
  reduction => { type => 'numeric', precision => 15, scale => 5 },
  type      => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
