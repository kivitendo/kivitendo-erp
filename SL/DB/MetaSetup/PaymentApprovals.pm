# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PaymentApprovals;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('payment_approvals');

__PACKAGE__->meta->columns(
  ap_id       => { type => 'integer', not_null => 1 },
  employee_id => { type => 'integer', not_null => 1 },
  itime       => { type => 'timestamp', default => 'now()' },
  mtime       => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'ap_id', 'employee_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  ap => {
    class       => 'SL::DB::PurchaseInvoice',
    key_columns => { ap_id => 'id' },
  },

  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },
);

1;
;
