package SL::DB::AdditionalBillingAddress;

use strict;

use SL::DB::MetaSetup::AdditionalBillingAddress;
use SL::DB::Manager::AdditionalBillingAddress;

__PACKAGE__->meta->initialize;

__PACKAGE__->after_save('_after_save_ensure_only_one_marked_as_default_per_customer');

sub _after_save_ensure_only_one_marked_as_default_per_customer {
  my ($self) = @_;

  if ($self->id && $self->customer_id && $self->default_address) {
    SL::DB::Manager::AdditionalBillingAddress->update_all(
      set   => { default_address => 0 },
      where => [
        customer_id => $self->customer_id,
        '!id'       => $self->id,
      ],
    );
  }

  return 1;
}

sub displayable_id {
  my $self = shift;
  my $text = join('; ', grep { $_ } (map({ $self->$_ } qw(name department_1 department_2 street)),
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
