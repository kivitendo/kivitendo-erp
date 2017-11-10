# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::CustomDataExportQueryParameter;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('custom_data_export_query_parameters');

__PACKAGE__->meta->columns(
  default_value      => { type => 'text' },
  default_value_type => { type => 'enum', check_in => [ 'none', 'current_user_login', 'sql_query', 'fixed_value' ], db_type => 'custom_data_export_query_parameter_default_value_type_enum', not_null => 1 },
  description        => { type => 'text' },
  id                 => { type => 'serial', not_null => 1 },
  itime              => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime              => { type => 'timestamp', default => 'now()', not_null => 1 },
  name               => { type => 'text', not_null => 1 },
  parameter_type     => { type => 'enum', check_in => [ 'text', 'number', 'date', 'timestamp' ], db_type => 'custom_data_export_query_parameter_type_enum', not_null => 1 },
  query_id           => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  query => {
    class       => 'SL::DB::CustomDataExportQuery',
    key_columns => { query_id => 'id' },
  },
);

1;
;
