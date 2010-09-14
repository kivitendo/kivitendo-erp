# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::License;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'license',

  columns => [
    id            => { type => 'integer', not_null => 1, sequence => 'id' },
    parts_id      => { type => 'integer' },
    customer_id   => { type => 'integer' },
    comment       => { type => 'text' },
    validuntil    => { type => 'date' },
    issuedate     => { type => 'date', default => 'now' },
    quantity      => { type => 'integer' },
    licensenumber => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
