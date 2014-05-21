#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2009-2012 -- leonerd@leonerd.org.uk

package List::UtilsBy;

use strict;
use warnings;

our $VERSION = '0.09';

use Exporter 'import';

our @EXPORT_OK = qw(
   sort_by
   nsort_by
   rev_sort_by
   rev_nsort_by

   max_by nmax_by
   min_by nmin_by

   uniq_by

   partition_by
   count_by

   zip_by
   unzip_by

   extract_by

   weighted_shuffle_by

   bundle_by
);

=head1 NAME

C<List::UtilsBy> - higher-order list utility functions

=head1 SYNOPSIS

 use List::UtilsBy qw( nsort_by min_by );

 use File::stat qw( stat );
 my @files_by_age = nsort_by { stat($_)->mtime } @files;

 my $shortest_name = min_by { length } @names;

=head1 DESCRIPTION

This module provides a number of list utility functions, all of which take an
initial code block to control their behaviour. They are variations on similar
core perl or C<List::Util> functions of similar names, but which use the block
to control their behaviour. For example, the core Perl function C<sort> takes
a list of values and returns them, sorted into order by their string value.
The C<sort_by> function sorts them according to the string value returned by
the extra function, when given each value.

 my @names_sorted = sort @names;

 my @people_sorted = sort_by { $_->name } @people;

=cut

=head1 FUNCTIONS

=cut

=head2 @vals = sort_by { KEYFUNC } @vals

Returns the list of values sorted according to the string values returned by
the C<KEYFUNC> block or function. A typical use of this may be to sort objects
according to the string value of some accessor, such as

 sort_by { $_->name } @people

The key function is called in scalar context, being passed each value in turn
as both C<$_> and the only argument in the parameters, C<@_>. The values are
then sorted according to string comparisons on the values returned.

This is equivalent to

 sort { $a->name cmp $b->name } @people

except that it guarantees the C<name> accessor will be executed only once per
value.

One interesting use-case is to sort strings which may have numbers embedded in
them "naturally", rather than lexically.

 sort_by { s/(\d+)/sprintf "%09d", $1/eg; $_ } @strings

This sorts strings by generating sort keys which zero-pad the embedded numbers
to some level (9 digits in this case), helping to ensure the lexical sort puts
them in the correct order.

=cut

