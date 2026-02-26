# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SearchProfileSetting;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('search_profile_settings');

__PACKAGE__->meta->columns(
  boolean_value     => { type => 'boolean' },
  date_value        => { type => 'date' },
  id                => { type => 'serial', not_null => 1 },
  integer_value     => { type => 'integer' },
  itime             => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime             => { type => 'timestamp' },
  name              => { type => 'text', not_null => 1 },
  search_profile_id => { type => 'integer', not_null => 1 },
  text_value        => { type => 'text' },
  type              => { type => 'enum', check_in => [ 'boolean', 'date', 'integer', 'text' ], db_type => 'search_profile_settings_value_type', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  search_profile => {
    class       => 'SL::DB::SearchProfile',
    key_columns => { search_profile_id => 'id' },
  },
);

1;
;
