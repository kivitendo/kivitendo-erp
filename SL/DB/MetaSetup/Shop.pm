# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Shop;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('shops');

__PACKAGE__->meta->columns(
  connector               => { type => 'text' },
  description             => { type => 'text' },
  id                      => { type => 'serial', not_null => 1 },
  itime                   => { type => 'timestamp', default => 'now()' },
  last_order_number       => { type => 'integer' },
  login                   => { type => 'text' },
  mtime                   => { type => 'timestamp', default => 'now()' },
  obsolete                => { type => 'boolean', default => 'false', not_null => 1 },
  orders_to_fetch         => { type => 'integer' },
  password                => { type => 'text' },
  path                    => { type => 'text', default => '/', not_null => 1 },
  port                    => { type => 'integer' },
  price_source            => { type => 'text' },
  pricetype               => { type => 'text' },
  protocol                => { type => 'text', default => 'http', not_null => 1 },
  realm                   => { type => 'text' },
  server                  => { type => 'text' },
  sortkey                 => { type => 'integer' },
  taxzone_id              => { type => 'integer' },
  transaction_description => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
