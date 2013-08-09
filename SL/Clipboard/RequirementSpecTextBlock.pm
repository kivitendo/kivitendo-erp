package SL::Clipboard::RequirementSpecTextBlock;

use strict;

use parent qw(SL::Clipboard::Base);

use SL::Clipboard::RequirementSpecPicture;
use SL::Common;
use SL::Locale::String;

sub dump {
  my ($self, $object) = @_;

  $self->reload_object($object);

  my $tree          = $self->as_tree($object, exclude => sub { ref($_[0]) !~ m/::RequirementSpecTextBlock$/ });
  $tree->{pictures} = [ map { SL::Clipboard::RequirementSpecPicture->new->dump($_) } @{ $object->pictures } ];

  return $tree;
}

sub describe {
  my ($self) = @_;

  return t8('Requirement spec text block "#1"; content: "#2"', $self->content->{title}, Common::truncate($self->content->{text}, strip => 'full'));
}

sub _fix_object {
  my ($self, $object) = @_;

  $object->$_(undef) for qw(output_position position requirement_spec_id);

  SL::Clipboard::RequirementSpecPicture->new->_fix_object($_) for @{ $object->pictures || [] };

  return $object;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Clipboard::RequirementSpecTextBlock - Clipboard specialization for
SL::DB::RequirementSpecTextBlock

=head1 FUNCTIONS

=over 4

=item C<describe>

Returns a human-readable description including the title and an
excerpt of its content.

=item C<dump $object>

This specialization reloads C<$object> from the database, loads all of
its pictures and dumps it. The pictures are dumped using the clipboard
specialization for it, L<SL::Clipboard::RequirementSpecPicture/dump>.

=item C<_fix_object $object>

Fixes C<$object> by clearing certain columns like the position. Lets
pictures be fixed by the clipboard specialization for it,
L<SL::Clipboard::RequirementSpecPicture/_fix_object>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
