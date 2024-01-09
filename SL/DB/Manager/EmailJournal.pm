package SL::DB::Manager::EmailJournal;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

sub object_class { 'SL::DB::EmailJournal' }

__PACKAGE__->make_manager_methods;

__PACKAGE__->add_filter_specs(
  linked_to => sub {
    my ($key, $value, $prefix) = @_;

    # if $value is truish, we want at least one link otherwise we want none
    my $comp = !!$value ? '>' : '=';

    # table emial_journal is aliased as t1
    return
      \qq{(
        SELECT CASE WHEN count(*) $comp 0 THEN TRUE ELSE FALSE END
        FROM record_links
        WHERE (
            (record_links.from_table = 'email_journal'::varchar(50))
            AND record_links.from_id = t1.id
          ) OR (
            (record_links.to_table = 'email_journal'::varchar(50))
            AND record_links.to_id = t1.id
          )
        )} => \'TRUE';
  },
);

sub _sort_spec {
  return (
    default => [ 'sent_on', 0 ],
    columns => {
      SIMPLE => 'ALL',
      sender => 'sender.name',
      linked_to => qq{(
        SELECT count(*)
        FROM record_links
        WHERE
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
