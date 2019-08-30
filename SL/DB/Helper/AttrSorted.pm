package SL::DB::Helper::AttrSorted;

use Carp;
use List::Util qw(max);

use strict;

use parent qw(Exporter);
our @EXPORT = qw(attr_sorted);

sub attr_sorted {
  my ($package, @attributes) = @_;

  _make_sorted($package, $_) for @attributes;
}

sub _make_sorted {
  my ($package, $attribute) = @_;

  my %params       = ref($attribute) eq 'HASH' ? %{ $attribute } : ( unsorted => $attribute );
  my $unsorted_sub = $params{unsorted};
  my $sorted_sub   = $params{sorted}   // $params{unsorted} . '_sorted';
  my $position_sub = $params{position} // 'position';

  no strict 'refs';

  *{ $package . '::' . $sorted_sub } = sub {
    my ($self) = @_;

    croak 'not an accessor' if @_ > 1;

    my $next_position = ((max map { $_->$position_sub // 0 } @{ $self->$unsorted_sub }) // 0) + 1;
    return [
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->$position_sub // ($next_position++), $_ ] }
           @{ $self->$unsorted_sub }
    ];
  };
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::AttrSorted - Attribute helper for sorting to-many
relationships by a positional attribute

=head1 SYNOPSIS

  # In a Rose model:
  use SL::DB::Helper::AttrSorted;
  __PACKAGE__->attr_sorted('items');

  # Use in controller or whereever:
  my $items = @{ $invoice->items_sorted };

=head1 OVERVIEW

Creates a function that returns a sorted relationship. Requires that
the linked objects have some kind of positional column.

Items for which no position has been set (e.g. because they haven't
been saved yet) are sorted last but kept in the order they appear in
the unsorted list.

=head1 FUNCTIONS

=over 4

=item C<attr_sorted @attributes>

Package method. Call with the names of the attributes for which the
helper methods should be created. Each attribute name can be either a
scalar or a hash reference if you need custom options.

If it's a hash reference then the following keys are supported:

=over 2

=item * C<unsorted> is the name of the relationship accessor that
returns the list to be sorted. This is required, and if only a scalar
is given instead of a hash reference then that scalar value is
interpreted as C<unsorted>.

=item * C<sorted> is the name of the new function to create. It
defaults to the unsorted name postfixed with C<_sorted>.

=item * C<position> must be a function name to be called on the
objects to be sorted. It is supposed to return either C<undef> (no
position has been set yet) or a numeric value. Defaults to C<position>.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
