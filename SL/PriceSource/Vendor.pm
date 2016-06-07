package SL::PriceSource::Vendor;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::DB::Vendor;
use SL::PriceSource::Discount;
use SL::Locale::String;

sub name { 'vendor_discount' }

sub description { t8('Vendor Discount') }

sub available_prices { }

sub available_discounts {
  my ($self, %params) = @_;

  return if     $self->record->is_sales;
  return unless $self->record->vendor;
  return unless $self->record->vendor->discount != 0;

  SL::PriceSource::Discount->new(
    discount     => $self->record->vendor->discount,
    spec         => $self->record->vendor->id,
    description  => t8('Vendor Discount'),
    price_source => $self,
  );
}

sub price_from_source { }

sub discount_from_source {
  my ($self, $source, $spec) = @_;

  my $vendor = SL::DB::Vendor->load_cached($spec);

  if (!$vendor) {
    return SL::PriceSource::Discount->new(
      missing      => t8('Could not load this vendor'),
      price_source => $self,
    )
  }

  if (!$self->record->vendor) {
    return SL::PriceSource::Discount->new(
      discount     => $vendor->discount,
      spec         => $vendor->id,
      description  => t8('Vendor Discount'),
      price_source => $self,
      invalid      => t8('This discount is only valid in purchase documents'),
    )
  }

  if ($vendor->id != $self->record->vendor->id) {
    return SL::PriceSource::Discount->new(
      discount     => $vendor->discount,
      spec         => $vendor->id,
      description  => t8('Vendor Discount'),
      price_source => $self,
      invalid      => t8('This discount is only valid for vendor #1', $vendor->displayable_name),
    )
  }

  return SL::PriceSource::Discount->new(
    discount     => $vendor->discount,
    spec         => $vendor->id,
    description  => t8('Vendor Discount'),
    price_source => $self,
  );
}


sub best_price { }

sub best_discount {
  &available_discounts;
}

1;

