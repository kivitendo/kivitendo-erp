# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SearchProfile;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('search_profiles');

__PACKAGE__->meta->columns(
  default_profile => { type => 'boolean', default => 'false', not_null => 1 },
  employee_id     => { type => 'integer', not_null => 1 },
  id              => { type => 'serial', not_null => 1 },
  itime           => { type => 'timestamp', default => 'now()', not_null => 1 },
  module          => { type => 'enum', check_in => [ 'ap/search' ], db_type => 'search_profiles_module_type', not_null => 1 },
  mtime           => { type => 'timestamp' },
  name            => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },
);

1;
;
