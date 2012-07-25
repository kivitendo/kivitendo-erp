# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::BusinessModel;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('business_models');

__PACKAGE__->meta->columns(
  business_id          => { type => 'integer', not_null => 1 },
  itime                => { type => 'timestamp', default => 'now()' },
  model                => { type => 'text' },
  mtime                => { type => 'timestamp' },
  part_description     => { type => 'text' },
  part_longdescription => { type => 'text' },
  parts_id             => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'parts_id', 'business_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  business => {
    class       => 'SL::DB::Business',
    key_columns => { business_id => 'id' },
  },

  parts => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },
);

1;
;
