# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TriggerInformation;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('trigger_information');

__PACKAGE__->meta->columns(
  id    => { type => 'serial', not_null => 1 },
  key   => { type => 'text', not_null => 1 },
  value => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'key', 'value' ]);

1;
;
