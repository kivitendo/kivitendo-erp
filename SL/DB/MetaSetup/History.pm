# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::History;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('history_erp');

__PACKAGE__->meta->columns(
  addition    => { type => 'text' },
  employee_id => { type => 'integer' },
  id          => { type => 'integer', not_null => 1, sequence => 'id' },
  itime       => { type => 'timestamp', default => 'now()' },
  snumbers    => { type => 'text' },
  trans_id    => { type => 'integer' },
  what_done   => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },
);

1;
;
