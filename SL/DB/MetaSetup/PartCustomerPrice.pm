# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartCustomerPrice;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('part_customer_prices');

__PACKAGE__->meta->columns(
  customer_id         => { type => 'integer', not_null => 1 },
  customer_partnumber => { type => 'text', default => '' },
  id                  => { type => 'serial', not_null => 1 },
  lastupdate          => { type => 'date', default => 'now()' },
  parts_id            => { type => 'integer', not_null => 1 },
  price               => { type => 'numeric', default => '0', precision => 15, scale => 5 },
  sortorder           => { type => 'integer', default => '0' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  customer => {
    class       => 'SL::DB::Customer',
    key_columns => { customer_id => 'id' },
  },

  parts => {
    class       => 'SL::DB::Part',
    key_columns => { parts_id => 'id' },
  },
);

1;
;
