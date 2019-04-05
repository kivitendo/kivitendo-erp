package SL::MoreCommon;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT    = qw(save_form restore_form compare_numbers cross);
our @EXPORT_OK = qw(ary_union ary_intersect ary_diff listify ary_to_hash uri_encode uri_decode);

use Encode ();
use List::MoreUtils qw(zip);
use SL::YAML;

use strict;

sub save_form {
  $main::lxdebug->enter_sub();

  my @dont_dump_keys = @_;
  my %not_dumped_values;

  foreach my $key (@dont_dump_keys) {
    $not_dumped_values{$key} = $main::form->{$key};
    delete $main::form->{$key};
  }

  my $old_form = SL::YAML::Dump($main::form);
  $old_form =~ s|!|!:|g;
  $old_form =~ s|\n|!n|g;
  $old_form =~ s|\r|!r|g;

  map { $main::form->{$_} = $not_dumped_values{$_} } keys %not_dumped_values;

  $main::lxdebug->leave_sub();

  return $old_form;
}

sub restore_form {
  $main::lxdebug->enter_sub();

  my ($old_form, $no_delete, @keep_vars) = @_;

  my $form          = $main::form;
  my %keep_vars_map = map { $_ => 1 } @keep_vars;

  map { delete $form->{$_} if (!$keep_vars_map{$_}); } keys %{$form} unless ($no_delete);

  $old_form =~ s|!r|\r|g;
  $old_form =~ s|!n|\n|g;
  $old_form =~ s|![!:]|!|g;

  my $new_form = SL::YAML::Load($old_form);
  map { $form->{$_} = $new_form->{$_} if (!$keep_vars_map{$_}) } keys %{ $new_form };

  $main::lxdebug->leave_sub();
}

sub compare_numbers {
  $main::lxdebug->enter_sub();

  my ($a, $a_unit, $b, $b_unit) = @_;
  require SL::AM;
  my $units          = AM->retrieve_all_units;

  if (!$units->{$a_unit} || !$units->{$b_unit} || ($units->{$a_unit}->{base_unit} ne $units->{$b_unit}->{base_unit})) {
    $main::lxdebug->leave_sub();
    return undef;
  }

  $a *= $units->{$a_unit}->{factor};
  $b *= $units->{$b_unit}->{factor};

  $main::lxdebug->leave_sub();

  return $a <=> $b;
}

sub cross(&\@\@) {
  my $op = shift;
  use vars qw/@A @B/;
  local (*A, *B) = @_;    # syms for caller's input arrays

  # Localise $a, $b
  my ($caller_a, $caller_b) = do {
    my $pkg = caller();
    no strict 'refs';
    \*{$pkg.'::a'}, \*{$pkg.'::b'};
  };

  local(*$caller_a, *$caller_b);

  # This map expression is also the return value.
  map { my $a_index = $_;
    map { my $b_index = $_;
      # assign to $a, $b as refs to caller's array elements
      (*$caller_a, *$caller_b) = \($A[$a_index], $B[$b_index]);
      $op->();    # perform the transformation
    }  0 .. $#B;
  }  0 .. $#A;
}

sub _ary_calc_union_intersect {
  my ($a, $b) = @_;

  my %count = ();

  foreach my $e (@$a, @$b) { $count{$e}++ }

  my @union = ();
  my @isect = ();
  foreach my $e (keys %count) {
    push @union, $e;
    push @isect, $e if $count{$e} == 2;
  }

  return (\@union, \@isect);
}

sub ary_union {
  return @{ (_ary_calc_union_intersect @_)[0] };
}

sub ary_intersect {
  return @{ (_ary_calc_union_intersect @_)[1] };
}

sub ary_diff {
  my ($a, $b) = @_;
  my %in_b    = map { $_ => 1 } @$b;
  return grep { !$in_b{$_} } @$a;
}

sub listify {
  my @ary = scalar @_ > 1 ? @_ : ref $_[0] eq 'ARRAY' ? @{ $_[0] } : (@_);
  return wantarray ? @ary : scalar @ary;
}

sub ary_to_hash {
  my $idx_key   = shift;
  my $value_key = shift;

  return map { ($_, 1) } @_ if !defined($idx_key);

  my @indexes = map { ref $_ eq 'HASH' ? $_->{ $idx_key } : $_->$idx_key(); } @_;
  my @values  = map {
      !defined($value_key) ? $_
    : ref $_ eq 'HASH'     ? $_->{ $value_key }
    :                        $_->$value_key()
  } @_;

  return zip(@indexes, @values);
}

sub uri_encode {
  my ($str) = @_;

  $str =  Encode::encode('utf-8-strict', $str);
  $str =~ s/([^a-zA-Z0-9_.:-])/sprintf("%%%02x", ord($1))/ge;

  return $str;
}

sub uri_decode {
  my $str = $_[0] // '';

  $str =~ tr/+/ /;
  $str =~ s/\\$//;

  $str =~ s/%([0-9a-fA-Z]{2})/pack("C",hex($1))/eg;
  $str =  Encode::decode('utf-8-strict', $str);

  return $str;
}

1;

__END__

=head1 NAME

SL::MoreCommon.pm - helper functions

=head1 DESCRIPTION

this is a collection of helper functions used in kivitendo.
Most of them are either obvious or too obscure to care about unless you really have to.
The exceptions are documented here.

=head2 FUNCTIONS

=over 4

=item save_form

=item restore_form

A lot of the old sql-ledger routines are strictly procedural. They search for params in the $form object, do stuff with it, and return a status code.

Once in a while you'll want something from such a function without altering $form. Yeah, you could rewrite the routine from scratch... not. Just save you form, execute the routine, grab your results, and restore the previous form while you curse at the original design.

=item cross BLOCK ARRAY ARRAY

Evaluates BLOCK for each combination of elements in ARRAY1 and ARRAY2
and returns a new list consisting of BLOCK's return values.
The two elements are set to $a and $b.
Note that those two are aliases to the original value so changing them
will modify the input arrays.

  # append each to each
  @a = qw/a b c/;
  @b = qw/1 2 3/;
  @x = cross { "$a$b" } @a, @b;
  # returns a1, a2, a3, b1, b2, b3, c1, c2, c3

As cross expects an array but returns a list it is not directly chainable
at the moment. This will be corrected in the future.

=item ary_to_hash INDEX_KEY, VALUE_KEY, ARRAY

Returns a hash with the content of ARRAY based on the values of
INDEX_KEY and VALUE_KEY.

If INDEX_KEY is undefined then the elements of ARRAY are the keys and
'1' is the value for each of them.

If INDEX_KEY is defined then each element of ARRAY is checked whether
or not it is a hash. If it is then its element at the position
INDEX_KEY will be the resulting hash element's key. Otherwise the
element is assumed to be a blessed reference, and its INDEX_KEY
function will be called.

The values of the resulting hash follow a similar pattern. If
VALUE_KEY is undefined then the current element itself is the new hash
element's value. If the current element is a hash then its element at
the position VALUE_KEY will be the resulting hash element's
key. Otherwise the element is assumed to be a blessed reference, and
its VALUE_KEY function will be called.

=back

=cut
