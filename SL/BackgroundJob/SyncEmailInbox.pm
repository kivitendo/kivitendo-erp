package SL::BackgroundJob::SyncEmailInbox;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::IMAPClient;

sub sync_email_inbox {
  my ($self) = @_;
  my $folder = $self->{job_obj}->data_as_hash->{folder} || 'INBOX';

  my $imap_client = SL::IMAPClient->new();

  $imap_client->update_emails_from_folder($folder);

}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  $self->sync_email_inbox();

  return;
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::SyncEmailInbox - Background job for syncing emails from a folder

=head1 SYNOPSIS

This background job is used to sync emails from a folder. It can be used to sync
emails from a folder on a regular basis for multiple folders. The folder to sync
is specified in the data field 'folder' of the background job, by default the
folder 'INBOX' is used. Sub folders are separated by a forward slash,
e.g. 'INBOX/Archive'. Subfolders are not synced.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
