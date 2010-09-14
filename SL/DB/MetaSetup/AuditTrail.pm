# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuditTrail;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'audittrail',

  columns => [
    trans_id    => { type => 'integer' },
    tablename   => { type => 'text' },
    reference   => { type => 'text' },
    formname    => { type => 'text' },
    action      => { type => 'text' },
    transdate   => { type => 'timestamp', default => 'now' },
    employee_id => { type => 'integer' },
    id          => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
