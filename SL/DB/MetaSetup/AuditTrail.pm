# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuditTrail;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('audittrail');

__PACKAGE__->meta->columns(
  trans_id    => { type => 'integer' },
  tablename   => { type => 'text' },
  reference   => { type => 'text' },
  formname    => { type => 'text' },
  action      => { type => 'text' },
  transdate   => { type => 'timestamp', default => 'now' },
  employee_id => { type => 'integer' },
  id          => { type => 'serial', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

# __PACKAGE__->meta->initialize;

1;
;
