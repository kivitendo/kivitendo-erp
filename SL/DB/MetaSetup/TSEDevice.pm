# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TSEDevice;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('tse_devices');

__PACKAGE__->meta->columns(
  active      => { type => 'boolean', default => 'true', not_null => 1 },
  description => { type => 'text' },
  device_id   => { type => 'text', not_null => 1 },
  id          => { type => 'serial', not_null => 1 },
  serial      => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'device_id' ]);

1;
;
