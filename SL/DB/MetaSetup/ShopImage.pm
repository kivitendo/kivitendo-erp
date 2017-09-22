# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ShopImage;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('shop_images');

__PACKAGE__->meta->columns(
  file_id                => { type => 'integer' },
  id                     => { type => 'serial', not_null => 1 },
  itime                  => { type => 'timestamp', default => 'now()' },
  mtime                  => { type => 'timestamp' },
  object_id              => { type => 'text', not_null => 1 },
  org_file_height        => { type => 'integer' },
  org_file_width         => { type => 'integer' },
  position               => { type => 'integer' },
  thumbnail_content      => { type => 'bytea' },
  thumbnail_content_type => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  file => {
    class       => 'SL::DB::File',
    key_columns => { file_id => 'id' },
  },
);

1;
;
