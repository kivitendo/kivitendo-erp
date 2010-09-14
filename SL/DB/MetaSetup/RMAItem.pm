# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RMAItem;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'rmaitems',

  columns => [
    trans_id      => { type => 'integer' },
    parts_id      => { type => 'integer' },
    description   => { type => 'text' },
    qty           => { type => 'float', precision => 4 },
    base_qty      => { type => 'float', precision => 4 },
    sellprice     => { type => 'numeric', precision => 5, scale => 15 },
    discount      => { type => 'float', precision => 4 },
    project_id    => { type => 'integer' },
    reqdate       => { type => 'date' },
    ship          => { type => 'float', precision => 4 },
    serialnumber  => { type => 'text' },
    id            => { type => 'integer', not_null => 1, sequence => 'orderitemsid' },
    itime         => { type => 'timestamp', default => 'now()' },
    mtime         => { type => 'timestamp' },
    pricegroup_id => { type => 'integer' },
    rmanumber     => { type => 'text' },
    transdate     => { type => 'text' },
    cusrmanumber  => { type => 'text' },
    unit          => { type => 'varchar', length => 20 },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    parts => {
      class       => 'SL::DB::Part',
      key_columns => { parts_id => 'id' },
    },
  ],
);

1;
;
