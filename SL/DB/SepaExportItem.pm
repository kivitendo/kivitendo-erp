package SL::DB::SepaExportItem;

use strict;
use SL::DB::MetaSetup::SepaExportItem;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
__PACKAGE__->meta->make_manager_class;

sub compare_to {
  my ($self, $other) = @_;

  return  1 if  $self->execution_date && !$other->execution_date;
  return -1 if !$self->execution_date &&  $other->execution_date;

  my $result = 0;
  $result    = $self->execution_date <=> $other->execution_date if $self->execution_date;
  return $result || ($self->sepa_export_id <=> $other->sepa_export_id) || ($self->id <=> $other->id);
}

sub set_executed {
  my ($self) = @_;

  $self->executed(1); # does execution date also need to be set?
  $self->save;
  # if all the sepa_export_items in the sepa_export are closed (executed), close the sepa_export
  if ( SL::DB::Manager::SepaExportItem->get_all_count( where => [ sepa_export_id => $self->sepa_export_id, executed => 0] ) == 0 ) {
    my $sepa_export = SL::DB::Manager::SepaExport->find_by(id => $self->sepa_export_id);
    $sepa_export->executed(1);
    $sepa_export->closed(1);
    $sepa_export->save(changes_only=>1);
  };
};


sub arap_id {
  my ($self) = @_;
  if ( $self->ar_id ) {
    return $self->ar_id;
  } else {
    return $self->ap_id;
  };
};

1;
