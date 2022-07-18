package SL::DB::Manager::DeliveryOrderItem;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::DeliveryOrderItem' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( columns => { position => [ 'delivery_order_id', 'position' ], },
           default => [ 'position', 1 ],
           nulls   => { }
         );
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::DeliveryOrderItem - Manager for models for the
'delivery_order_items' table

=head1 SYNOPSIS

This is a standard Rose::DB::Manager based model manager and can be
used as such.

=head1 FUNCTIONS

None yet.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
