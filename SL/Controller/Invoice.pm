package SL::Controller::Invoice;

use strict;

use parent qw(SL::Controller::Base);

use Archive::Zip;
use Params::Validate qw(:all);

use SL::DB::File;
use SL::DB::Invoice;
use SL::DB::Employee;

use SL::Webdav;
use SL::File;
use SL::Locale::String qw(t8);
use SL::MoreCommon qw(listify);

__PACKAGE__->run_before('check_auth');

sub check_auth {
  my ($self) = validate_pos(@_, { isa => 'SL::Controller::Invoice' }, 1);

  return 1 if  $::auth->assert('ar_transactions', 1); # may edit all invoices
  my @ids = listify($::form->{id});
  $::auth->assert() unless has_rights_through_projects(\@ids);
  return 1;
}

sub has_rights_through_projects {
  my ($ids) = validate_pos(@_, {
    type => ARRAYREF,
  });
  return 0 unless scalar @{$ids}; # creating new invoices isn't allowed without invoice_edit
  my $current_employee = SL::DB::Manager::Employee->current;
  my $id_placeholder = join(', ', ('?') x @{$ids});
  # Count of ids where the use has no access to
  my $query = <<SQL;
  SELECT count(id) FROM ar
  WHERE NOT EXISTS (
    SELECT * from employee_project_invoices WHERE project_id = ar.globalproject_id and employee_id = ?
  ) AND id IN ($id_placeholder)
SQL
  my ($no_access_count) = SL::DB->client->dbh->selectrow_array($query, undef, $current_employee->id, @{$ids});
  return !$no_access_count;
}

sub action_webdav_pdf_export {
  my ($self) = @_;
  my $ids  = $::form->{id};

  my $invoices = SL::DB::Manager::Invoice->get_all(where => [ id => $ids ]);

  my @file_names_and_file_paths;
  my @errors;
  foreach my $invoice (@{$invoices}) {
    my $record_type = $invoice->record_type;
    $record_type = 'general_ledger' if $record_type eq 'ar_transaction';
    $record_type = 'invoice'        if $record_type eq 'invoice_storno';
    my $webdav = SL::Webdav->new(
      type     => $record_type,
      number   => $invoice->record_number,
    );
    my @latest_object = $webdav->get_all_latest();
    unless (scalar @latest_object) {
      push @errors, t8(
        "No Dokument found for record '#1'. Please deselect it or create a document it.",
        $invoice->displayable_name()
      );
      next;
    }
    push @file_names_and_file_paths, {
      file_name => $latest_object[0]->basename . "." . $latest_object[0]->extension,
      file_path => $latest_object[0]->full_filedescriptor(),
    }
  }

  if (scalar @errors) {
    die join("\n", @errors);
  }
  $self->_create_and_send_zip(\@file_names_and_file_paths);
}

sub action_files_pdf_export {
  my ($self) = @_;

  my $ids  = $::form->{id};

  my $invoices = SL::DB::Manager::Invoice->get_all(where => [ id => $ids ]);

  my @file_names_and_file_paths;
  my @errors;
  foreach my $invoice (@{$invoices}) {
    my $record_type = $invoice->record_type;
    $record_type = 'invoice' if $record_type eq 'ar_transaction';
    $record_type = 'invoice' if $record_type eq 'invoice_storno';
    my @file_objects = SL::File->get_all(
      object_type => $record_type,
      object_id   => $invoice->id,
      file_type   => 'document',
      source      => 'created',
    );

    unless (scalar @file_objects) {
      push @errors, t8(
        "No Dokument found for record '#1'. Please deselect it or create a document it.",
        $invoice->displayable_name()
      );
      next;
    }
    foreach my $file_object (@file_objects) {
      eval {
        push @file_names_and_file_paths, {
          file_name => $file_object->file_name,
          file_path => $file_object->get_file(),
        };
      } or do {
        push @errors, $@,
      };
    }
  }

  if (scalar @errors) {
    die join("\n", @errors);
  }
  $self->_create_and_send_zip(\@file_names_and_file_paths);
}

sub _create_and_send_zip {
  my ($self, $file_names_and_file_paths) = validate_pos(@_,
    { isa => 'SL::Controller::Invoice' },
    {
      type => ARRAYREF,
      callbacks => {
        "has 'file_name' and 'file_path'" => sub {
          foreach my $file_entry (@{$_[0]}) {
            return 0 unless defined $file_entry->{file_name}
                         && defined $file_entry->{file_path};
          }
          return 1;
        }
      }
    });

  my ($fh, $zipfile) = File::Temp::tempfile();
  my $zip = Archive::Zip->new();
  foreach my $file (@{$file_names_and_file_paths}) {
    $zip->addFile($file->{file_path}, $file->{file_name});
  }
  $zip->writeToFileHandle($fh) == Archive::Zip::AZ_OK() or die 'error writing zip file';
  close($fh);

  $self->send_file(
    $zipfile,
    name => t8('pdf_records.zip'), unlink => 1,
    type => 'application/zip',
  );
}

1;
