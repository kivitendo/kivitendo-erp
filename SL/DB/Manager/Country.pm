# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::Country;

use strict;

use SL::Helper::ISO3166 qw(map_name_to_alpha_2_code);
use SL::DB::Helper::Manager;
use SL::DB::Helper::Sorted;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Country' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortorder', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

sub find_by_name {
  my ($class, $country_name) = @_;

  my $country_code = map_name_to_alpha_2_code($country_name);

  return unless $country_code;

  my $countries_by_iso2 = $::request->cache('::SL::DB::Manager::Country', { map { $_->iso2 => $_ } @{ SL::DB::Manager::Country->get_all } });

  return $countries_by_iso2->{$country_code};
}

1;
