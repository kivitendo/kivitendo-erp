# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CsvImportReport;

use strict;
use SL::DB;
use SL::DBUtils;

use SL::DB::MetaSetup::CsvImportReport;
use SL::DB::Manager::CsvImportReport;

__PACKAGE__->meta->add_relationships(
  rows => {
    type         => 'one to many',
    class        => 'SL::DB::CsvImportReportRow',
    column_map   => { id => 'csv_import_report_id' },
  },
  status => {
    type         => 'one to many',
    class        => 'SL::DB::CsvImportReportStatus',
    column_map   => { id => 'csv_import_report_id' },
  },
);

__PACKAGE__->meta->initialize;

sub folded_rows {
  my ($self, %params) = @_;

  my $folded_rows = {};

  for my $row_obj (@{ $params{rows} || $self->rows }) {
    $folded_rows->{ $row_obj->row } ||= [];
    $folded_rows->{ $row_obj->row }[ $row_obj->col ] = $row_obj->value;
  }

  $folded_rows;
}

sub folded_status {
  my ($self, %params) = @_;

  my $folded_status = {};

  for my $status_obj (@{ $params{status} || $self->status }) {
    $folded_status->{ $status_obj->row } ||= {};
    $folded_status->{ $status_obj->row }{information} ||= [];
    $folded_status->{ $status_obj->row }{errors} ||= [];
    push @{ $folded_status->{ $status_obj->row }{ $status_obj->type } }, $status_obj->value;
  }

  $folded_status;
}

# implementes cascade delete as per documentation
sub destroy {
  my ($self) = @_;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;

    do_query($::form, $dbh, 'DELETE FROM csv_import_report_status WHERE csv_import_report_id = ?', $self->id);
    do_query($::form, $dbh, 'DELETE FROM csv_import_report_rows WHERE csv_import_report_id = ?', $self->id);
    do_query($::form, $dbh, 'DELETE FROM csv_import_reports WHERE id = ?', $self->id);

    if ($self->profile_id) {
      my ($is_profile_used_elsewhere) = selectfirst_array_query($::form, $dbh, <<SQL, $self->profile_id);
        SELECT id
        FROM csv_import_reports
        WHERE profile_id = ?
        LIMIT 1
SQL

      if (!$is_profile_used_elsewhere) {
        do_query($::form, $dbh, 'DELETE FROM csv_import_profile_settings WHERE csv_import_profile_id = ?', $self->profile_id);
        do_query($::form, $dbh, 'DELETE FROM csv_import_profiles WHERE id = ?', $self->profile_id);
      }
    }
    1;
  }) or do { die SL::DB->client->error };
}

1;
