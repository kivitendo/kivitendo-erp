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

    my $sub_query = qq{ (
      SELECT from_id
        FROM record_links
        WHERE (from_table = 'email_journal')
      UNION ALL
      SELECT to_id
        FROM record_links
        WHERE (to_table = 'email_journal')
    )};

    return (!!$value ? '' : '!') . ${prefix} . 'id' => [ \$sub_query ];
  },
  unprocessed_attachment_names => sub {
    my ($key, $value, $prefix) = @_;
    return (
      and => [
        'attachments.name' => $value,
        'attachments.processed' => 0,
      ],
      'attachments'
    )
  },
  has_unprocessed_attachments => sub {
    my ($key, $value, $prefix) = @_;

    my $sub_query = q{(
      SELECT email_journal_id
        FROM email_journal_attachments
        WHERE processed = FALSE
    )};

    return (!!$value ? '' : '!') . ${prefix} . 'id' => [ \$sub_query ];
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
      )},
      attachment_names => qq{(
        SELECT STRING_AGG(
          email_journal_attachments.name,
          ', '
          ORDER BY email_journal_attachments.position ASC
       )
        FROM email_journal_attachments
        WHERE
          email_journal_attachments.email_journal_id = email_journal.id
      )},
      unprocessed_attachment_names => qq{(
        SELECT STRING_AGG(
          email_journal_attachments.name,
          ', '
          ORDER BY email_journal_attachments.position ASC
       )
        FROM email_journal_attachments
        WHERE
          email_journal_attachments.email_journal_id = email_journal.id
            AND email_journal_attachments.processed = FALSE
      )},
      has_unprocessed_attachments => qq{(
        SELECT count(*)
        FROM email_journal_attachments
        WHERE
          email_journal_attachments.email_journal_id = email_journal.id
            AND email_journal_attachments.processed = FALSE
      )},
    },
  );
}

1;
