package SL::DB::AdditionalBillingAddress;

use strict;

use SL::DB::MetaSetup::AdditionalBillingAddress;
use SL::DB::Manager::AdditionalBillingAddress;

__PACKAGE__->meta->initialize;

sub displayable_id {
  my $self = shift;
  my $text = join('; ', grep { $_ } (map({ $self->$_ } qw(name street)),
                                     join(' ', grep { $_ }
                                               map  { $self->$_ }
                                               qw(zipcode city))));

  return $text;
}

sub used {
  my ($self) = @_;

  return unless $self->id;

  require SL::DB::Order;
  require SL::DB::Invoice;
  require SL::DB::DeliveryOrder;

  my %args = (query => [ billing_address_id => $self->id ]);

  return SL::DB::Manager::Invoice->get_all_count(%args)
      || SL::DB::Manager::Order->get_all_count(%args)
      || SL::DB::Manager::DeliveryOrder->get_all_count(%args);
}

sub detach {
  $_[0]->customer_id(undef);
  return $_[0];
}

1;
