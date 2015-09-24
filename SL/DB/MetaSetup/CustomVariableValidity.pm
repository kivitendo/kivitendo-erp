# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomVariableValidity;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('custom_variables_validity');

__PACKAGE__->meta->columns(
  config_id => { type => 'integer', not_null => 1 },
  id        => { type => 'integer', not_null => 1, sequence => 'id' },
  itime     => { type => 'timestamp', default => 'now()' },
  trans_id  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  config => {
    class       => 'SL::DB::CustomVariableConfig',
    key_columns => { config_id => 'id' },
  },
);

1;
;
