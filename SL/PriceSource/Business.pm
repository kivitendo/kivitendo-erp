package SL::PriceSource::Business;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::DB::Business;
use SL::PriceSource::Discount;
use SL::Locale::String;

sub name { 'business' }

sub description { t8('Business') }

sub available_prices { }

sub available_discounts {
  my ($self, %params) = @_;

  return unless $self->customer_vendor;
  return unless $self->customer_vendor->business;
  return unless $self->customer_vendor->business->discount != 0;

  SL::PriceSource::Discount->new(
    discount     => $self->customer_vendor->business->discount,
    spec         => $self->customer_vendor->business->id,
    description  => t8('Business Discount'),
    price_source => $self,
  );
}

sub price_from_source { }

sub discount_from_source {
  my ($self, $source, $spec) = @_;

  my $business = SL::DB::Business->load_cached($spec);

  if (!$business) {
    return SL::PriceSource::Discount->new(
      missing      => t8('Could not load this business'),
      price_source => $self,
    )
  }

  if (!$self->customer_vendor) {
    return SL::PriceSource::Discount->new(
      discount     => $business->discount,
      spec         => $business->id,
      description  => t8('Business Discount'),
      price_source => $self,
      invalid      => t8('This discount is only valid in records with customer or vendor'),
    )
  }

  if (!$self->customer_vendor->business ||
      $business->id != $self->customer_vendor->business->id) {
    return SL::PriceSource::Discount->new(
      discount     => $business->discount,
      spec         => $business->id,
      description  => t8('Business Discount'),
      price_source => $self,
      invalid      => t8('This discount is only valid for business #1', $business->displayable_name),
    )
  }

  return SL::PriceSource::Discount->new(
    discount     => $business->discount,
    spec         => $business->id,
    description  => t8('Business Discount'),
    price_source => $self,
  );
}

sub best_price { }

sub best_discount {
  &available_discounts;
}

1;

