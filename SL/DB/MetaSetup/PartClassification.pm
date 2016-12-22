# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PartClassification;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('part_classifications');

__PACKAGE__->meta->columns(
  abbreviation      => { type => 'text' },
  description       => { type => 'text' },
  id                => { type => 'serial', not_null => 1 },
  report_separate   => { type => 'boolean', default => 'false' },
  used_for_purchase => { type => 'boolean', default => 'true' },
  used_for_sale     => { type => 'boolean', default => 'true' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
