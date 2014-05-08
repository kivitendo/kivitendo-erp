package SL::Clipboard::RequirementSpecItem;

use strict;

use parent qw(SL::Clipboard::Base);

use List::Util qw(sum);

use SL::Common;
use SL::Locale::String;

sub dump {
  my ($self, $object) = @_;

  return $self->as_tree(_load_children($self->reload_object($object)), exclude => sub { ref($_[0]) !~ m/::RequirementSpecItem$/ });
}

sub describe {
  my ($self) = @_;

  my $item              = $self->content;
  my $num_children      = @{ $item->{children} || [] };
  my $num_grandchildren = sum map { scalar(@{ $_->{children} || [] }) } @{ $item->{children} || [] };

  if ($item->{item_type} eq 'section') {
    return t8('Requirement spec section #1 "#2" with #3 function blocks and a total of #4 sub function blocks; preamble: "#5"',
              $item->{fb_number}, $item->{title}, $num_children, $num_grandchildren, Common::truncate($item->{description}, strip => 'full'));
  } elsif ($item->{item_type} eq 'function-block') {
    return t8('Requirement spec function block #1 with #2 sub function blocks; description: "#3"',
              $item->{fb_number}, $num_children, Common::truncate($item->{description}, strip => 'full'));
  } else {
    return t8('Requirement spec sub function block #1; description: "#2"',
              $item->{fb_number}, Common::truncate($item->{description}, strip => 'full'));
  }
}

sub _load_children {
  my ($object) = @_;

  _load_children($_) for @{ $object->children };

  return $object;
}

sub _fix_object {
  my ($self, $object) = @_;

  $object->$_(undef)     for qw(fb_number);
  $self->_fix_object($_) for @{ $object->children || [] };
}

sub _fix_tree {
  my ($self, $tree, $object) = @_;

  delete @{ $tree }{ qw(id itime mtime parent_id position requirement_spec_id) };
  $self->_fix_tree($_) for @{ $tree->{children} || [] };
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Clipboard::RequirementSpecItem - Clipboard specialization for
SL::DB::RequirementSpecItem

=head1 FUNCTIONS

=over 4

=item C<describe>

Returns a human-readable description depending on the copied type
(section, function block or sub function block).

=item C<dump $object>

This specialization reloads C<$object> from the database, loads all of
its children (but only the other requirement spec items, no other
relationships) and dumps it.

=item C<_fix_object $object>

Fixes C<$object> and all of its children by clearing certain columns
like the position or function block numbers.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
