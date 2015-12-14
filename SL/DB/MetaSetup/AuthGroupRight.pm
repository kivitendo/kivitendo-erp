# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthGroupRight;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('group_rights');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  granted  => { type => 'boolean', not_null => 1 },
  group_id => { type => 'integer', not_null => 1 },
  right    => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'group_id', 'right' ]);

__PACKAGE__->meta->foreign_keys(
  group => {
    class       => 'SL::DB::AuthGroup',
    key_columns => { group_id => 'id' },
  },
);

1;
;
