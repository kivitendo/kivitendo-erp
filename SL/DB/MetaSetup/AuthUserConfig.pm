# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthUserConfig;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'user_config',

  columns => [
    user_id   => { type => 'integer', not_null => 1 },
    cfg_key   => { type => 'text', not_null => 1 },
    cfg_value => { type => 'text' },
  ],

  primary_key_columns => [ 'user_id', 'cfg_key' ],
);

1;
;
