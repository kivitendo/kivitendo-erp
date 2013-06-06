# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthClientUser;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'clients_users',
  schema  => 'auth',

  columns => [
    client_id => { type => 'integer', not_null => 1 },
    user_id   => { type => 'integer', not_null => 1 },
  ],

  primary_key_columns => [ 'client_id', 'user_id' ],

  foreign_keys => [
    client => {
      class       => 'SL::DB::AuthClient',
      key_columns => { client_id => 'id' },
    },

    user => {
      class       => 'SL::DB::AuthUser',
      key_columns => { user_id => 'id' },
    },
  ],
);

1;
;
