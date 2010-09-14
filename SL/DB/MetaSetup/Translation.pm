# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Translation;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'translation',

  columns => [
    parts_id        => { type => 'integer' },
    language_id     => { type => 'integer' },
    translation     => { type => 'text' },
    itime           => { type => 'timestamp', default => 'now()' },
    mtime           => { type => 'timestamp' },
    longdescription => { type => 'text' },
    id              => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
