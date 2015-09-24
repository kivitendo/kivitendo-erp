# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TaxKey;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('taxkeys');

__PACKAGE__->meta->columns(
  chart_id  => { type => 'integer', not_null => 1 },
  id        => { type => 'integer', not_null => 1, sequence => 'id' },
  pos_ustva => { type => 'integer' },
  startdate => { type => 'date', not_null => 1 },
  tax_id    => { type => 'integer', not_null => 1 },
  taxkey_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'chart_id', 'startdate' ]);

__PACKAGE__->meta->foreign_keys(
  chart => {
    class       => 'SL::DB::Chart',
    key_columns => { chart_id => 'id' },
  },

  tax => {
    class       => 'SL::DB::Tax',
    key_columns => { tax_id => 'id' },
  },
);

1;
;
