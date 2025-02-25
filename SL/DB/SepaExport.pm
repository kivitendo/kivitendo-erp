package SL::DB::SepaExport;

use strict;

use SL::DB::MetaSetup::SepaExport;

__PACKAGE__->meta->add_relationship(
  message_ids  => {
    type       => 'one to many',
    class      => 'SL::DB::SepaExportMessageId',
    column_map => { id => 'sepa_export_id' },
  },
  sepa_exports_acc_trans => {
    type            => 'one to many',
    class           => 'SL::DB::SepaExportsAccTrans',
    column_map      => { id => 'sepa_exports_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

1;
