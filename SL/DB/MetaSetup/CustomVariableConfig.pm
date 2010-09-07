# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomVariableConfig;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'custom_variable_configs',

  columns => [
    id                  => { type => 'integer', not_null => 1, sequence => 'custom_variable_configs_id' },
    name                => { type => 'text' },
    description         => { type => 'text' },
    type                => { type => 'varchar', length => 20 },
    module              => { type => 'varchar', length => 20 },
    default_value       => { type => 'text' },
    options             => { type => 'text' },
    searchable          => { type => 'boolean' },
    includeable         => { type => 'boolean' },
    included_by_default => { type => 'boolean' },
    sortkey             => { type => 'integer' },
    itime               => { type => 'timestamp', default => 'now()' },
    mtime               => { type => 'timestamp' },
    flags               => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
