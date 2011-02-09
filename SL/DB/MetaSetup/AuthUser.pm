# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthUser;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'user',

  columns => [
    id       => { type => 'serial', not_null => 1 },
    login    => { type => 'text', not_null => 1 },
    password => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  unique_key => [ 'login' ],
);

1;
;
