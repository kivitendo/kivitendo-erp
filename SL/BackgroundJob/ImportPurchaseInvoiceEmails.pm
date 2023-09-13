package SL::BackgroundJob::ImportPurchaseInvoiceEmails;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::IMAPClient;
use SL::DB::Manager::EmailImport;

sub sync_email_folder {
  my ($self) = @_;

  my $email_import = $self->{imap_client}->update_emails_from_folder(
    $self->{folder},
    {
      email_journal => {
        extended_status => 'purchase_invoice_import',
      },
    }
  );
  $self->{email_import} = $email_import;
  return unless $email_import;

  return "Created email import: " . $email_import->id;
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

  return "Deleted email import(s): " . join(', ', @deleted_email_imports_ids);
}

sub clean_up_imported_emails {
  my ($self) = @_;

  $self->{imap_client}->clean_up_imported_emails_from_folder($self->{folder});

  return "Cleaned imported emails";
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;
  $self->{imap_client} = SL::IMAPClient->new(%{$::lx_office_conf{purchase_invoice_emails_imap}});
  $self->{folder} = $self->{job_obj}->data_as_hash->{folder};

  my @results;
  push @results, $self->delete_email_imports();
  push @results, $self->sync_email_folder();
  if ($self->{job_obj}->data_as_hash->{clean_up_imported_emails}) {
    push @results, $self->clean_up_imported_emails();
  }

  return join(". ", grep { $_ ne ''} @results);
}

1;

__END__

=encoding utf8

=head1 NAME

SL::BackgroundJob::ImportPurchaseInvoiceEmails - Background job for syncing
emails from a folder for purchase invoices .

=head1 SYNOPSIS

This background job is used to sync emails from a folder with purchase invoices.
It can be used to sync emails from a folder on a regular basis for multiple
folders . The folder to sync is specified in the data field 'folder' of the
background job, by default the folder 'base_folder' from
[purchase_invoice_emails_imap] in kivitendo.conf is used. Sub folders are
separated by a forward slash, e.g. 'INBOX/Archive'. Subfolders are not synced.
It can also remove emails from the folder which have been imported into kivitendo
by setting the data field 'clean_up_imported_emails' to a true value.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
