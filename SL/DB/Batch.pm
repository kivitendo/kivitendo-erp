package SL::DB::Batch;

use strict;

use SL::DB::MetaSetup::Batch;
use SL::DB::Manager::Batch;

__PACKAGE__->meta->initialize;
__PACKAGE__->before_save('_before_save_set_batchnumber');

sub _before_save_set_batchnumber {
  my $self = shift;
  $self->create_trans_number if !$self->batchnumber;
  return 1;
}

sub displayable_name {
  my $self = shift;
  return join '/', grep $_, $self->producer->displayable_name, $self->part->displayable_name, $self->batchnumber ;
}

sub has_children {
  my $self = shift;
  $self->id && eval "require SL::DB::Piece" && return SL::DB::Manager::Piece->get_all_count( where => [ batch_id => $self->id ] );
  return 1;
}

sub last_modification {
  my ($self) = @_;
  return $self->mtime // $self->itime;
}

sub validate {
  my( $self, $locale ) = ( shift, $::locale );
  my @errors = ();
  $self->producer_id || push @errors, $locale->text( 'The producer is missing.'    );
  $self->part_id     || push @errors, $locale->text( 'The part is missing.'        );
  $self->batchnumber || push @errors, $locale->text( 'The batchnumber is missing.' );
  $self->batchdate   || push @errors, $locale->text( 'The batchdate is missing.'   );
  scalar @errors && return @errors;
  SL::DB::Manager::Vendor->get_all_count( where => [ id => $self->producer_id ] ) || push @errors, $locale->text( "This producer dosn't exist." );
  SL::DB::Manager::Part->get_all_count( where => [ id => $self->part_id ] )       || push @errors, $locale->text( "This part dosn't exist."     );
  scalar @errors && return @errors;
  unless( $self->id ) {
    SL::DB::Manager::Batch->get_all_count(
      where => [
        producer_id => $self->producer_id,
        part_id     => $self->part_id,
        batchnumber => $self->batchnumber
      ]
    ) && push @errors, $locale->text( 'This producer/part/batchnumber already does exist.' );
    SL::DB::Manager::Batch->get_all_count(
      where => [
        producer_id => $self->producer_id,
        part_id     => $self->part_id,
        batchdate   => $self->batchdate,
        location    => $self->location,
        process     => $self->process
      ]
    ) && push @errors, $locale->text( 'This producer/part/patchdate/location/process already does exist.' );
  } else {
    SL::DB::Manager::Batch->get_all_count(
      where => [
        id          => { ne => $self->id },
        producer_id => $self->producer_id,
        part_id     => $self->part_id,
        batchnumber => $self->batchnumber
      ]
    ) && push @errors, $locale->text( 'This producer/part/batchnumber already does exist.' );
    SL::DB::Manager::Batch->get_all_count(
      where => [
        id          => { ne => $self->id },
        producer_id => $self->producer_id,
        part_id     => $self->part_id,
        batchdate   => $self->batchdate,
        location    => $self->location,
        process     => $self->process
      ]
    ) && push @errors, $locale->text( 'This producer/part/batchdate/location/process already does exist.' );
  }
  return @errors;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::Batch: Model for the table 'batches'

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 TYPES

None

=head1 FUNCTIONS

=over 4

=item C<displayable_name>

Returns the composed unique name to display.

=item C<has_children>

Returns 0 if there aren't any referenes from other tables.

=item C<last_modification>

Returns the datetime of the last modification.

=item C<validate>

Returns the error messages if this batch doesn,t fullfill the constrains.

=back

=head1 AUTHORS

Rolf Flühmann E<lt>rolf.fluehmann@revamp-it.chE<gt>,
ROlf Flühmann E<lt>rolf_fluehmann@gmx.chE<gt>

=cut
