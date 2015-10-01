# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SepaExportMessageId;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('sepa_export_message_ids');

__PACKAGE__->meta->columns(
  id             => { type => 'serial', not_null => 1 },
  message_id     => { type => 'text', not_null => 1 },
  sepa_export_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  sepa_export => {
    class       => 'SL::DB::SepaExport',
    key_columns => { sepa_export_id => 'id' },
  },
);

1;
;
