# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::ECterminal;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('ec_terminals');

__PACKAGE__->meta->columns(
  id                => { type => 'serial', not_null => 1 },
  ip_address        => { type => 'text', not_null => 1 },
  name              => { type => 'text', not_null => 1 },
  transfer_chart_id => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  transfer_chart => {
    class       => 'SL::DB::Chart',
    key_columns => { transfer_chart_id => 'id' },
  },
);

1;
;
