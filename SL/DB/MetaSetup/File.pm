# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::File;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('files');

__PACKAGE__->meta->columns(
  backend      => { type => 'text' },
  backend_data => { type => 'text' },
  description  => { type => 'text' },
  file_name    => { type => 'text', not_null => 1 },
  file_type    => { type => 'text', not_null => 1 },
  id           => { type => 'serial', not_null => 1 },
  itime        => { type => 'timestamp', default => 'now()' },
  mime_type    => { type => 'text', not_null => 1 },
  mtime        => { type => 'timestamp' },
  object_id    => { type => 'integer', not_null => 1 },
  object_type  => { type => 'text', not_null => 1 },
  source       => { type => 'text', not_null => 1 },
  title        => { type => 'varchar', length => 45 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
