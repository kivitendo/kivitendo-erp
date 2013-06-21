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

1;
