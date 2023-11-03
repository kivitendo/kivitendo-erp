package SL::DB::Manager::GLTransaction;

use strict;

use parent qw(SL::DB::Helper::Manager);


sub object_class { 'SL::DB::GLTransaction' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return if $type eq 'gl_transaction';

  die "Unknown type $type";
}

1;
