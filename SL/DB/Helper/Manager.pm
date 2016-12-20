package SL::DB::Helper::Manager;

use strict;

use Carp;

use Rose::DB::Object::Manager;
use base qw(Rose::DB::Object::Manager);

sub make_manager_methods {
  my $class  = shift;
  my @params = scalar(@_) ? @_ : qw(all);
  return $class->SUPER::make_manager_methods(@params);
}

sub find_by {
  my $class = shift;

  return if !@_;
  return $class->get_all(query => [ @_ ], limit => 1)->[0];
}

sub find_by_or_create {
  my $class = shift;

  my $found;
  eval {
    $found = $class->find_by(@_);
    1;
  } or die $@;
  return defined $found ? $found : $class->object_class->new;
}

sub get_first {
  shift->get_all(
    @_,
    limit => 1,
  )->[0];
}

sub cache_all {
  my $manager_class =  shift;
  my $class         =  $manager_class;
  $class            =~ s{Manager::}{};

  croak "Caching can only be used with classes with exactly one primary key column" if 1 != scalar(@{ $class->meta->primary_key_columns });

  my $all_have_been_cached =  $::request->cache("::SL::DB::Manager::cache_all");
  return if $all_have_been_cached->{$class};

  $all_have_been_cached->{$class} = 1;

  my $item_cache                  = $::request->cache("::SL::DB::Object::object_cache::${class}");
  my $primary_key                 = $class->meta->primary_key_columns->[0]->name;
  my $objects                     = $class->_get_manager_class->get_all;

  $item_cache->{$_->$primary_key} = $_ for @{ $objects};
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::Manager - Base class & helper functions for all Rose manager classes

=head1 FUNCTIONS

=over 4

=item C<cache_all>

Pre-caches all items from a table. Use this is you expect to need all
items from a table. You can retrieve them later with the
C<load_cached> function from the corresponding Rose DB object class.

For example, if you expect to need all unit objects, you can use
C<SL::DB::Manager::Unit-E<gt>cache_all> before you start the actual
work. Later you can use C<SL::DB::Unit-E<gt>load_cached> to retrieve
individual objects and be sure that they're already cached.

=item C<find_by @where>

Retrieves one item from the corresponding table matching the
conditions given in C<@where>.

This is shorthand for the following call:

    SL::DB::Manager::SomeClass->get_all(where => [ … ], limit => 1)

=item C<find_by_or_create @where>

This calls L</find_by> with C<@where> and returns its result if one is
found.

If none is found, a new instance of the corresponding DB object class
is created and returned. Such a new object is not inserted into the
database automatically.

=item C<get_first @args>

Retrieves the first item from the database by calling C<get_all> with
a limit of 1. The C<@args> are passed through to C<get_all> allowing
for arbitrary filters and sort options to be applied.

=item C<make_manager_methods [@method_list]>

Calls Rose's C<make_manager_methods> with the C<@method_list> or
C<all> if no methods are given.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
