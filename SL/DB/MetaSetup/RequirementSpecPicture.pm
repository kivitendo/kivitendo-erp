# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecPicture;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('requirement_spec_pictures');

__PACKAGE__->meta->columns(
  description            => { type => 'text' },
  id                     => { type => 'serial', not_null => 1 },
  itime                  => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime                  => { type => 'timestamp' },
  number                 => { type => 'text', not_null => 1 },
  picture_content        => { type => 'bytea', not_null => 1 },
  picture_content_type   => { type => 'text', not_null => 1 },
  picture_file_name      => { type => 'text', not_null => 1 },
  picture_height         => { type => 'integer', not_null => 1 },
  picture_mtime          => { type => 'timestamp', default => 'now()', not_null => 1 },
  picture_width          => { type => 'integer', not_null => 1 },
  position               => { type => 'integer', not_null => 1 },
  requirement_spec_id    => { type => 'integer', not_null => 1 },
  text_block_id          => { type => 'integer', not_null => 1 },
  thumbnail_content      => { type => 'bytea', not_null => 1 },
  thumbnail_content_type => { type => 'text', not_null => 1 },
  thumbnail_height       => { type => 'integer', not_null => 1 },
  thumbnail_width        => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  requirement_spec => {
    class       => 'SL::DB::RequirementSpec',
    key_columns => { requirement_spec_id => 'id' },
  },

  text_block => {
    class       => 'SL::DB::RequirementSpecTextBlock',
    key_columns => { text_block_id => 'id' },
  },
);

1;
;
