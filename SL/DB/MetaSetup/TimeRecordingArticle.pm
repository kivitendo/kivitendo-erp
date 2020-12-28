# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TimeRecordingArticle;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('time_recording_articles');

__PACKAGE__->meta->columns(
  id       => { type => 'serial', not_null => 1 },
  part_id  => { type => 'integer', not_null => 1 },
  position => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->unique_keys([ 'part_id' ]);

__PACKAGE__->meta->foreign_keys(
  part => {
    class       => 'SL::DB::Part',
    key_columns => { part_id => 'id' },
    rel_type    => 'one to one',
  },
);

1;
;
