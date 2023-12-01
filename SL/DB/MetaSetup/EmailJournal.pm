# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::EmailJournal;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('email_journal');

__PACKAGE__->meta->columns(
  body               => { type => 'text', not_null => 1 },
  email_import_id    => { type => 'integer' },
  extended_status    => { type => 'text', not_null => 1 },
  folder             => { type => 'text' },
  folder_uidvalidity => { type => 'text' },
  from               => { type => 'text', not_null => 1 },
  headers            => { type => 'text', not_null => 1 },
  id                 => { type => 'serial', not_null => 1 },
  itime              => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime              => { type => 'timestamp', default => 'now()', not_null => 1 },
  obsolete           => { type => 'boolean', default => 'false', not_null => 1 },
  recipients         => { type => 'text', not_null => 1 },
  record_type        => { type => 'enum', check_in => [ 'sales_order', 'purchase_order', 'sales_quotation', 'request_quotation', 'purchase_quotation_intake', 'sales_order_intake', 'sales_delivery_order', 'purchase_delivery_order', 'supplier_delivery_order', 'rma_delivery_order', 'sales_reclamation', 'purchase_reclamation', 'invoice', 'invoice_for_advance_payment', 'invoice_for_advance_payment_storno', 'final_invoice', 'invoice_storno', 'credit_note', 'credit_note_storno', 'purchase_invoice', 'purchase_credit_note', 'ap_transaction', 'ar_transaction', 'gl_transaction', 'purchase_order_confirmation', 'catch_all' ], db_type => 'email_journal_record_type' },
  sender_id          => { type => 'integer' },
  sent_on            => { type => 'timestamp', default => 'now()', not_null => 1 },
  status             => { type => 'enum', check_in => [ 'sent', 'send_failed', 'imported' ], db_type => 'email_journal_status', not_null => 1 },
  subject            => { type => 'text', not_null => 1 },
  uid                => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  email_import => {
    class       => 'SL::DB::EmailImport',
    key_columns => { email_import_id => 'id' },
  },

  sender => {
    class       => 'SL::DB::Employee',
    key_columns => { sender_id => 'id' },
  },
);

1;
;
