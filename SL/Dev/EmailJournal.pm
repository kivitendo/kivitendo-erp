package SL::Dev::EmailJournal;

use strict;
use base qw(Exporter);

our @EXPORT_OK = qw(
  create_email_journal
  create_attachment
);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;

sub create_email_journal {
  my (%params) = @_;

  my $email_journal = SL::DB::EmailJournal->new(
    body               => 'Test Email',
    extended_status    => '',
    folder             => 'INBOX',
    folder_uidvalidity => 1,
    uid                => 1,
    from               => 'FOO BAR <foo@bar.baz>',
    recipients         => 'me@me.me',
    subject            => 'Test',
    record_type        => 'sales_order',
    status             => 'imported',
    headers            => 'None',
    %params
  );

  return $email_journal;
}

sub create_attachment {
  my ($email_journal, %params) = @_;

  my $attachment = SL::DB::EmailJournalAttachment->new(
    email_journal_id => $email_journal->id,
    content          => 'FooBar',
    mime_type        => 'text/plain',
    name             => 'foo.txt',
    position         => 1,
    processed        => 0,
    %params
  );

  return $attachment;
}
