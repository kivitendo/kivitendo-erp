# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::File;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('files');

__PACKAGE__->meta->columns(
  backend       => { type => 'enum', check_in => [ 'Filesystem', 'Webdav' ], db_type => 'files_backends', not_null => 1 },
  backend_data  => { type => 'text' },
  description   => { type => 'text' },
  file_name     => { type => 'text', not_null => 1 },
  file_type     => { type => 'text', not_null => 1 },
  id            => { type => 'serial', not_null => 1 },
  itime         => { type => 'timestamp', default => 'now()' },
  mime_type     => { type => 'text', not_null => 1 },
  mtime         => { type => 'timestamp' },
  object_id     => { type => 'integer', not_null => 1 },
  object_type   => { type => 'enum', check_in => [ 'sales_quotation', 'sales_order', 'sales_order_intake', 'request_quotation', 'purchase_quotation_intake', 'purchase_order', 'purchase_order_confirmation', 'sales_delivery_order', 'supplier_delivery_order', 'purchase_delivery_order', 'rma_delivery_order', 'invoice', 'invoice_for_advance_payment', 'final_invoice', 'credit_note', 'purchase_invoice', 'sales_reclamation', 'purchase_reclamation', 'dunning', 'dunning1', 'dunning2', 'dunning3', 'dunning_orig_invoice', 'dunning_invoice', 'customer', 'vendor', 'gl_transaction', 'part', 'shop_image', 'draft', 'letter', 'project', 'statement' ], db_type => 'file_object_types', not_null => 1 },
  print_variant => { type => 'text' },
  source        => { type => 'text', not_null => 1 },
  title         => { type => 'varchar', length => 45 },
  uid           => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
