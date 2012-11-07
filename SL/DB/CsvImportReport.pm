# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CsvImportReport;

use strict;
use SL::DBUtils;

use SL::DB::MetaSetup::CsvImportReport;

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

__PACKAGE__->meta->make_manager_class;
__PACKAGE__->meta->initialize;

sub folded_rows {
  my ($self) = @_;

  $self->_fold_rows unless $self->{folded_rows};

  return $self->{folded_rows};
}

sub folded_status {
  my ($self) = @_;

  $self->_fold_status unless $self->{folded_status};

  return $self->{folded_status};
}

sub _fold_rows {
  my ($self) = @_;

  $self->{folded_rows} = [];

  for my $row_obj (@{ $self->rows }) {
    $self->{folded_rows}->[ $row_obj->row ] ||= [];
    $self->{folded_rows}->[ $row_obj->row ][ $row_obj->col ] = $row_obj->value;
  }
}

sub _fold_status {
  my ($self) = @_;

  $self->{folded_status} = [];

  for my $status_obj (@{ $self->status }) {
    $self->{folded_status}->[ $status_obj->row ] ||= {};
    $self->{folded_status}->[ $status_obj->row ]{information} ||= [];
    $self->{folded_status}->[ $status_obj->row ]{errors} ||= [];
    push @{ $self->{folded_status}->[ $status_obj->row ]{ $status_obj->type } }, $status_obj->value;
  }
}

# implementes cascade delete as per documentation
sub destroy {
  my ($self) = @_;

  my $dbh = $self->db->dbh;

  $dbh->begin_work;

  do_query($::form, $dbh, 'DELETE FROM csv_import_report_status WHERE csv_import_report_id = ?', $self->id);
  do_query($::form, $dbh, 'DELETE FROM csv_import_report_rows WHERE csv_import_report_id = ?', $self->id);
  do_query($::form, $dbh, 'DELETE FROM csv_import_reports WHERE id = ?', $self->id);

  if ($self->profile_id) {
    do_query($::form, $dbh, 'DELETE FROM csv_import_profile_settings WHERE csv_import_profile_id = ?', $self->profile_id);
    do_query($::form, $dbh, 'DELETE FROM csv_import_profiles WHERE id = ?', $self->profile_id);
  }

  $dbh->commit;
}

1;
