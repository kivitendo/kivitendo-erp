# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Country;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('countries');

__PACKAGE__->meta->columns(
  description => { type => 'text' },
  id          => { type => 'serial', not_null => 1 },
  iso2        => { type => 'text' },
  sortorder   => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys(
  [ 'description' ],
  [ 'iso2' ],
);

1;
;
