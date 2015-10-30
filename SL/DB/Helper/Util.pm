package SL::DB::Helper::Util;

use strict;

use Rose::DB::Object::Util;

use parent qw(Exporter);
our @EXPORT_OK = qw(is_unique);

#
# Public functions not exported by default
#

sub is_unique {
  my ($self, @columns) = @_;

  my @filter =  map { ($_ => $self->$_) } @columns;
  if (Rose::DB::Object::Util::is_in_db($self)) {
    push @filter, map { ("!${_}" => $self->$_ )} $self->meta->primary_key;
  }

  return !$self->_get_manager_class->get_first(where => [ and => \@filter ]);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::Util - Helper functions for Rose::DB::Object instances

=head1 SYNOPSIS

  package SL::DB::AuthUser;

  use SL::DB::Helper::Util;

  sub validate {
    ...
    if (!SL::DB::Helper::Util::is_unique($self, 'login')) {
      push @errors, "Login not unique";
    }
  }

=head1 OVERVIEW

This is a collection of assorted helper and utility functions for
Rose::DB::Object instances that don't require full-blown mixin helpers
like L<SL::DB::ActsAsList>. The module does not export any function by
default, but all of the public ones can be requested in the usual
way.

Each function can be called either as a fully qualified name with the
object instance as the first argument or (if the function is imported)
as an instance method on the object instance.

=head1 FUNCTIONS

=over 4

=item C<is_unique @columns>

Returns trueish if C<$self> is unique in its table regarding the
columns C<@columns>. What it does is look for existing records in the
database whose stored column values match C<$self>'s current values
for these columns. If C<$self> already exists in the database then
that row is not considered during the search.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
