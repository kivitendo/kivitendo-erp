# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecVersion;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('requirement_spec_versions');

__PACKAGE__->meta->columns(
  comment        => { type => 'text' },
  description    => { type => 'text', not_null => 1 },
  id             => { type => 'serial', not_null => 1 },
  itime          => { type => 'timestamp', default => 'now()' },
  mtime          => { type => 'timestamp' },
  order_date     => { type => 'date' },
  order_id       => { type => 'integer' },
  order_number   => { type => 'text' },
  version_number => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  order => {
    class       => 'SL::DB::Order',
    key_columns => { order_id => 'id' },
  },
);

1;
;
