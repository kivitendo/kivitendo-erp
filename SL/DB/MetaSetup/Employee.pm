# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Employee;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('employee');

__PACKAGE__->meta->columns(
  deleted           => { type => 'boolean', default => 'false' },
  deleted_email     => { type => 'text' },
  deleted_fax       => { type => 'text' },
  deleted_signature => { type => 'text' },
  deleted_tel       => { type => 'text' },
  enddate           => { type => 'date' },
  id                => { type => 'integer', not_null => 1, sequence => 'id' },
  itime             => { type => 'timestamp', default => 'now()' },
  login             => { type => 'text' },
  mtime             => { type => 'timestamp' },
  name              => { type => 'text' },
  sales             => { type => 'boolean', default => 'true' },
  startdate         => { type => 'date', default => 'now' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'login' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
