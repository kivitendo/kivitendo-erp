# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomVariableConfig;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('custom_variable_configs');

__PACKAGE__->meta->columns(
  id                  => { type => 'integer', not_null => 1, sequence => 'custom_variable_configs_id' },
  name                => { type => 'text', not_null => 1 },
  description         => { type => 'text', not_null => 1 },
  type                => { type => 'text', not_null => 1 },
  module              => { type => 'text', not_null => 1 },
  default_value       => { type => 'text' },
  options             => { type => 'text' },
  searchable          => { type => 'boolean', not_null => 1 },
  includeable         => { type => 'boolean', not_null => 1 },
  included_by_default => { type => 'boolean', not_null => 1 },
  sortkey             => { type => 'integer', not_null => 1 },
  itime               => { type => 'timestamp', default => 'now()' },
  mtime               => { type => 'timestamp' },
  flags               => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

# __PACKAGE__->meta->initialize;

1;
;
