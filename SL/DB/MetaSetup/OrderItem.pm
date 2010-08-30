# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::OrderItem;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'orderitems',

  columns => [
    trans_id           => { type => 'integer' },
    parts_id           => { type => 'integer' },
    description        => { type => 'text' },
    qty                => { type => 'float', precision => 4 },
    sellprice          => { type => 'numeric', precision => 5, scale => 15 },
    discount           => { type => 'float', precision => 4 },
    project_id         => { type => 'integer' },
    reqdate            => { type => 'date' },
    ship               => { type => 'float', precision => 4 },
    serialnumber       => { type => 'text' },
    id                 => { type => 'integer', not_null => 1, sequence => 'orderitemsid' },
    itime              => { type => 'timestamp', default => 'now()' },
    mtime              => { type => 'timestamp' },
    pricegroup_id      => { type => 'integer' },
    ordnumber          => { type => 'text' },
    transdate          => { type => 'text' },
    cusordnumber       => { type => 'text' },
    unit               => { type => 'varchar', length => 20 },
    base_qty           => { type => 'float', precision => 4 },
    subtotal           => { type => 'boolean', default => 'false' },
    longdescription    => { type => 'text' },
    marge_total        => { type => 'numeric', precision => 5, scale => 15 },
    marge_percent      => { type => 'numeric', precision => 5, scale => 15 },
    lastcost           => { type => 'numeric', precision => 5, scale => 15 },
    price_factor_id    => { type => 'integer' },
    price_factor       => { type => 'numeric', default => 1, precision => 5, scale => 15 },
    marge_price_factor => { type => 'numeric', default => 1, precision => 5, scale => 15 },
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
