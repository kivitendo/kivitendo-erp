package SL::DB::Manager::PartClassification;

use strict;

use parent qw(SL::DB::Helper::Manager);
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::PartClassification' }

__PACKAGE__->make_manager_methods;

sub classification_filter {
  my ($class, $classification, $prefix) = @_;

  return () unless $classification;

  $prefix //= '';

  my @classifications = grep { $_ } listify($classification);
  return ( $prefix . 'classification_id' => \@classifications );
}

1;


__END__

=encoding utf-8

=head1 NAME

SL::DB::Manager::PartClassification

=cut
