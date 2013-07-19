# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuditTrail;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('audittrail');

__PACKAGE__->meta->columns(
  action      => { type => 'text' },
  employee_id => { type => 'integer' },
  formname    => { type => 'text' },
  id          => { type => 'serial', not_null => 1 },
  reference   => { type => 'text' },
  tablename   => { type => 'text' },
  trans_id    => { type => 'integer' },
  transdate   => { type => 'timestamp', default => 'now' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
