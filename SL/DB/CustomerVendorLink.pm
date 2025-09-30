# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CustomerVendorLink;

use strict;
use Carp qw(croak);

use SL::DB::MetaSetup::CustomerVendorLink;
use SL::DB::Manager::CustomerVendorLink;

__PACKAGE__->meta->initialize;

# alternate implementation of SL::DB::Object::load_cached, since this one uses a combined primary key
sub load_cached {
  my $class_or_self = shift;
  my @ids           = @_;
  my $class         = ref($class_or_self) || $class_or_self;
  my $cache         = $::request->cache("::SL::DB::Object::object_cache::${class}");

  croak "Missing ID" unless @ids;

  my @missing_ids = grep { !exists $cache->{$_} } @ids;

  return $cache->{$ids[0]} if !@missing_ids;

  # since customer/vendor are on the same id serial, use either to find the link
  my $objects     = $class->_get_manager_class->get_all(
    where => [
      or => [
        customer_id => \@missing_ids,
        vendor_id   => \@missing_ids,
      ]
    ]
  );

  $cache->{$_->customer_id} = $_ for @{ $objects};
  $cache->{$_->vendor_id} = $_ for @{ $objects};

  return $cache->{$ids[0]};
}

sub invalidate_cached {
  my ($class_or_self, @ids) = @_;
  my $class                 = ref($class_or_self) || $class_or_self;

  if (ref($class_or_self) && !@ids) {
    @ids            = ($class_or_self->customer_id);
  }

  # expand ids to have both
  @ids = map { $_->customer_id, $_->vendor_id } @{ $::request->cache("::SL::DB::Object::object_cache::${class}") }{ @ids };

  delete @{ $::request->cache("::SL::DB::Object::object_cache::${class}") }{ @ids };

  return $class_or_self;
}

1;
