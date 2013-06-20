# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TaxZone;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('tax_zones');

__PACKAGE__->meta->columns(
  id          => { type => 'integer', not_null => 1 },
  description => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

# __PACKAGE__->meta->initialize;

1;
;
