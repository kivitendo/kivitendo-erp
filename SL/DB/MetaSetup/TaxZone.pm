# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TaxZone;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('tax_zones');

__PACKAGE__->meta->columns(
  description => { type => 'text' },
  id          => { type => 'integer', not_null => 1, sequence => 'id' },
  obsolete    => { type => 'boolean', default => 'false' },
  sortkey     => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
