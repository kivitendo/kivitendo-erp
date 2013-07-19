package SL::DB::Manager::Unit;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

sub object_class { 'SL::DB::Unit' }

__PACKAGE__->make_manager_methods;
__PACKAGE__->add_filter_specs(
  convertible_to => sub {
    my ($key, $value, $prefix) = @_;
    return __PACKAGE__->convertible_to_filter($key, $value, $prefix);
  },
);

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL',
                        name   => 'lower(name)',
                      });
}

sub convertible_to_filter {
  my ($class, $key, $unit_name, $prefix) = @_;

  return () unless $unit_name;

  $prefix //= '';

  my $unit = $class->find_by(name => $unit_name);
  if (!$unit) {
    $::lxdebug->warn("Unit manager: No unit with name $unit_name");
    return ();
  }

  return ("${prefix}name" => [ map { $_->name } @{ $unit->convertible_units } ]);
}

1;
