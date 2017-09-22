# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ShopPart;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('shop_parts');

__PACKAGE__->meta->columns(
  active              => { type => 'boolean', default => 'false', not_null => 1 },
  active_price_source => { type => 'text' },
  front_page          => { type => 'boolean', default => 'false', not_null => 1 },
  id                  => { type => 'serial', not_null => 1 },
  itime               => { type => 'timestamp', default => 'now()' },
  last_update         => { type => 'timestamp' },
  metatag_description => { type => 'text' },
  metatag_keywords    => { type => 'text' },
  metatag_title       => { type => 'text' },
  mtime               => { type => 'timestamp' },
  part_id             => { type => 'integer', not_null => 1 },
  shop_category       => { type => 'array' },
  shop_description    => { type => 'text' },
  shop_id             => { type => 'integer', not_null => 1 },
  show_date           => { type => 'date' },
  sortorder           => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'shop_id', 'part_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },

  shop => {
    class       => 'SL::DB::Shop',
    key_columns => { shop_id => 'id' },
  },
);

1;
;
