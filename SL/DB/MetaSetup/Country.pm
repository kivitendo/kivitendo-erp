# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Country;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('countries');

__PACKAGE__->meta->columns(
  description_de => { type => 'text', not_null => 1 },
  description_en => { type => 'text', not_null => 1 },
  id             => { type => 'serial', not_null => 1 },
  iso2           => { type => 'text', not_null => 1 },
  itime          => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime          => { type => 'timestamp' },
  sortorder      => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'iso2' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
