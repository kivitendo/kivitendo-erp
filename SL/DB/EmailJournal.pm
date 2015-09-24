package SL::DB::EmailJournal;

use strict;

use SL::DB::MetaSetup::EmailJournal;
use SL::DB::Manager::EmailJournal;

__PACKAGE__->meta->add_relationship(
  attachments  => {
    type       => 'one to many',
    class      => 'SL::DB::EmailJournalAttachment',
    column_map => { id => 'email_journal_id' },
  },
);

__PACKAGE__->meta->initialize;

1;
