# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::EmailJournalAttachment;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('email_journal_attachments');

__PACKAGE__->meta->columns(
  content          => { type => 'bytea', not_null => 1 },
  email_journal_id => { type => 'integer', not_null => 1 },
  file_id          => { type => 'integer', default => '0', not_null => 1 },
  id               => { type => 'serial', not_null => 1 },
  itime            => { type => 'timestamp', default => 'now()', not_null => 1 },
  mime_type        => { type => 'text', not_null => 1 },
  mtime            => { type => 'timestamp', default => 'now()', not_null => 1 },
  name             => { type => 'text', not_null => 1 },
  position         => { type => 'integer', not_null => 1 },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  email_journal => {
    class       => 'SL::DB::EmailJournal',
    key_columns => { email_journal_id => 'id' },
  },
);

1;
;
