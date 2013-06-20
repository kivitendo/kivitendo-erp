# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Employee;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('employee');

__PACKAGE__->meta->columns(
  id        => { type => 'integer', not_null => 1, sequence => 'id' },
  login     => { type => 'text' },
  startdate => { type => 'date', default => 'now' },
  enddate   => { type => 'date' },
  notes     => { type => 'text' },
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
  deleted   => { type => 'boolean', default => 'false' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'login' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->relationships(
  ap => {
    class      => 'SL::DB::PurchaseInvoice',
    column_map => { id => 'employee_id' },
    type       => 'one to many',
  },

  ar => {
    class      => 'SL::DB::Invoice',
    column_map => { id => 'employee_id' },
    type       => 'one to many',
  },

  ar_objs => {
    class      => 'SL::DB::Invoice',
    column_map => { id => 'salesman_id' },
    type       => 'one to many',
  },

  drafts => {
    class      => 'SL::DB::Draft',
    column_map => { id => 'employee_id' },
    type       => 'one to many',
  },
);

# __PACKAGE__->meta->initialize;

1;
;
