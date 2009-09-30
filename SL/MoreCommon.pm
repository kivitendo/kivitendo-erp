package SL::MoreCommon;

require Exporter;
@ISA = qw(Exporter);

@EXPORT    = qw(save_form restore_form compare_numbers any cross);
@EXPORT_OK = qw(ary_union ary_intersect ary_diff listify);

use YAML;

use SL::AM;

sub save_form {
  $main::lxdebug->enter_sub();

  my @dont_dump_keys = @_;
  my %not_dumped_values;

  foreach my $key (@dont_dump_keys) {
    $not_dumped_values{$key} = $main::form->{$key};
    delete $main::form->{$key};
  }

  my $old_form = YAML::Dump($main::form);
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

  my $new_form = YAML::Load($old_form);
  map { $form->{$_} = $new_form->{$_} if (!$keep_vars_map{$_}) } keys %{ $new_form };

  $main::lxdebug->leave_sub();
}

sub compare_numbers {
  $main::lxdebug->enter_sub();

  my $a      = shift;
  my $a_unit = shift;
  my $b      = shift;
  my $b_unit = shift;

  $main::all_units ||= AM->retrieve_units(\%main::myconfig, $main::form);
  my $units          = $main::all_units;

  if (!$units->{$a_unit} || !$units->{$b_unit} || ($units->{$a_unit}->{base_unit} ne $units->{$b_unit}->{base_unit})) {
    $main::lxdebug->leave_sub();
    return undef;
  }

  $a *= $units->{$a_unit}->{factor};
  $b *= $units->{$b_unit}->{factor};

  $main::lxdebug->leave_sub();

  return $a <=> $b;
}

sub any (&@) {
  my $f = shift;
  return if ! @_;
  for (@_) {
    return 1 if $f->();
  }
  return 0;
}

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

=cut
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
+

1;
