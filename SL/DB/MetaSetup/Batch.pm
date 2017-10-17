# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Batch;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('batches');

__PACKAGE__->meta->columns(
  batchdate          => { type => 'date', not_null => 1, default => 'now()' },
  batchnumber        => { type => 'text', not_null => 1 },
  deleted            => { type => 'boolean', not_null => 1, default => 'false' },
  employee_id        => { type => 'integer' },
  id                 => { type => 'integer', not_null => 1, sequence => 'id' },
  itime              => { type => 'timestamp', not_null => 1, default => 'now()' },
  location           => { type => 'text' },
  mtime              => { type => 'timestamp' },
  notes              => { type => 'text' },
  part_id            => { type => 'integer', not_null => 1 },
  process            => { type => 'text' },
  producer_id        => { type => 'integer', not_null => 1  },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->add_unique_key( Rose::DB::Object::Metadata::UniqueKey->new(
  columns => [ 'producer_id', 'part_id', 'batchnumber' ]
));

__PACKAGE__->meta->add_unique_key( Rose::DB::Object::Metadata::UniqueKey->new(
  columns => [ 'producer_id', 'part_id', 'batchdate', 'location', 'process' ]
));

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
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
