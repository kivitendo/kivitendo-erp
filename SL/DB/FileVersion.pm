# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::FileVersion;

use strict;

use SL::DB::MetaSetup::FileVersion;
use SL::DB::Manager::FileVersion;

__PACKAGE__->meta->initialize;


sub get_system_location {
  my ($self) = @_;

  my $filesystem_file = $self->doc_path . $self->file_location;

  die "Invalid state, file has vanished at: $filesystem_file" unless -f $filesystem_file;

  return $filesystem_file;

}

sub file_name {
  my ($self) = @_;

  return $self->file->file_name;

}

1;

__END__

=pod

=head1 NAME

SL::DB::FileVersion

=head1 FUNCTIONS

=over 4

=item C<get_system_location>

Returns the filesystem's file location for this exact version.
Dies if no plain file exists at the expected location.

=item C<file_name>

Shortcut for $self->file->file_name.


=back

=head1 AUTHOR

Jan E<lt>jan@kivitendo.deE<gt>
=cut
