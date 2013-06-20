# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthUserConfig;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('user_config');
__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->columns(
  user_id   => { type => 'integer', not_null => 1 },
  cfg_key   => { type => 'text', not_null => 1 },
  cfg_value => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'user_id', 'cfg_key' ]);

__PACKAGE__->meta->foreign_keys(
  user => {
    class       => 'SL::DB::AuthUser',
    key_columns => { user_id => 'id' },
  },
);

# __PACKAGE__->meta->initialize;

1;
;
