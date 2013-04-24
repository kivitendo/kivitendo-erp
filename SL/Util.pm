package SL::Util;

use strict;

use parent qw(Exporter);

use Carp;

our @EXPORT_OK = qw(_hashify);

sub _hashify {
  my $keep = shift;

  croak "Invalid number of entries to keep" if 0 > $keep;

  return @_[0..scalar(@_) - 1] if $keep >= scalar(@_);
  return ($keep ? @_[0..$keep - 1] : (),
          ((1 + $keep) == scalar(@_)) && ((ref($_[$keep]) || '') eq 'HASH') ? %{ $_[$keep] } : @_[$keep..scalar(@_) - 1]);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Util - Assorted utility functions

=head1 OVERVIEW

Most important things first:

DO NOT USE C<@EXPORT> HERE! Only C<@EXPORT_OK> is allowed!

=head1 FUNCTIONS

=over 4

=item C<_hashify $num, @args>

Hashifies the very last argument. Returns a list consisting of two
parts:

The first part are the first C<$num> elements of C<@args>.

The second part depends on the remaining arguments. If exactly one
argument remains and is a hash reference then its dereferenced
elements will be used. Otherwise the remaining elements of C<@args>
will be returned as-is.

Useful if you want to write code that can be called from Perl code and
Template code both. Example:

  use SL::Util qw(_hashify);

  sub do_stuff {
    my ($self, %params) = _hashify(1, @_);
    # Now do stuff, obviously!
  }

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
