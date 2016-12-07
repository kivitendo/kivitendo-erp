package SL::PriceSource::Pricegroup;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::DB::Price;
use SL::Locale::String;
use List::UtilsBy qw(min_by);
use List::Util qw(first);

sub name { 'pricegroup' }

sub description { t8('Pricegroup') }

sub available_prices {
  my ($self, %params) = @_;

  return () unless $self->record->is_sales;

  my $item = $self->record_item;

  my $query = [ parts_id => $item->parts_id, price => { gt => 0 } ];

  # add a pricegroup_filter for obsolete pricegroups, unless part of an
  # existing pricegroup where that pricegroup was actually used.
  if ( $self->record->id and $item->active_price_source =~ m/^pricegroup/ ) {
    my ($pricegroup_id) = $item->active_price_source =~ m/^pricegroup\/(\d+)$/;
    push(@{$query}, or => [ 'pricegroup.obsolete' => 0, 'pricegroup_id' => $pricegroup_id ]);
  } else {
    push(@{$query}, 'pricegroup.obsolete' => 0);
  }

  my $prices = SL::DB::Manager::Price->get_all(
    query        => $query,
    with_objects => 'pricegroup',
    sort_by      => 'pricegroup.sortkey',
  );

  return () unless @$prices;

  return map {
    $self->make_price($_);
  } @$prices;
}

sub available_discounts { }

sub price_from_source {
  my ($self, $source, $spec) = @_;

  my $price = SL::DB::Manager::Price->find_by(pricegroup_id => $spec, parts_id => $self->part->id);

  if (!$price) {
    return SL::PriceSource::Price->new(
      price_source => $self,
      missing      => t8('Could not find an entry for this part in the pricegroup.'),
    );
  }

  return $self->make_price($price);
}

sub discount_from_source { }

sub best_price {
  my ($self, %params) = @_;

  return () unless $self->record->is_sales;

  my @prices    = $self->available_prices;
  my $customer  = $self->record->customer;

  return () if !$customer || !$customer->pricegroup_id;

  my $best_price = first { $_->spec == $customer->pricegroup_id } @prices;

  return $best_price || ();
}

sub best_discount { }

sub make_price {
  my ($self, $price_obj) = @_;

  SL::PriceSource::Price->new(
    price        => $price_obj->price,
    spec         => $price_obj->pricegroup->id,
    description  => $price_obj->pricegroup->pricegroup,
    price_source => $self,
  )
}

1;
