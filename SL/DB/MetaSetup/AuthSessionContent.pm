# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthSessionContent;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('session_content');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  auto_restore => { type => 'boolean' },
  sess_key     => { type => 'text', not_null => 1 },
  sess_value   => { type => 'text' },
  session_id   => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'session_id', 'sess_key' ]);

__PACKAGE__->meta->foreign_keys(
  session => {
    class       => 'SL::DB::AuthSession',
    key_columns => { session_id => 'id' },
  },
);

1;
;