sub sort_by(&@)
{
   my $keygen = shift;

   my @keys = map { local $_ = $_; scalar $keygen->( $_ ) } @_;
   return @_[ sort { $keys[$a] cmp $keys[$b] } 0 .. $#_ ];
}

=head2 @vals = nsort_by { KEYFUNC } @vals

Similar to C<sort_by> but compares its key values numerically.

=cut

sub nsort_by(&@)
{
   my $keygen = shift;

   my @keys = map { local $_ = $_; scalar $keygen->( $_ ) } @_;
   return @_[ sort { $keys[$a] <=> $keys[$b] } 0 .. $#_ ];
}

=head2 @vals = rev_sort_by { KEYFUNC } @vals

=head2 @vals = rev_nsort_by { KEYFUNC } @vals

Similar to C<sort_by> and C<nsort_by> but returns the list in the reverse
order. Equivalent to

 @vals = reverse sort_by { KEYFUNC } @vals

except that these functions are slightly more efficient because they avoid
the final C<reverse> operation.

=cut

sub rev_sort_by(&@)
{
   my $keygen = shift;

   my @keys = map { local $_ = $_; scalar $keygen->( $_ ) } @_;
   return @_[ sort { $keys[$b] cmp $keys[$a] } 0 .. $#_ ];
}

sub rev_nsort_by(&@)
{
   my $keygen = shift;

   my @keys = map { local $_ = $_; scalar $keygen->( $_ ) } @_;
   return @_[ sort { $keys[$b] <=> $keys[$a] } 0 .. $#_ ];
}

=head2 $optimal = max_by { KEYFUNC } @vals

=head2 @optimal = max_by { KEYFUNC } @vals

Returns the (first) value from C<@vals> that gives the numerically largest
result from the key function.

 my $tallest = max_by { $_->height } @people

 use File::stat qw( stat );
 my $newest = max_by { stat($_)->mtime } @files;

In scalar context, the first maximal value is returned. In list context, a
list of all the maximal values is returned. This may be used to obtain
positions other than the first, if order is significant.

If called on an empty list, an empty list is returned.

For symmetry with the C<nsort_by> function, this is also provided under the
name C<nmax_by> since it behaves numerically.

=cut

sub max_by(&@)
{
   my $code = shift;

   return unless @_;

   local $_;

   my @maximal = $_ = shift @_;
   my $max     = $code->( $_ );

   foreach ( @_ ) {
      my $this = $code->( $_ );
      if( $this > $max ) {
         @maximal = $_;
         $max     = $this;
      }
      elsif( wantarray and $this == $max ) {
         push @maximal, $_;
      }
   }

   return wantarray ? @maximal : $maximal[0];
}

*nmax_by = \&max_by;

=head2 $optimal = min_by { KEYFUNC } @vals

=head2 @optimal = min_by { KEYFUNC } @vals

Similar to C<max_by> but returns values which give the numerically smallest
result from the key function. Also provided as C<nmin_by>

=cut

sub min_by(&@)
{
   my $code = shift;

   return unless @_;

   local $_;

   my @minimal = $_ = shift @_;
   my $min     = $code->( $_ );

   foreach ( @_ ) {
      my $this = $code->( $_ );
      if( $this < $min ) {
         @minimal = $_;
         $min     = $this;
      }
      elsif( wantarray and $this == $min ) {
         push @minimal, $_;
      }
   }

   return wantarray ? @minimal : $minimal[0];
}

*nmin_by = \&min_by;

=head2 @vals = uniq_by { KEYFUNC } @vals

Returns a list of the subset of values for which the key function block
returns unique values. The first value yielding a particular key is chosen,
subsequent values are rejected.

 my @some_fruit = uniq_by { $_->colour } @fruit;

To select instead the last value per key, reverse the input list. If the order
of the results is significant, don't forget to reverse the result as well:

 my @some_fruit = reverse uniq_by { $_->colour } reverse @fruit;

=cut

sub uniq_by(&@)
{
   my $code = shift;

   my %present;
   return grep {
      my $key = $code->( local $_ = $_ );
      !$present{$key}++
   } @_;
}

=head2 %parts = partition_by { KEYFUNC } @vals

Returns a key/value list of ARRAY refs containing all the original values
distributed according to the result of the key function block. Each value will
be an ARRAY ref containing all the values which returned the string from the
key function, in their original order.

 my %balls_by_colour = partition_by { $_->colour } @balls;

Because the values returned by the key function are used as hash keys, they
ought to either be strings, or at least well-behaved as strings (such as
numbers, or object references which overload stringification in a suitable
manner).

=cut

sub partition_by(&@)
{
   my $code = shift;

   my %parts;
   push @{ $parts{ $code->( local $_ = $_ ) } }, $_ for @_;

   return %parts;
}

=head2 %counts = count_by { KEYFUNC } @vals

Returns a key/value list of integers, giving the number of times the key
function block returned the key, for each value in the list.

 my %count_of_balls = count_by { $_->colour } @balls;

Because the values returned by the key function are used as hash keys, they
ought to either be strings, or at least well-behaved as strings (such as
numbers, or object references which overload stringification in a suitable
manner).

=cut

sub count_by(&@)
{
   my $code = shift;

   my %counts;
   $counts{ $code->( local $_ = $_ ) }++ for @_;

   return %counts;
}

=head2 @vals = zip_by { ITEMFUNC } \@arr0, \@arr1, \@arr2,...

Returns a list of each of the values returned by the function block, when
invoked with values from across each each of the given ARRAY references. Each
value in the returned list will be the result of the function having been
invoked with arguments at that position, from across each of the arrays given.

 my @transposition = zip_by { [ @_ ] } @matrix;

 my @names = zip_by { "$_[1], $_[0]" } \@firstnames, \@surnames;

 print zip_by { "$_[0] => $_[1]\n" } [ keys %hash ], [ values %hash ];

If some of the arrays are shorter than others, the function will behave as if
they had C<undef> in the trailing positions. The following two lines are
equivalent:

 zip_by { f(@_) } [ 1, 2, 3 ], [ "a", "b" ]
 f( 1, "a" ), f( 2, "b" ), f( 3, undef )

The item function is called by C<map>, so if it returns a list, the entire
list is included in the result. This can be useful for example, for generating
a hash from two separate lists of keys and values

 my %nums = zip_by { @_ } [qw( one two three )], [ 1, 2, 3 ];
 # %nums = ( one => 1, two => 2, three => 3 )

(A function having this behaviour is sometimes called C<zipWith>, e.g. in
Haskell, but that name would not fit the naming scheme used by this module).

=cut

sub zip_by(&@)
{
   my $code = shift;

   @_ or return;

   my $len = 0;
   scalar @$_ > $len and $len = scalar @$_ for @_;

   return map {
      my $idx = $_;
      $code->( map { $_[$_][$idx] } 0 .. $#_ )
   } 0 .. $len-1;
}

=head2 $arr0, $arr1, $arr2, ... = unzip_by { ITEMFUNC } @vals

Returns a list of ARRAY references containing the values returned by the
function block, when invoked for each of the values given in the input list.
Each of the returned ARRAY references will contain the values returned at that
corresponding position by the function block. That is, the first returned
ARRAY reference will contain all the values returned in the first position by
the function block, the second will contain all the values from the second
position, and so on.

 my ( $firstnames, $lastnames ) = unzip_by { m/^(.*?) (.*)$/ } @names;

If the function returns lists of differing lengths, the result will be padded
with C<undef> in the missing elements.

This function is an inverse of C<zip_by>, if given a corresponding inverse
function.

=cut

sub unzip_by(&@)
{
   my $code = shift;

   my @ret;
   foreach my $idx ( 0 .. $#_ ) {
      my @slice = $code->( local $_ = $_[$idx] );
      $#slice = $#ret if @slice < @ret;
      $ret[$_][$idx] = $slice[$_] for 0 .. $#slice;
   }

   return @ret;
}

=head2 @vals = extract_by { SELECTFUNC } @arr

Removes elements from the referenced array on which the selection function
returns true, and returns a list containing those elements. This function is
similar to C<grep>, except that it modifies the referenced array to remove the
selected values from it, leaving only the unselected ones.

 my @red_balls = extract_by { $_->color eq "red" } @balls;

 # Now there are no red balls in the @balls array

This function modifies a real array, unlike most of the other functions in this
module. Because of this, it requires a real array, not just a list.

This function is implemented by invoking C<splice()> on the array, not by
constructing a new list and assigning it. One result of this is that weak
references will not be disturbed.

 extract_by { !defined $_ } @refs;

will leave weak references weakened in the C<@refs> array, whereas

 @refs = grep { defined $_ } @refs;

will strengthen them all again.

=cut

sub extract_by(&\@)
{
   my $code = shift;
   my ( $arrref ) = @_;

   my @ret;
   for( my $idx = 0; $idx < scalar @$arrref; ) {
      if( $code->( local $_ = $arrref->[$idx] ) ) {
         push @ret, splice @$arrref, $idx, 1, ();
      }
      else {
         $idx++;
      }
   }

   return @ret;
}

=head2 @vals = weighted_shuffle_by { WEIGHTFUNC } @vals

Returns the list of values shuffled into a random order. The randomisation is
not uniform, but weighted by the value returned by the C<WEIGHTFUNC>. The
probabilty of each item being returned first will be distributed with the
distribution of the weights, and so on recursively for the remaining items.

=cut

sub weighted_shuffle_by(&@)
{
   my $code = shift;
   my @vals = @_;

   my @weights = map { $code->( local $_ = $_ ) } @vals;

   my @ret;
   while( @vals > 1 ) {
      my $total = 0; $total += $_ for @weights;
      my $select = int rand $total;
      my $idx = 0;
      while( $select >= $weights[$idx] ) {
         $select -= $weights[$idx++];
      }

      push @ret, splice @vals, $idx, 1, ();
      splice @weights, $idx, 1, ();
   }

   push @ret, @vals if @vals;

   return @ret;
}

=head2 @vals = bundle_by { BLOCKFUNC } $number, @vals

Similar to a regular C<map> functional, returns a list of the values returned
by C<BLOCKFUNC>. Values from the input list are given to the block function in
bundles of C<$number>.

If given a list of values whose length does not evenly divide by C<$number>,
the final call will be passed fewer elements than the others.

=cut

sub bundle_by(&@)
{
   my $code = shift;
   my $n = shift;

   my @ret;
   for( my ( $pos, $next ) = ( 0, $n ); $pos < @_; $pos = $next, $next += $n ) {
      $next = @_ if $next > @_;
      push @ret, $code->( @_[$pos .. $next-1] );
   }
   return @ret;
}

=head1 TODO

=over 4

=item * XS implementations

These functions are currently all written in pure perl. Some at least, may
benefit from having XS implementations to speed up their logic.

=item * Merge into L<List::Util> or L<List::MoreUtils>

This module shouldn't really exist. The functions should instead be part of
one of the existing modules that already contain many list utility functions.
Having Yet Another List Utilty Module just worsens the problem.

I have attempted to contact the authors of both of the above modules, to no
avail; therefore I decided it best to write and release this code here anyway
so that it is at least on CPAN. Once there, we can then see how best to merge
it into an existing module.

=back

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
