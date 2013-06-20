# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Translation;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('translation');

__PACKAGE__->meta->columns(
  parts_id        => { type => 'integer' },
  language_id     => { type => 'integer' },
  translation     => { type => 'text' },
  itime           => { type => 'timestamp', default => 'now()' },
  mtime           => { type => 'timestamp' },
  longdescription => { type => 'text' },
  id              => { type => 'serial', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
