# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Piece;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('pieces');

__PACKAGE__->meta->columns(
  batch_id           => { type => 'integer' },
  bin_id             => { type => 'integer' },
  deleted            => { type => 'boolean', not_null => 1, default => 'false' },
  delivery_in_id     => { type => 'integer' },
  delivery_out_id    => { type => 'integer' },
  employee_id        => { type => 'integer' },
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  itime              => { type => 'timestamp', not_null => 1, default => 'now()' },
  mtime              => { type => 'timestamp' },
  notes              => { type => 'text' },
  serialnumber       => { type => 'text', not_null => 1 },
  part_id            => { type => 'integer', not_null => 1 },
  producer_id        => { type => 'integer', not_null => 1 },
  weight             => { type => 'numeric', precision => 15, scale => 5 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->add_unique_key( Rose::DB::Object::Metadata::UniqueKey->new(
  columns => [ 'producer_id', 'part_id', 'batch_id', 'serialnumber' ]
));

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  bin           => {
    class       => 'SL::DB::Bin',
    key_columns => { bin_id => 'id' },
  },
  batch         => {
    class       => 'SL::DB::Batch',
    key_columns => { batch_id => 'id' },
  },
  delivery_in => {
    class       => 'SL::DB::DeliveryOrder',
    key_columns => { delivery_in_id => 'id' },
  },
  delivery_out => {
    class       => 'SL::DB::DeliveryOrder',
    key_columns => { delivery_out_id => 'id' },
  },
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },
  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
  },
  producer => {
    class       => 'SL::DB::Vendor',
    key_columns => { producer_id => 'id' },
  },
);

1;
;
