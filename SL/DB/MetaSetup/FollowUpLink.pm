# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::FollowUpLink;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'follow_up_links',

  columns => [
    id           => { type => 'integer', not_null => 1, sequence => 'follow_up_link_id' },
    follow_up_id => { type => 'integer', not_null => 1 },
    trans_id     => { type => 'integer', not_null => 1 },
    trans_type   => { type => 'text', not_null => 1 },
    trans_info   => { type => 'text' },
    itime        => { type => 'timestamp', default => 'now()' },
    mtime        => { type => 'timestamp' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,

  foreign_keys => [
    follow_up => {
      class       => 'SL::DB::FollowUp',
      key_columns => { follow_up_id => 'id' },
    },
  ],
);

1;
;
