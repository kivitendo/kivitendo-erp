package SL::PriceSource::Customer;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::DB::Customer;
use SL::PriceSource::Discount;
use SL::Locale::String;

sub name { 'customer_discount' }

sub description { t8('Customer Discount') }

sub available_prices { }

sub available_discounts {
  my ($self, %params) = @_;

  return if     $self->part->not_discountable;
  return unless $self->record->is_sales;
  return unless $self->record->customer;
  return unless $self->record->customer->discount != 0;

  SL::PriceSource::Discount->new(
    discount     => $self->record->customer->discount,
    spec         => $self->record->customer->id,
    description  => t8('Customer Discount'),
    price_source => $self,
  );
}

sub price_from_source { }

sub discount_from_source {
  my ($self, $source, $spec) = @_;

  my $customer = SL::DB::Customer->load_cached($spec);

  if (!$customer) {
    return SL::PriceSource::Discount->new(
      missing      => t8('Could not load this customer'),
      price_source => $self,
    )
  }

  if (!$self->record->can('customer') || !$self->record->customer) {
    return SL::PriceSource::Discount->new(
      discount     => $customer->discount,
      spec         => $customer->id,
      description  => t8('Customer Discount'),
      price_source => $self,
      invalid      => t8('This discount is only valid in sales documents'),
    )
  }

  if ($customer->id != $self->record->customer->id) {
    return SL::PriceSource::Discount->new(
      discount     => $customer->discount,
      spec         => $customer->id,
      description  => t8('Customer Discount'),
      price_source => $self,
      invalid      => t8('This discount is only valid for customer #1', $customer->displayable_name),
    )
  }

  return SL::PriceSource::Discount->new(
    discount     => $customer->discount,
    spec         => $customer->id,
    description  => t8('Customer Discount'),
    price_source => $self,
  );
}

sub best_price { }

sub best_discount {
  &available_discounts;
}

1;

