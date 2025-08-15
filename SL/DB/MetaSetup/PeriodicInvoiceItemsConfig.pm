# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PeriodicInvoiceItemsConfig;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('periodic_invoice_items_configs');

__PACKAGE__->meta->columns(
  end_date                => { type => 'date' },
  extend_automatically_by => { type => 'integer' },
  once_invoice_id         => { type => 'integer' },
  order_item_id           => { type => 'integer', not_null => 1 },
  periodicity             => { type => 'varchar', length => 10, not_null => 1 },
  start_date              => { type => 'date' },
  terminated              => { type => 'boolean' },
);

__PACKAGE__->meta->primary_key_columns([ 'order_item_id' ]);

__PACKAGE__->meta->foreign_keys(
  once_invoice => {
    class       => 'SL::DB::Invoice',
    key_columns => { once_invoice_id => 'id' },
  },

  order_item => {
    class       => 'SL::DB::OrderItem',
    key_columns => { order_item_id => 'id' },
    rel_type    => 'one to one',
  },
);

1;
;
