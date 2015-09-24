# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::GenericTranslation;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('generic_translations');

__PACKAGE__->meta->columns(
  id               => { type => 'serial', not_null => 1 },
  language_id      => { type => 'integer' },
  translation      => { type => 'text' },
  translation_id   => { type => 'integer' },
  translation_type => { type => 'varchar', length => 100, not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  language => {
    class       => 'SL::DB::Language',
    key_columns => { language_id => 'id' },
  },
);

1;
;
