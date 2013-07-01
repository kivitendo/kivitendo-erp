# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomVariable;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('custom_variables');

__PACKAGE__->meta->columns(
  bool_value      => { type => 'boolean' },
  config_id       => { type => 'integer', not_null => 1 },
  id              => { type => 'integer', not_null => 1, sequence => 'custom_variables_id' },
  itime           => { type => 'timestamp', default => 'now()' },
  mtime           => { type => 'timestamp' },
  number_value    => { type => 'numeric', precision => 5, scale => 25 },
  sub_module      => { type => 'text', default => '', not_null => 1 },
  text_value      => { type => 'text' },
  timestamp_value => { type => 'timestamp' },
  trans_id        => { type => 'integer', not_null => 1 },
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
