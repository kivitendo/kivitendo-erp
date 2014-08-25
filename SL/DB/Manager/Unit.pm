package SL::DB::Manager::Unit;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

use List::Util qw(first);

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

sub all_units {
  my ($class) = @_;
  $::request->cache('all_units')->{sorted} //= $class->get_all_sorted;
}

sub find_h_unit {
  my ($class) = @_;

  return $::request->cache('unit_manager')->{h_unit} //= first { $_->name =~ m{^(?: Std | h | Stunde )$}x } @{ $class->all_units };
}

sub time_based_units {
  my ($class) = @_;

  my $h_unit = $class->find_h_unit;
  return [] if !$h_unit;
  return $::request->cache('unit_manager')->{units} //= $h_unit->convertible_units;
}

1;
