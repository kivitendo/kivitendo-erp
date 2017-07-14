package SL::DB::Manager::PartClassification;

use strict;

use parent qw(SL::DB::Helper::Manager);
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::PartClassification' }

__PACKAGE__->make_manager_methods;

1;


__END__

=encoding utf-8

=head1 NAME

SL::DB::Manager::PartClassification

=cut
