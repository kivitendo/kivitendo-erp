package SL::DB::Helper::ValidateAssembly;

use strict;
use parent qw(Exporter);
our @EXPORT = qw(validate_assembly);

use SL::Locale::String;
use SL::DB::Part;
use SL::DB::Assembly;

sub validate_assembly {
  my ($new_part, $part) = @_;

  return t8("The assembly '#1' cannot be a part from itself.", $part->partnumber) if $new_part->id == $part->id;

  my @seen = ($part->id);

  return assembly_loop_exists(0, $new_part, @seen);
}

sub assembly_loop_exists {
  my ($depth, $new_part, @seen) = @_;

  return t8("Too much recursions in assembly tree (>100)") if $depth > 100;

  # 1. check part is an assembly
  return unless $new_part->is_assembly;

  # 2. check assembly is still in list
  return t8("The assembly '#1' would make a loop in assembly tree.", $new_part->partnumber) if grep { $_ == $new_part->id } @seen;

  # 3. add to new list

  push @seen, $new_part->id;

  # 4. go into depth for each child

  foreach my $assembly ($new_part->assemblies) {
    my $retval = assembly_loop_exists($depth + 1, $assembly->part, @seen);
    return $retval if $retval;
  }
  return undef;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::ValidateAssembly - Mixin to check loops in assemblies

=head1 SYNOPSIS

SL::DB::Helper::ValidateAssembly->validate_assembly($newpart,$assembly_part);


=head1 HELPER FUNCTION

=over 4

=item C<validate_assembly new_part_object  part_object>

A new part is added to an assembly. C<new_part_object> is the part which is want to added.

First it was checked if the new part is equal the actual part.
Then recursively all assemblies in the assemby are checked for a loop.

The function returns an error string if a loop exists or the maximum of 100 iterations is reached
else on success ''.

=back

=head1 AUTHOR

Martin Helmling E<lt>martin.helmling@opendynamic.de>E<gt>

=cut
