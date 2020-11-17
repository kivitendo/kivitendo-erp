# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TimeRecordingType;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('time_recording_types');

__PACKAGE__->meta->columns(
  abbreviation => { type => 'text', not_null => 1 },
  description  => { type => 'text' },
  id           => { type => 'serial', not_null => 1 },
  obsolete     => { type => 'boolean', default => 'false', not_null => 1 },
  position     => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
