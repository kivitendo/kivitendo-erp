# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Employee;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('employee');

__PACKAGE__->meta->columns(
  addr1     => { type => 'text' },
  addr2     => { type => 'text' },
  addr3     => { type => 'text' },
  addr4     => { type => 'text' },
  deleted   => { type => 'boolean', default => 'false' },
  enddate   => { type => 'date' },
  homephone => { type => 'text' },
  id        => { type => 'integer', not_null => 1, sequence => 'id' },
  itime     => { type => 'timestamp', default => 'now()' },
  login     => { type => 'text' },
  mtime     => { type => 'timestamp' },
  name      => { type => 'text' },
  notes     => { type => 'text' },
  sales     => { type => 'boolean', default => 'true' },
  startdate => { type => 'date', default => 'now' },
  workphone => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'login' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
