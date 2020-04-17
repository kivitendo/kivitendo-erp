# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Greeting;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('greetings');

__PACKAGE__->meta->columns(
  description => { type => 'text', not_null => 1 },
  id          => { type => 'serial', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'description' ]);

1;
;
