# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Draft;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('drafts');

__PACKAGE__->meta->columns(
  description => { type => 'text' },
  employee_id => { type => 'integer' },
  form        => { type => 'text' },
  id          => { type => 'varchar', length => 50, not_null => 1 },
  itime       => { type => 'timestamp', default => 'now()' },
  module      => { type => 'varchar', length => 50, not_null => 1 },
  submodule   => { type => 'varchar', length => 50, not_null => 1 },
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
