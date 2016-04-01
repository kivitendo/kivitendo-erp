package SL::Util;

use strict;

use parent qw(Exporter);

use Carp;

our @EXPORT_OK = qw(_hashify camelify snakify trim);

sub _hashify {
  my $keep = shift;

  croak "Invalid number of entries to keep" if 0 > $keep;

  return @_[0..scalar(@_) - 1] if $keep >= scalar(@_);
  return ($keep ? @_[0..$keep - 1] : (),
          ((1 + $keep) == scalar(@_)) && ((ref($_[$keep]) || '') eq 'HASH') ? %{ $_[$keep] } : @_[$keep..scalar(@_) - 1]);
}

sub camelify {
  my ($str) = @_;
  $str =~ s/_+([[:lower:]])/uc($1)/ge;
  ucfirst $str;
}

sub snakify {
  my ($str) = @_;
  $str =~ s/_([[:upper:]])/'_' . lc($1)/ge;
  $str =~ s/(?<!^)([[:upper:]])/'_' . lc($1)/ge;
  lc $str;
}

sub trim {
  my $value = shift;
  $value    =~ s{^ \p{WSpace}+ | \p{WSpace}+ $}{}xg if defined($value);
  return $value;
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

=item C<camilify $string>

Returns C<$string> converted from underscore-style to
camel-case-style, e.g. for the string C<stupid_example_dude> it will
return C<StupidExampleDude>.

L</snakify> does the reverse.

=item C<snakify $string>

Returns C<$string> converted from camel-case-style to
underscore-style, e.g. for the string C<EvenWorseExample> it will
return C<even_worse_example>.

L</camilify> does the reverse.

=item C<trim $string>

Removes all leading and trailing whitespaces from C<$string> and
returns it. Whitespaces within the string won't be changed.

This function considers everything matching the Unicode character
property "Whitespace" (C<WSpace>) to be a whitespace.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
