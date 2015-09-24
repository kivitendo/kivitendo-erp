# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PriceFactor;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('price_factors');

__PACKAGE__->meta->columns(
  description => { type => 'text' },
  factor      => { type => 'numeric', precision => 15, scale => 5 },
  id          => { type => 'integer', not_null => 1, sequence => 'id' },
  sortkey     => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
