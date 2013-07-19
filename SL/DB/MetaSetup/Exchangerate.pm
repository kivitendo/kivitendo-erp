# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Exchangerate;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->table('exchangerate');

__PACKAGE__->meta->columns(
  buy         => { type => 'numeric', precision => 5, scale => 15 },
  currency_id => { type => 'integer', not_null => 1 },
  id          => { type => 'serial', not_null => 1 },
  itime       => { type => 'timestamp', default => 'now()' },
  mtime       => { type => 'timestamp' },
  sell        => { type => 'numeric', precision => 5, scale => 15 },
  transdate   => { type => 'date' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  currency => {
    class       => 'SL::DB::Currency',
    key_columns => { currency_id => 'id' },
  },
);

1;
;
