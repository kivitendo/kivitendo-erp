# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomVariableConfigPartsgroup;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('custom_variable_config_partsgroups');

__PACKAGE__->meta->columns(
  custom_variable_config_id => { type => 'integer', not_null => 1 },
  itime                     => { type => 'timestamp', default => 'now()' },
  mtime                     => { type => 'timestamp' },
  partsgroup_id             => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'custom_variable_config_id', 'partsgroup_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  custom_variable_config => {
    class       => 'SL::DB::CustomVariableConfig',
    key_columns => { custom_variable_config_id => 'id' },
  },

  partsgroup => {
    class       => 'SL::DB::PartsGroup',
    key_columns => { partsgroup_id => 'id' },
  },
);

1;
;
