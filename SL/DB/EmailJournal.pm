package SL::DB::EmailJournal;

use strict;

use SL::DB::MetaSetup::EmailJournal;
use SL::DB::Manager::EmailJournal;
use SL::DB::Helper::AttrSorted;

__PACKAGE__->meta->add_relationship(
  attachments  => {
    type       => 'one to many',
    class      => 'SL::DB::EmailJournalAttachment',
    column_map => { id => 'email_journal_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_sorted('attachments');

1;
