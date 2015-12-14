# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthSchemaInfo;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('schema_info');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  itime => { type => 'timestamp', default => 'now()' },
  login => { type => 'text' },
  tag   => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'tag' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
