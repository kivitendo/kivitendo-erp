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

=item C<find_by>

TODO: Describe find_by

=item C<find_by_or_create>

TODO: Describe find_by_or_create

=item C<get_first>

TODO: Describe get_first

=item C<make_manager_methods>

TODO: Describe make_manager_methods

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
