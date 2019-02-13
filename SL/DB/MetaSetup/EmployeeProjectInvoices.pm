# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::EmployeeProjectInvoices;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('employee_project_invoices');

__PACKAGE__->meta->columns(
  employee_id => { type => 'integer', not_null => 1 },
  project_id  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'employee_id', 'project_id' ]);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },

  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },
);

1;
;
