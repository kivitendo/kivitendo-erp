package SL::DB::EmailImport;

use strict;

use SL::DB::MetaSetup::EmailImport;
use SL::DB::Manager::EmailImport;

__PACKAGE__->meta->add_relationship(
  email_journals => {
    type      => 'one to many',
    class     => 'SL::DB::EmailJournal',
    column_map => { id => 'email_import_id' },
  },
);

__PACKAGE__->meta->initialize;

1;
