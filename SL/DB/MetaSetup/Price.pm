# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Price;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'prices',

  columns => [
    parts_id      => { type => 'integer' },
    pricegroup_id => { type => 'integer' },
    price         => { type => 'numeric', precision => 5, scale => 15 },
    id            => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    parts => {
      class       => 'SL::DB::Part',
      key_columns => { parts_id => 'id' },
    },

    pricegroup => {
      class       => 'SL::DB::Pricegroup',
      key_columns => { pricegroup_id => 'id' },
    },
  ],
);

1;
;
