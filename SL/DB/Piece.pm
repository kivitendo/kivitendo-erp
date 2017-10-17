package SL::DB::Piece;

use strict;

use SL::DB::MetaSetup::Piece;
use SL::DB::Manager::Piece;

__PACKAGE__->meta->initialize;
__PACKAGE__->before_save('_before_save_set_serialnumber');

sub _before_save_set_serialnumber {
  my $self = shift;
  $self->create_trans_number if !$self->serialnumber;
  return 1;
}

sub displayable_name {
  my $self = shift;
  return $self->batch_id
    ? join '/', grep $_, $self->producer->displayable_name, $self->part->displayable_name, $self->batch->batchnumber, $self->serialnumber
    : join '/', grep $_, $self->producer->displayable_name, $self->part->displayable_name, $self->serialnumber
  ;
}

sub last_modification {
  my ($self) = @_;
  return $self->mtime // $self->itime;
}

sub validate {
  my( $self, $locale ) = ( shift, $::locale );
  my @errors = ();
  $self->producer_id  || push @errors, $locale->text( 'The producer is missing.' );
  $self->part_id      || push @errors, $locale->text( 'The part is missing.' );
  $self->serialnumber || push @errors, $locale->text( 'The serial number is missing.' );
  scalar @errors && return @errors;
  SL::DB::Manager::Vendor->get_all_count( where => [ id => $self->producer_id ] ) || push @errors, $locale->text( "This producer dosn't exist." );
  SL::DB::Manager::Part->get_all_count( where => [ id => $self->part_id ] )       || push @errors, $locale->text( "This part dosn't exist."     );
  if( $self->batch_id ) {
    SL::DB::Manager::Batch->get_all_count( where => [ id => $self->batch_id ] )   || push @errors, $locale->text( "This batch dosn't exist."     );
    SL::DB::Manager::Batch->get_all_count( where => [
        id           => $self->batch_id,
        producer_id  => $self->producer_id,
        part_id      => $self->part_id
      ]
    ) || push @errors, $locale->text( "This producer/part/batch doesn't exist." );
  }
  scalar @errors && return @errors;
  unless( $self->id ) {
    unless( $self->batch_id ) {
      SL::DB::Manager::Piece->get_all_count(
        where => [
          producer_id  => $self->producer_id,
          part_id      => $self->part_id,
          serialnumber => $self->serialnumber
        ]
      ) && push @errors, $locale->text( 'This producer/part/batch/serial number already does exist.' );
    } else {
      SL::DB::Manager::Piece->get_all_count(
        where => [
          producer_id  => $self->producer_id,
          part_id      => $self->part_id,
          batch_id     => $self->batch_id,
          serialnumber => $self->serialnumber
        ]
      ) && push @errors, $locale->text( 'This producer/part/batch/serial number already does exist.' );
    }
  } else {
    unless( $self->batch_id ) {
      SL::DB::Manager::Piece->get_all_count(
        where => [
          id           => { ne => $self->id },
          producer_id  => $self->producer_id,
          part_id      => $self->part_id,
          serialnumber => $self->serialnumber
        ]
      ) && push @errors, $locale->text( 'This producer/part/batch/serial number already does exist.' );
    } else {
      SL::DB::Manager::Piece->get_all_count(
        where => [
          id           => { ne => $self->id },
          producer_id  => $self->producer_id,
          part_id      => $self->part_id,
          batch_id     => $self->batch_id,
          serialnumber => $self->serialnumber
        ]
      ) && push @errors, $locale->text( 'This producer/part/batch/serial number already does exist.' );
    }
  }
  return @errors;
}

sub undefine {
  my $self = shift;
  $self->batch_id || $self->batch_id( undef );
  $self->weight || $self->weight( undef );
  $self->delivery_in_id || $self->delivery_in_id( undef );
  $self->bin_id || $self->bin_id( undef );
  $self->delivery_out_id || $self->delivery_out_id( undef );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::Piece: Model for the table 'pieces'

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 TYPES

None

=head1 FUNCTIONS

=over 4

=item C<displayable_name>

Returns the composed unique name to display.

=item C<last_modification>

Returns the datetime of the last modification.

=item C<undefine>

Sets the empty strings of numeric fields to undefine.

=item C<validate>

Returns the error messages if this batch doesn,t fullfill the constrains.

=back

=head1 AUTHORS

Rolf Flühmann E<lt>rolf.fluehmann@revamp-it.chE<gt>,
ROlf Flühmann E<lt>rolf_fluehmann@gmx.chE<gt>

=cut
