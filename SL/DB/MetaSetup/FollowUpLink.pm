# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUpLink;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('follow_up_links');

__PACKAGE__->meta->columns(
  follow_up_id => { type => 'integer', not_null => 1 },
  id           => { type => 'integer', not_null => 1, sequence => 'follow_up_link_id' },
  itime        => { type => 'timestamp', default => 'now()' },
  mtime        => { type => 'timestamp' },
  trans_id     => { type => 'integer', not_null => 1 },
  trans_info   => { type => 'text' },
  trans_type   => { type => 'text', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  follow_up => {
    class       => 'SL::DB::FollowUp',
    key_columns => { follow_up_id => 'id' },
  },
);

1;
;
