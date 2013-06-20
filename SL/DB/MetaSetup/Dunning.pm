# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Dunning;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('dunning');

__PACKAGE__->meta->columns(
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  trans_id           => { type => 'integer' },
  dunning_id         => { type => 'integer' },
  dunning_level      => { type => 'integer' },
  transdate          => { type => 'date' },
  duedate            => { type => 'date' },
  fee                => { type => 'numeric', precision => 5, scale => 15 },
  interest           => { type => 'numeric', precision => 5, scale => 15 },
  dunning_config_id  => { type => 'integer' },
  itime              => { type => 'timestamp', default => 'now()' },
  mtime              => { type => 'timestamp' },
  fee_interest_ar_id => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  fee_interest_ar => {
    class       => 'SL::DB::Invoice',
    key_columns => { fee_interest_ar_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
