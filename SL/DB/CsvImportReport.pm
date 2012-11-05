# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CsvImportReport;

use strict;

use SL::DB::MetaSetup::CsvImportReport;

__PACKAGE__->meta->add_relationships(
  rows => {
    type         => 'one to many',
    class        => 'SL::DB::CsvImportReportRow',
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

sub _fold_rows {
  my ($self) = @_;

  $self->{folded_rows} = [];

  for my $row_obj (@{ $self->rows }) {
    $::lxdebug->dump(0,  "adding", $row_obj->row . ' ' . $row_obj->col . ' ' . $row_obj->value);
    $self->{folded_rows}->[ $row_obj->row ] ||= [];
    $self->{folded_rows}->[ $row_obj->row ][ $row_obj->col ] = $row_obj->value;
    $::lxdebug->dump(0,  "now", $self->{folded_rows});
  }
}

1;
