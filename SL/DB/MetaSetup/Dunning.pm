# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Dunning;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'dunning',

  columns => [
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
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    dunning_config => {
      class       => 'SL::DB::DunningConfig',
      key_columns => { dunning_config_id => 'id' },
    },

    fee_interest_ar => {
      class       => 'SL::DB::Invoice',
      key_columns => { fee_interest_ar_id => 'id' },
    },
  ],
);

1;
;
