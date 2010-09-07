# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomVariableValidity;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'custom_variables_validity',

  columns => [
    id        => { type => 'integer', not_null => 1, sequence => 'id' },
    config_id => { type => 'integer', not_null => 1 },
    trans_id  => { type => 'integer', not_null => 1 },
    itime     => { type => 'timestamp', default => 'now()' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    config => {
      class       => 'SL::DB::CustomVariableConfig',
      key_columns => { config_id => 'id' },
    },
  ],
);

1;
;
