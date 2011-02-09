# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AuthGroupRight;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'group_rights',

  columns => [
    group_id => { type => 'integer', not_null => 1 },
    right    => { type => 'text', not_null => 1 },
    granted  => { type => 'boolean', not_null => 1 },
  ],

  primary_key_columns => [ 'group_id', 'right' ],
);

1;
;
