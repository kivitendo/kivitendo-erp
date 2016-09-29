# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Pricegroup;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('pricegroup');

__PACKAGE__->meta->columns(
  id         => { type => 'integer', not_null => 1, sequence => 'id' },
  obsolete   => { type => 'boolean', default => 'false' },
  pricegroup => { type => 'text', not_null => 1 },
  sortkey    => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
