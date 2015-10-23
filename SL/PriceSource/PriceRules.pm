package SL::PriceSource::PriceRules;

use strict;
use parent qw(SL::PriceSource::Base);

use SL::PriceSource::Price;
use SL::PriceSource::Discount;
use SL::Locale::String;
use SL::DB::PriceRule;
use List::UtilsBy qw(min_by max_by);

sub name { 'price_rules' }

sub description { t8('Price Rule') }

sub available_rules {
  my ($self, %params) = @_;

  $self->{available} ||= SL::DB::Manager::PriceRule->get_all_matching(record => $self->record, record_item => $self->record_item);
}

sub available_price_rules {
  my $rules = $_[0]->available_rules;
  grep { $_->price_type != SL::DB::Manager::PriceRule::PRICE_DISCOUNT() } @$rules
}

sub available_discount_rules {
  my $rules = $_[0]->available_rules;
  grep { $_->price_type == SL::DB::Manager::PriceRule::PRICE_DISCOUNT() } @$rules
}

sub available_prices {
  my ($self, %params) = @_;

  map { $self->make_price_from_rule($_) } $self->available_price_rules;
}

sub available_discounts {
  my ($self, %params) = @_;

  map { $self->make_discount_from_rule($_) } $self->available_discount_rules;
}

sub price_from_source {
  my ($self, $source, $spec) = @_;

  my $rule = SL::DB::Manager::PriceRule->find_by(id => $spec);

  return SL::PriceSource::Discount->new(
    price_source => $self,
    missing      => t8('The price rule for this price does not exist anymore'),
  ) if !$rule;

  if ($rule->price_type != SL::DB::Manager::PriceRule::PRICE_DISCOUNT()) {
    return $self->make_price_from_rule($rule);
  } else {
    return SL::PriceSource::Price->new(
      price_source => $self,
      invalid      => t8('The price rule is not a rule for prices'),
    );
  }
}

sub discount_from_source {
  my ($self, $source, $spec) = @_;

  my $rule = SL::DB::Manager::PriceRule->find_by(id => $spec);

  return SL::PriceSource::Discount->new(
    price_source => $self,
    missing      => t8('The price rule for this discount does not exist anymore'),
  ) if !$rule;

  if ($rule->price_type == SL::DB::Manager::PriceRule::PRICE_DISCOUNT()) {
    return $self->make_discount_from_rule($rule);
  } else {
    return SL::PriceSource::Discount->new(
      price_source => $self,
      invalid      => t8('The price rule is not a rule for discounts'),
    );
  }
}

sub best_price {
  my ($self) = @_;

  my @rules     = $self->available_price_rules;

  return unless @rules;

  my @max_prio  = max_by { $_->priority } @rules;
  my $min_price = min_by { $self->price_for_rule($_) } @max_prio;

  $self->make_price_from_rule($min_price);
}

sub best_discount {
  my ($self) = @_;

  my @rules     = $self->available_discount_rules;

  return unless @rules;

  my @max_prio     = max_by { $_->priority } @rules;
  my $max_discount = max_by { $_->discount } @max_prio;

  $self->make_discount_from_rule($max_discount);
}

sub price_for_rule {
  my ($self, $rule) = @_;
  $rule->price_type != SL::DB::Manager::PriceRule::PRICE_NEW()
    ? (1 - $rule->reduction / 100) * ($rule->is_sales ? $self->part->sellprice : $self->part->lastcost)
    : $rule->price;
}

sub make_price_from_rule {
  my ($self, $rule) = @_;

  SL::PriceSource::Price->new(
    price        => $self->price_for_rule($rule),
    spec         => $rule->id,
    description  => $rule->name,
    priority     => $rule->priority,
    price_source => $self,
    (invalid      => t8('This Price Rule is no longer valid'))x!!$rule->obsolete,
  )
}

sub make_discount_from_rule {
  my ($self, $rule) = @_;

  SL::PriceSource::Discount->new(
    discount     => $rule->discount / 100,
    spec         => $rule->id,
    description  => $rule->name,
    priority     => $rule->priority,
    price_source => $self,
    (invalid      => t8('This Price Rule is no longer valid'))x!!$rule->obsolete,
  )
}

1;
