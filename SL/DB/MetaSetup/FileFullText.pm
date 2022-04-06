# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FileFullText;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('file_full_texts');

__PACKAGE__->meta->columns(
  file_id   => { type => 'integer', not_null => 1 },
  full_text => { type => 'text', not_null => 1 },
  id        => { type => 'serial', not_null => 1 },
  itime     => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime     => { type => 'timestamp' },
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
