# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::SepaExportItem;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'sepa_export_items',

  columns => [
    id                       => { type => 'integer', not_null => 1, sequence => 'id' },
    sepa_export_id           => { type => 'integer', not_null => 1 },
    ap_id                    => { type => 'integer' },
    chart_id                 => { type => 'integer', not_null => 1 },
    amount                   => { type => 'numeric', precision => 5, scale => 25 },
    reference                => { type => 'varchar', length => 35 },
    requested_execution_date => { type => 'date' },
    executed                 => { type => 'boolean', default => 'false' },
    execution_date           => { type => 'date' },
    our_iban                 => { type => 'varchar', length => 100 },
    our_bic                  => { type => 'varchar', length => 100 },
    vc_iban                  => { type => 'varchar', length => 100 },
    vc_bic                   => { type => 'varchar', length => 100 },
    end_to_end_id            => { type => 'varchar', length => 35 },
    ar_id                    => { type => 'integer' },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    ap => {
      class       => 'SL::DB::PurchaseInvoice',
      key_columns => { ap_id => 'id' },
    },

    ar => {
      class       => 'SL::DB::Invoice',
      key_columns => { ar_id => 'id' },
    },

    chart => {
      class       => 'SL::DB::Chart',
      key_columns => { chart_id => 'id' },
    },

    sepa_export => {
      class       => 'SL::DB::SepaExport',
      key_columns => { sepa_export_id => 'id' },
    },
  ],
);

1;
;
