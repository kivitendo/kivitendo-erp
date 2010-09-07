# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Employee;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'employee',

  columns => [
    id        => { type => 'integer', not_null => 1, sequence => 'id' },
    login     => { type => 'text' },
    startdate => { type => 'date', default => 'now' },
    enddate   => { type => 'date' },
    notes     => { type => 'text' },
    role      => { type => 'text' },
    sales     => { type => 'boolean', default => 'true' },
    itime     => { type => 'timestamp', default => 'now()' },
    mtime     => { type => 'timestamp' },
    name      => { type => 'text' },
    addr1     => { type => 'text' },
    addr2     => { type => 'text' },
    addr3     => { type => 'text' },
    addr4     => { type => 'text' },
    homephone => { type => 'text' },
    workphone => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'login' ],

  allow_inline_column_values => 1,
);

1;
;
