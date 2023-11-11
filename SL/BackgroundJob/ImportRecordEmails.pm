package SL::BackgroundJob::ImportRecordEmails;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::IMAPClient;
use SL::DB::Manager::EmailImport;
use SL::Helper::EmailProcessing;
use SL::Presenter::Tag qw(link_tag);
use SL::Presenter::EscapedText qw(escape);

sub sync_record_email_folder {
  my ($self, $imap_client, $record_type, $folder) = @_;

  my $email_import = $imap_client->update_emails_from_folder(
    $folder,
    {
      email_journal => {
        status => 'imported',
        record_type => $record_type,
      },
    }
  );

  return $email_import;
}

sub delete_email_imports {
  my ($self) = @_;
  my $job_obj = $self->{job_obj};

  my $email_import_ids_to_delete =
    $job_obj->data_as_hash->{email_import_ids_to_delete} || [];

  my @deleted_email_imports_ids;
  foreach my $email_import_id (@$email_import_ids_to_delete) {
    my $email_import = SL::DB::Manager::EmailImport->find_by(id => $email_import_id);
    next unless $email_import;
    $email_import->delete(cascade => 1);
    push @deleted_email_imports_ids, $email_import_id;
  }
  return unless @deleted_email_imports_ids;

  return "Deleted email import(s): " . join(', ', @deleted_email_imports_ids) . ".\n";
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  my $data = $job_obj->data_as_hash;

  my %configs = map { $_ => {
      %{$data->{records}->{$_}},
      config => $::lx_office_conf{"record_emails_imap/record/$_"}
        || $::lx_office_conf{record_emails_imap}
        || {},
    } } keys %{$data->{records}};

  my @results = ();
  push @results, $self->delete_email_imports();

  foreach my $import_key (keys %configs) {
    my @record_results = ();
    my $record_config = $configs{$import_key};
    my $imap_client = SL::IMAPClient->new(%{$record_config->{config}});
    my $record_folder = $record_config->{folder};

    my $email_import = $self->sync_record_email_folder(
      $imap_client, $import_key, $record_folder,
    );

    unless ($email_import) {
      push @results, "$import_key No emails to import";
      next;
    }
    push @record_results, "Created email import with id " . $email_import->id;

    if ($record_config->{process_imported_emails}) {
      my @function_names =
        ref $record_config->{process_imported_emails} eq 'ARRAY' ?
            @{$record_config->{process_imported_emails}}
          : ($record_config->{process_imported_emails});
      foreach my $email_journal (@{$email_import->email_journals}) {
        my $created_records = 0;
        foreach my $function_name (@function_names) {
          eval {
            my $processed = SL::Helper::EmailProcessing->process_attachments($function_name, $email_journal);
            $created_records += $processed;
            1;
          } or do {
            # TODO: link not shown as link
            my $email_journal_link = link_tag(
              $ENV{HTTP_ORIGIN} . $ENV{REQUEST_URI}
              . '?action=EmailJournal/show'
              . '&id=' . escape($email_journal->id)
              # text
              , $email_journal->id
            );
            push @record_results, "Error while processing email journal $email_journal_link attachments with $function_name: $@";
          };
        }
        if ($created_records) {
          $imap_client->set_flag_for_email(
            $email_journal, $record_config->{processed_imap_flag});
        } else {
          $imap_client->set_flag_for_email(
            $email_journal, $record_config->{not_processed_imap_flag});
        }

      }
      push @record_results, "Processed attachments with " . join(', ', @function_names) . ".";
    }

    push @results, join("\n- ", "$import_key :", @record_results);
  }

  return join("\n", grep { $_ ne ''} @results);
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::ImportPurchaseInvoiceEmails - Background job for syncing
emails from a folder for records.

=head1 SYNOPSIS

This background job syncs emails from a folder for records. The emails are
imported as email journals and can be processed with functions from
SL::Helper::EmailProcessing.

=head1 CONFIGURATION

In kivitendo.conf the settings for the IMAP server must be specified. The
default config is under [record_emails_imap]. The config for a specific record
type is under [record_emails_imap/record/<record_type>]. The config for a
specific record type overrides the default config.

In the data field 'records' of the background job, the record types to sync
emails for are specified. The key is the record type, the value is a hashref.
The hashref contains the following keys:

=over 4

=item folder

The folder to sync emails from. Sub folders are separated by a forward slash,
e.g. 'INBOX/Archive'. Subfolders are not synced.

=item process_imported_emails

The function name(s) to process the imported emails with. Multiple function
names can be specified as an arrayref. The function names are passed to
SL::Helper::EmailProcessing->process_attachments. The function names must be
implemented in SL::Helper::EmailProcessing.

=item processed_imap_flag

The IMAP flag to set for emails that were processed successfully.

=item not_processed_imap_flag

The IMAP flag to set for emails that were not processed successfully.

=back

=head1 METHODS



=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
