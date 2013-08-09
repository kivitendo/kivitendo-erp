package SL::Clipboard::RequirementSpecPicture;

use strict;

use parent qw(SL::Clipboard::Base);

use SL::Common;
use SL::Locale::String;
use MIME::Base64;

sub dump {
  my ($self, $object) = @_;

  $self->reload_object($object);

  my $tree    = $self->as_tree($object, exclude => sub { ref($_[0]) !~ m/::RequirementSpecPicture$/ });
  $tree->{$_} = encode_base64($tree->{$_}, '') for $self->_binary_column_names('SL::DB::RequirementSpecPicture');

  return $tree;
}

sub describe {
  my ($self) = @_;

  return t8('Requirement spec picture "#1"', $self->content->{description} ? $self->content->{description} . ' (' . $self->content->{picture_file_name} . ')' : $self->content->{picture_file_name});
}

sub _fix_object {
  my ($self, $object) = @_;

  $object->$_(undef) for qw(number);
  $object->$_(decode_base64($object->$_)) for $self->_binary_column_names('SL::DB::RequirementSpecPicture');

  return $object;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Clipboard::RequirementSpecPicture - Clipboard specialization for
SL::DB::RequirementSpecPicture

=head1 NOTES

The underlying RDBO model contains binary columns, but binary data
cannot be dumped as YAML. Therefore the binary content is encoded in
Base64 in L</dump> and decoded back to binary form in L</_fix_object>.

=head1 FUNCTIONS

=over 4

=item C<describe>

Returns a human-readable description including the title and an
excerpt of its content.

=item C<dump $object>

This specialization reloads C<$object> from the database, and dumps
it. Binary columns are dumped encoded in Base64.

=item C<_fix_object $object>

Fixes C<$object> by clearing certain columns like the number. Also
decodes binary columns from Base64 back to binary.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
