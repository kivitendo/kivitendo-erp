# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PriceFactor;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'price_factors',

  columns => [
    id          => { type => 'integer', not_null => 1, sequence => 'id' },
    description => { type => 'text' },
    factor      => { type => 'numeric', precision => 5, scale => 15 },
    sortkey     => { type => 'integer' },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
