# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PointOfSale;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('points_of_sale');

__PACKAGE__->meta->columns(
  cash_chart_id             => { type => 'integer', not_null => 1 },
  delivery_order_copies     => { type => 'integer', not_null => 1 },
  delivery_order_printer_id => { type => 'integer', not_null => 1 },
  delivery_order_template   => { type => 'text', not_null => 1 },
  ec_terminal_id            => { type => 'integer', not_null => 1 },
  id                        => { type => 'serial', not_null => 1 },
  invoice_copies            => { type => 'integer', not_null => 1 },
  invoice_printer_id        => { type => 'integer', not_null => 1 },
  invoice_template          => { type => 'text', not_null => 1 },
  name                      => { type => 'text', not_null => 1 },
  project_id                => { type => 'integer', not_null => 1 },
  receipt_printer_id        => { type => 'integer', not_null => 1 },
  serial_number             => { type => 'text', not_null => 1 },
  tse_terminal_id           => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  cash_chart => {
    class       => 'SL::DB::Chart',
    key_columns => { cash_chart_id => 'id' },
  },

  delivery_order_printer => {
    class       => 'SL::DB::Printer',
    key_columns => { delivery_order_printer_id => 'id' },
  },

  ec_terminal => {
    class       => 'SL::DB::ECterminal',
    key_columns => { ec_terminal_id => 'id' },
  },

  invoice_printer => {
    class       => 'SL::DB::Printer',
    key_columns => { invoice_printer_id => 'id' },
  },

  project => {
    class       => 'SL::DB::Project',
    key_columns => { project_id => 'id' },
  },
);

1;
;
