package SL::BackgroundJob::ImportRecordEmails;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::IMAPClient;
use SL::DB::EmailJournal;
use SL::DB::Manager::EmailImport;
use SL::Helper::EmailProcessing;
use SL::Presenter::Tag qw(link_tag);
use SL::Locale::String qw(t8);

use List::MoreUtils qw(any);
use Params::Validate qw(:all);
use Try::Tiny;

sub sync_record_email_folder {
  my ($self, $config) = @_;

  my %imap_config;
  foreach my $key (qw(enabled hostname port ssl username password)) {
    if (defined $config->{$key}) {
      $imap_config{$key} = $config->{$key};
    }
  }

  my $imap_client = SL::IMAPClient->new(%imap_config);

  my $email_import = $imap_client->update_emails_from_folder(
    folder => $config->{folder},
    email_journal_params => {
      record_type => $config->{record_type},
    }
  );
  return "No emails to import." unless $email_import;

  my $result = "Created email import with id " . $email_import->id . ".";

  if ($config->{process_imported_emails}) {
    my @function_names =
      ref $config->{process_imported_emails} eq 'ARRAY' ?
          @{$config->{process_imported_emails}}
        : ($config->{process_imported_emails});
    foreach my $email_journal (@{$email_import->email_journals}) {
      my $created_records = 0;
      foreach my $function_name (@function_names) {
        eval {
          my $processed = SL::Helper::EmailProcessing->process_attachments($function_name, $email_journal);
          $created_records += $processed;
          1;
        } or do {
          # # TODO: link not shown as link
          # my $email_journal_link = link_tag(
          #   $ENV{HTTP_ORIGIN} . $ENV{REQUEST_URI}
          #   . '?action=EmailJournal/show'
          #   . '&id=' . $email_journal->id
          #   # text
          #   , $email_journal->id
          # );
          my $email_journal_id = $email_journal->id;
          $result .= t8("Error while processing email journal ('#1') attachments with '#2': ", $email_journal_id, $function_name) . $@ . ".";
        };
      }
      if ($created_records  && $config->{processed_imap_flag}) {
        $imap_client->set_flag_for_email(
          email_journal => $email_journal,
          flag          => $config->{processed_imap_flag},
        );
      } elsif ($config->{not_processed_imap_flag}) {
        $imap_client->set_flag_for_email(
          email_journal => $email_journal,
          flag          => $config->{not_processed_imap_flag},
        );
      }
    }
    $result .= "Processed attachments with "
      . join(', ', @function_names) . "."
      if scalar @function_names;
  }

  return $result;
}

sub delete_email_imports {
  my ($self, $email_import_ids_to_delete) = @_;

  my @not_found_email_import_ids;
  my @deleted_email_import_ids;
  foreach my $email_import_id (@$email_import_ids_to_delete) {
    my $email_import = SL::DB::Manager::EmailImport->find_by(id => $email_import_id);
    unless ($email_import) {
      push @not_found_email_import_ids, $email_import_id;
      next;
    }
    $email_import->delete(cascade => 1);
    push @deleted_email_import_ids, $email_import_id;
  }

  my $result = "";

  $result .= t8("Deleted email import(s): ")
    . join(', ', @deleted_email_import_ids) . "."
    if scalar @deleted_email_import_ids;

  $result .= t8("Could not find email import(s): ")
    . join(', ', @not_found_email_import_ids) . " for deletion."
    if scalar @not_found_email_import_ids;

  return $result;
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  my $data;

  try {
    $data = $job_obj->data_as_hash;
  } catch { die t8("Invalid YAML Configuration for this job. Reason: malformed YAML Data: #1. Please consult: Program -> Documentation -> HTML -> Configuration of Background-Jobs.", $_ ); };

  my @config_params = %{$data};

  my %config = validate_with(
    params => \@config_params,
    spec   => {
      folder => {
        type     => SCALAR,
        optional => 1,
      },
      record_type => {
        optional  => 1,
        default   => 'catch_all',
        callbacks => {
          'valid record type' => sub {
            my $valid_record_types = SL::DB::EmailJournal->meta->{columns}->{record_type}->{check_in};
            unless (any {$_[0] eq $_} @$valid_record_types) {
              die "record_type '$_[0]' is not valid. Possible values:\n- " . join("\n- ", @$valid_record_types);
            }
          },
        },
      },
      process_imported_emails => {
        type      => SCALAR | ARRAYREF,
        optional  => 1,
        callbacks => {
          'function is implemented' => sub {
            foreach my $function_name (ref $_[0] eq 'ARRAY' ? @{$_[0]} : ($_[0])) {
              !!SL::Helper::EmailProcessing->can_function($function_name) or
                die "Function '$function_name' not implemented in SL::Helper::EmailProcessing";
            }
            1;
          }
        }
      },
      processed_imap_flag        => { type => SCALAR,   optional => 1, },
      not_processed_imap_flag    => { type => SCALAR,   optional => 1, },
      email_import_ids_to_delete => { type => ARRAYREF, optional => 1, },
      # email config
      hostname    => { type => SCALAR,  },
      port        => { type => SCALAR,  optional => 1},
      ssl         => { type => BOOLEAN, },
      username    => { type => SCALAR,  },
      password    => { type => SCALAR,  },
      base_folder => { type => SCALAR,  optional => 1},

    },
    called => "YAML Configuration for this Background Job invalid. Please consult: Program -> Documentation -> HTML -> Configuration of Background-Jobs.",
  );

  my @results;
  if (scalar $config{email_import_ids_to_delete}) {
    push @results, $self->delete_email_imports($config{email_import_ids_to_delete});
  }

  push @results, $self->sync_record_email_folder(\%config);

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

In kivitendo.conf the settings for the IMAP server can be specified. The
default config is under [record_emails_imap]. The config for a specific record
type is under [record_emails_imap/record_type/<record_type>]. The config for a
specific record type overwrites the default config. The data fields can
overwrite single configration values.

=over 4

=item record_type

The record type to set for each imported email journal. This is used to get
a specific config under [record_emails_imap/record_type/<record_type>]. The
default value is C<catch_all>

=item folder

The folder to sync emails from. Sub folders are separated by a forward slash,
e.g. 'INBOX/Archive'. Subfolders are not synced.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
