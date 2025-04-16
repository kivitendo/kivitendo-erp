# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TSETransaction;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('tse_transactions');

__PACKAGE__->meta->columns(
  ar_id              => { type => 'integer' },
  client_id          => { type => 'text', not_null => 1 },
  finish_timestamp   => { type => 'timestamp with time zone', not_null => 1 },
  id                 => { type => 'serial', not_null => 1 },
  json               => { type => 'text' },
  pos_id             => { type => 'integer', not_null => 1 },
  pos_serial_number  => { type => 'text', not_null => 1 },
  process_data       => { type => 'text' },
  process_type       => { type => 'text', not_null => 1 },
  sig_counter        => { type => 'text', not_null => 1 },
  signature          => { type => 'text', not_null => 1 },
  start_timestamp    => { type => 'timestamp with time zone', not_null => 1 },
  transaction_number => { type => 'text', not_null => 1 },
  tse_device_id      => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys(
  [ 'ar_id' ],
  [ 'transaction_number', 'tse_device_id' ],
);

__PACKAGE__->meta->foreign_keys(
  ar => {
    class       => 'SL::DB::Invoice',
    key_columns => { ar_id => 'id' },
    rel_type    => 'one to one',
  },

  pos => {
    class       => 'SL::DB::PointOfSale',
    key_columns => { pos_id => 'id' },
  },

  tse_device => {
    class       => 'SL::DB::TSEDevice',
    key_columns => { tse_device_id => 'id' },
  },
);

1;
;
