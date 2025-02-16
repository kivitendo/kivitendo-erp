# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SepaExportItemsAccTrans;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('sepa_export_items_acc_trans');

__PACKAGE__->meta->columns(
  acc_trans_id        => { type => 'integer', not_null => 1 },
  itime               => { type => 'timestamp', default => 'now()' },
  mtime               => { type => 'timestamp' },
  sepa_export_item_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'sepa_export_item_id', 'acc_trans_id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  acc_transaction => {
    class       => 'SL::DB::AccTransaction',
    key_columns => { acc_trans_id => 'acc_trans_id' },
  },

  sepa_export_item => {
    class       => 'SL::DB::SepaExportItem',
    key_columns => { sepa_export_item_id => 'id' },
  },
);

1;
;
