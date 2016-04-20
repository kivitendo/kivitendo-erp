# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Letter;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('letter');

__PACKAGE__->meta->columns(
  body         => { type => 'text' },
  cp_id        => { type => 'integer' },
  customer_id  => { type => 'integer', not_null => 1 },
  date         => { type => 'date' },
  employee_id  => { type => 'integer' },
  greeting     => { type => 'text' },
  id           => { type => 'integer', not_null => 1, sequence => 'id' },
  intnotes     => { type => 'text' },
  itime        => { type => 'timestamp', default => 'now()' },
  letternumber => { type => 'text' },
  mtime        => { type => 'timestamp' },
  reference    => { type => 'text' },
  salesman_id  => { type => 'integer' },
  subject      => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  contact => {
    class       => 'SL::DB::Contact',
    key_columns => { cp_id => 'cp_id' },
  },

  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  salesman => {
    class       => 'SL::DB::Employee',
    key_columns => { salesman_id => 'id' },
  },
);

1;
;
