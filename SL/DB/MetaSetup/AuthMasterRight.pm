# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthMasterRight;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('master_rights');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  category    => { type => 'boolean', default => 'false', not_null => 1 },
  description => { type => 'text', not_null => 1 },
  id          => { type => 'serial', not_null => 1 },
  name        => { type => 'text', not_null => 1 },
  position    => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'name' ]);

1;
;
