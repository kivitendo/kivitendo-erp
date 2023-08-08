# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::EmailJournal;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('email_journal');

__PACKAGE__->meta->columns(
  body               => { type => 'text', not_null => 1 },
  email_import_id    => { type => 'integer' },
  extended_status    => { type => 'text', not_null => 1 },
  folder             => { type => 'text' },
  folder_uidvalidity => { type => 'text' },
  from               => { type => 'text', not_null => 1 },
  headers            => { type => 'text', not_null => 1 },
  id                 => { type => 'serial', not_null => 1 },
  itime              => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime              => { type => 'timestamp', default => 'now()', not_null => 1 },
  recipients         => { type => 'text', not_null => 1 },
  sender_id          => { type => 'integer' },
  sent_on            => { type => 'timestamp', default => 'now()', not_null => 1 },
  status             => { type => 'enum', check_in => [ 'sent', 'send_failed', 'imported' ], db_type => 'email_journal_status', not_null => 1 },
  subject            => { type => 'text', not_null => 1 },
  uid                => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  email_import => {
    class       => 'SL::DB::EmailImport',
    key_columns => { email_import_id => 'id' },
  },

  sender => {
    class       => 'SL::DB::Employee',
    key_columns => { sender_id => 'id' },
  },
);

1;
;
