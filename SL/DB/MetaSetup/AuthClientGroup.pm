# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthClientGroup;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('clients_groups');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  client_id => { type => 'integer', not_null => 1 },
  group_id  => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'client_id', 'group_id' ]);

__PACKAGE__->meta->foreign_keys(
  client => {
    class       => 'SL::DB::AuthClient',
    key_columns => { client_id => 'id' },
  },

  group => {
    class       => 'SL::DB::AuthGroup',
    key_columns => { group_id => 'id' },
  },
);

1;
;
