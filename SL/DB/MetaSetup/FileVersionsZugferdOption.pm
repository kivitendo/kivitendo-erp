# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FileVersionsZugferdOption;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('file_versions_zugferd_options');

__PACKAGE__->meta->columns(
  attach   => { type => 'boolean', default => 'false', not_null => 1 },
  doc_id   => { type => 'text' },
  doc_name => { type => 'text' },
  guid     => { type => 'text', not_null => 1 },
  id       => { type => 'serial', not_null => 1 },
  itime    => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime    => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'guid' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  file_version => {
    class       => 'SL::DB::FileVersion',
    key_columns => { guid => 'guid' },
    rel_type    => 'one to one',
  },
);

1;

