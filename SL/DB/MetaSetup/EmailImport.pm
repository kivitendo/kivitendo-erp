# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::EmailImport;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('email_imports');

__PACKAGE__->meta->columns(
  folder    => { type => 'text', not_null => 1 },
  host_name => { type => 'text', not_null => 1 },
  id        => { type => 'serial', not_null => 1 },
  itime     => { type => 'timestamp', default => 'now()', not_null => 1 },
  user_name => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
