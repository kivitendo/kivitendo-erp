# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomVariable;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('custom_variables');

__PACKAGE__->meta->columns(
  id              => { type => 'integer', not_null => 1, sequence => 'custom_variables_id' },
  config_id       => { type => 'integer', not_null => 1 },
  trans_id        => { type => 'integer', not_null => 1 },
  bool_value      => { type => 'boolean' },
  timestamp_value => { type => 'timestamp' },
  text_value      => { type => 'text' },
  number_value    => { type => 'numeric', precision => 5, scale => 25 },
  itime           => { type => 'timestamp', default => 'now()' },
  mtime           => { type => 'timestamp' },
  sub_module      => { type => 'text', default => '', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  config => {
    class       => 'SL::DB::CustomVariableConfig',
    key_columns => { config_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
