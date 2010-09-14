# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TaxKey;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'taxkeys',

  columns => [
    id        => { type => 'integer', not_null => 1, sequence => 'id' },
    chart_id  => { type => 'integer' },
    tax_id    => { type => 'integer' },
    taxkey_id => { type => 'integer' },
    pos_ustva => { type => 'integer' },
    startdate => { type => 'date' },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    tax => {
      class       => 'SL::DB::Tax',
      key_columns => { tax_id => 'id' },
    },
  ],
);

1;
;
