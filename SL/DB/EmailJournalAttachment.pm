package SL::DB::EmailJournalAttachment;

use strict;

use SL::DB::MetaSetup::EmailJournalAttachment;
use SL::DB::Manager::EmailJournalAttachment;
use SL::DB::Helper::ActsAsList (group_by => [ qw(email_journal_id) ]);

__PACKAGE__->meta->initialize;

1;
