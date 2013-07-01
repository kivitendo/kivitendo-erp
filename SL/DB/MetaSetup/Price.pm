# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Price;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('prices');

__PACKAGE__->meta->columns(
  id            => { type => 'serial', not_null => 1 },
  parts_id      => { type => 'integer' },
  price         => { type => 'numeric', precision => 5, scale => 15 },
  pricegroup_id => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  parts => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },

  pricegroup => {
    class       => 'SL::DB::Pricegroup',
    key_columns => { pricegroup_id => 'id' },
  },
);

1;
;
