# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::AsyncEvent;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('async_events');

__PACKAGE__->meta->columns(
  body          => { type => 'text' },
  id            => { type => 'serial', not_null => 1 },
  itime         => { type => 'timestamp', default => 'now()', not_null => 1 },
  msg_type      => { type => 'text', default => 'call', not_null => 1 },
  mtime         => { type => 'timestamp', default => 'now()', not_null => 1 },
  redact_msg_id => { type => 'integer' },
  subject       => { type => 'text' },
  user_id       => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

1;
;
