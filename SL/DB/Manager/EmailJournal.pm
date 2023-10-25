package SL::DB::Manager::EmailJournal;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::EmailJournal' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'sent_on', 0 ],
    columns => {
      SIMPLE => 'ALL',
      sender => 'sender.name',
      linked_to => qq{(
        SELECT count(*) from record_links where
          ( record_links.from_table = 'email_journal'::varchar(50)
            AND record_links.from_id = email_journal.id
          ) OR (
            record_links.to_table = 'email_journal'::varchar(50)
            AND record_links.to_id = email_journal.id
          )
      )}
    },
  );
}

1;
