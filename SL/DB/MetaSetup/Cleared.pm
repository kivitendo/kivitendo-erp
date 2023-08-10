# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Cleared;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('cleared');

__PACKAGE__->meta->columns(
  acc_trans_id     => { type => 'bigint', not_null => 1 },
  cleared_group_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'cleared_group_id', 'acc_trans_id' ]);

__PACKAGE__->meta->unique_keys(
  [ 'acc_trans_id' ],
  [ 'acc_trans_id', 'cleared_group_id' ],
);

__PACKAGE__->meta->foreign_keys(
  acc_transaction => {
    class       => 'SL::DB::AccTransaction',
    key_columns => { acc_trans_id => 'acc_trans_id' },
    rel_type    => 'one to one',
  },

  cleared_group => {
    class       => 'SL::DB::ClearedGroup',
    key_columns => { cleared_group_id => 'id' },
  },
);

1;
;
