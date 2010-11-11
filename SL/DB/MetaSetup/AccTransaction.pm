# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AccTransaction;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'acc_trans',

  columns => [
    acc_trans_id   => { type => 'bigint', not_null => 1, sequence => 'acc_trans_id_seq' },
    trans_id       => { type => 'integer', not_null => 1 },
    chart_id       => { type => 'integer', not_null => 1 },
    amount         => { type => 'numeric', precision => 5, scale => 15 },
    transdate      => { type => 'date', default => 'now' },
    gldate         => { type => 'date', default => 'now' },
    source         => { type => 'text' },
    cleared        => { type => 'boolean', default => 'false' },
    fx_transaction => { type => 'boolean', default => 'false' },
    ob_transaction => { type => 'boolean', default => 'false' },
    cb_transaction => { type => 'boolean', default => 'false' },
    project_id     => { type => 'integer' },
    memo           => { type => 'text' },
    taxkey         => { type => 'integer' },
    itime          => { type => 'timestamp', default => 'now()' },
    mtime          => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'acc_trans_id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    chart => {
      class       => 'SL::DB::Chart',
      key_columns => { chart_id => 'id' },
    },

    project => {
      class       => 'SL::DB::Project',
      key_columns => { project_id => 'id' },
    },
  ],
);

1;
;
