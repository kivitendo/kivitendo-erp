# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TaxKey;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'taxkeys',

  columns => [
    id        => { type => 'integer', not_null => 1, sequence => 'id' },
    chart_id  => { type => 'integer', not_null => 1 },
    tax_id    => { type => 'integer', not_null => 1 },
    taxkey_id => { type => 'integer', not_null => 1 },
    pos_ustva => { type => 'integer' },
    startdate => { type => 'date', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'chart_id', 'startdate' ],

  foreign_keys => [
    chart => {
      class       => 'SL::DB::Chart',
      key_columns => { chart_id => 'id' },
    },

    tax => {
      class       => 'SL::DB::Tax',
      key_columns => { tax_id => 'id' },
    },
  ],
);

1;
;
