package SL::DB::PriceFactor;

use strict;

use SL::DB::MetaSetup::PriceFactor;
use SL::DB::Manager::PriceFactor;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

sub orphaned {
  my ($self) = @_;

  die 'not an accessor' if @_ > 1;

  require SL::DB::DeliveryOrderItem;
  require SL::DB::InvoiceItem;
  require SL::DB::OrderItem;
  require SL::DB::Part;

  return 1 if !$self->id;

  return 0 if SL::DB::Manager::DeliveryOrderItem->get_first(query => [ price_factor_id => $self->id ]);
  return 0 if SL::DB::Manager::InvoiceItem      ->get_first(query => [ price_factor_id => $self->id ]);
  return 0 if SL::DB::Manager::OrderItem        ->get_first(query => [ price_factor_id => $self->id ]);
  return 0 if SL::DB::Manager::Part             ->get_first(query => [ price_factor_id => $self->id ]);

  return 1;
}

1;

__END__

=pod

=head1 NAME

SL::DB::PriceFactor: Model for the 'price_factors' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 FUNCTIONS

None so far.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
