# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TimeRecording;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('time_recordings');

__PACKAGE__->meta->columns(
  booked          => { type => 'boolean', default => 'false' },
  customer_id     => { type => 'integer', not_null => 1 },
  description     => { type => 'text', not_null => 1 },
  employee_id     => { type => 'integer', not_null => 1 },
  end_time        => { type => 'timestamp' },
  id              => { type => 'serial', not_null => 1 },
  itime           => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime           => { type => 'timestamp', default => 'now()', not_null => 1 },
  payroll         => { type => 'boolean', default => 'false' },
  project_id      => { type => 'integer' },
  staff_member_id => { type => 'integer', not_null => 1 },
  start_time      => { type => 'timestamp', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },

  staff_member => {
    class       => 'SL::DB::Employee',
    key_columns => { staff_member_id => 'id' },
  },
);

1;
;
