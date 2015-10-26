# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::PartsClassification;

use strict;

use parent qw(SL::DB::Helper::Manager);
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::PartsClassification' }

__PACKAGE__->make_manager_methods;


sub get_abbreviation {
  my ($class,$id) = @_;
  my $obj = $class->get_first(query => [ id => $id ]);
  return $obj->abbreviation?$obj->abbreviation:undef;
}

sub get_separate_abbreviation {
  my ($class,$id) = @_;
  my $obj = $class->get_first(query => [ id => $id ]);
  return $obj->report_separate?$obj->abbreviation:'';
}

1;
