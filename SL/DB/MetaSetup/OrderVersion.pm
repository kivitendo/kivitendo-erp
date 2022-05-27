# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::OrderVersion;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('oe_version');

__PACKAGE__->meta->columns(
  email_journal_id => { type => 'integer' },
  file_id          => { type => 'integer' },
  final_version    => { type => 'boolean', default => 'false' },
  itime            => { type => 'timestamp', default => 'now()' },
  mtime            => { type => 'timestamp' },
  oe_id            => { type => 'integer', not_null => 1 },
  version          => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'oe_id', 'version' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  email_journal => {
    class       => 'SL::DB::EmailJournal',
    key_columns => { email_journal_id => 'id' },
  },

  file => {
    class       => 'SL::DB::File',
    key_columns => { file_id => 'id' },
  },

  oe => {
    class       => 'SL::DB::Order',
    key_columns => { oe_id => 'id' },
  },
);

1;
;
