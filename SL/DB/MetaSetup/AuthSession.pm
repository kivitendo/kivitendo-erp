# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthSession;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('session');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  api_token  => { type => 'text' },
  id         => { type => 'text', not_null => 1 },
  ip_address => { type => 'scalar' },
  mtime      => { type => 'timestamp' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
