# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Secret;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('secrets');

__PACKAGE__->meta->columns(
  cipher      => { type => 'bytea' },
  description => { type => 'text' },
  id          => { type => 'serial', not_null => 1 },
  iv          => { type => 'bytea' },
  salt        => { type => 'text' },
  tag         => { type => 'text', not_null => 1 },
  utf_flag    => { type => 'boolean', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'tag' ]);

1;
;
