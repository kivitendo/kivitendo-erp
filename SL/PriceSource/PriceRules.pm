package SL::PriceSource::PriceRules;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::Locale::String;
use SL::DB::PriceRule;
use List::UtilsBy qw(min_by max_by);

sub name { 'price_rules' }

sub description { t8('Price Rules') }

sub available_rules {
  my ($self, %params) = @_;

  SL::DB::Manager::PriceRule->get_all_matching(record => $self->record, record_item => $self->record_item);
}

sub available_prices {
  my ($self, %params) = @_;

  my $rules = $self->available_rules;

  map { $self->make_price_from_rule($_) } @$rules;
}

sub price_from_source {
  my ($self, $source, $spec) = @_;

  my $rule = SL::DB::Manager::PriceRule->find_by(id => $spec);
  $self->make_price_from_rule($rule);
}

sub best_price {
  my ($self) = @_;

  $self->make_price_from_rule( min_by { $self->price_for_rule($_) } max_by { $_->priority } @{ $self->available_rules });
}

sub price_for_rule {
  my ($self, $rule) = @_;
  $rule->price_or_discount
    ? (1 - $rule->discount / 100) * ($rule->is_sales ? $self->part->sellprice : $self->part->lastcost)
    : $rule->price;
}

sub make_price_from_rule {
  my ($self, $rule) = @_;

  SL::PriceSource::Price->new(
    price        => $self->price_for_rule($rule),
    spec         => $rule->id,
    description  => $rule->name,
    price_source => $self,
  )
}

1;
