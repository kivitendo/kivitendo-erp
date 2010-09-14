# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TaxZone;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'tax_zones',

  columns => [
    id          => { type => 'integer', not_null => 1 },
    description => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
