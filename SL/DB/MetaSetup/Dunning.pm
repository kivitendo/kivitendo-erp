# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Dunning;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('dunning');

__PACKAGE__->meta->columns(
  duedate            => { type => 'date' },
  dunning_config_id  => { type => 'integer' },
  dunning_id         => { type => 'integer' },
  dunning_level      => { type => 'integer' },
  fee                => { type => 'numeric', precision => 15, scale => 5 },
  fee_interest_ar_id => { type => 'integer' },
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  interest           => { type => 'numeric', precision => 15, scale => 5 },
  itime              => { type => 'timestamp', default => 'now()' },
  mtime              => { type => 'timestamp' },
  trans_id           => { type => 'integer' },
  transdate          => { type => 'date' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  dunning_config => {
    class       => 'SL::DB::DunningConfig',
    key_columns => { dunning_config_id => 'id' },
  },

  fee_interest_invoice => {
    class       => 'SL::DB::Invoice',
    key_columns => { fee_interest_ar_id => 'id' },
  },

  invoice => {
    class       => 'SL::DB::Invoice',
    key_columns => { trans_id => 'id' },
  },
);

1;
;
