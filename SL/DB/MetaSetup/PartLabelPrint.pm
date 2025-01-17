# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartLabelPrint;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('part_label_prints');

__PACKAGE__->meta->columns(
  price_history_id => { type => 'integer', not_null => 1 },
  print_type       => { type => 'enum', check_in => [ 'single', 'stock' ], db_type => 'part_label_print_types', not_null => 1 },
  template         => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'price_history_id', 'print_type', 'template' ]);

__PACKAGE__->meta->foreign_keys(
  price_history => {
    class       => 'SL::DB::PartsPriceHistory',
    key_columns => { price_history_id => 'id' },
  },
);

1;
;
