# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DeliveryTerm;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('delivery_terms');

__PACKAGE__->meta->columns(
  description      => { type => 'text' },
  description_long => { type => 'text' },
  id               => { type => 'integer', not_null => 1, sequence => 'id' },
  itime            => { type => 'timestamp', default => 'now()' },
  mtime            => { type => 'timestamp' },
  obsolete         => { type => 'boolean', default => 'false', not_null => 1 },
  sortkey          => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
