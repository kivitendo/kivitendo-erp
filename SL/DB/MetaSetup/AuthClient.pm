# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthClient;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('clients');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  id         => { type => 'serial', not_null => 1 },
  name       => { type => 'text', not_null => 1 },
  dbhost     => { type => 'text', not_null => 1 },
  dbport     => { type => 'integer', default => 5432, not_null => 1 },
  dbname     => { type => 'text', not_null => 1 },
  dbuser     => { type => 'text', not_null => 1 },
  dbpasswd   => { type => 'text', not_null => 1 },
  is_default => { type => 'boolean', default => 'false', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys(
  [ 'dbhost', 'dbport', 'dbname' ],
  [ 'name' ],
);

# __PACKAGE__->meta->initialize;

1;
;
