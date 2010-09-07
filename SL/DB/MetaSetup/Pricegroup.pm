# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Pricegroup;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'pricegroup',

  columns => [
    id         => { type => 'integer', not_null => 1, sequence => 'id' },
    pricegroup => { type => 'text', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
