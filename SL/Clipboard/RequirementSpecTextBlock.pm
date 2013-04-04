package SL::Clipboard::RequirementSpecTextBlock;

use strict;

use parent qw(SL::Clipboard::Base);

use SL::Common;
use SL::Locale::String;

sub describe {
  my ($self) = @_;

  return t8('Requirement spec text block "#1"; content: "#2"', $self->content->{title}, Common::truncate($self->content->{text}, strip => 'full'));
}

sub _fix_object {
  my ($self, $object) = @_;

  $object->$_(undef) for qw(output_position position requirement_spec_id);

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

=item C<_fix_object $object>

Fixes C<$object> by clearing certain columns like the position.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
