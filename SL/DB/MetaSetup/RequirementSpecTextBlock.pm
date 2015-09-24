# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::RequirementSpecTextBlock;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('requirement_spec_text_blocks');

__PACKAGE__->meta->columns(
  id                  => { type => 'serial', not_null => 1 },
  is_flagged          => { type => 'boolean', default => 'false', not_null => 1 },
  itime               => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime               => { type => 'timestamp' },
  output_position     => { type => 'integer', default => 1, not_null => 1 },
  position            => { type => 'integer', not_null => 1 },
  requirement_spec_id => { type => 'integer', not_null => 1 },
  text                => { type => 'text' },
  title               => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  requirement_spec => {
    class       => 'SL::DB::RequirementSpec',
    key_columns => { requirement_spec_id => 'id' },
  },
);

1;
;
