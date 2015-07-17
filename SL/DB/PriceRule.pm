# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PriceRule;

use strict;

use SL::DB::MetaSetup::PriceRule;
use SL::DB::Manager::PriceRule;
use SL::Locale::String qw(t8);

__PACKAGE__->meta->add_relationship(
  items => {
    type         => 'one to many',
    class        => 'SL::DB::PriceRuleItem',
    column_map   => { id => 'price_rules_id' },
  },
);

__PACKAGE__->meta->initialize;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(price_or_discount_state) ],
);

sub match {
  my ($self, %params) = @_;

  die 'need record'      unless $params{record};
  die 'need record_item' unless $params{record_item};

  for ($self->items) {
    next if $_->match(%params);
    # TODO save for error
    return
  }

  return 1;
}

sub is_sales {
    $_[0]->type eq 'customer' ? 1
  : $_[0]->type eq 'vendor'   ? 0 : do { die 'wrong type' };
}

sub price_type {
  my ($self, $value) = @_;

  if (@_ > 1) {
    my $number = $self->price || $self->discount || $self->reduction;
    if ($value == SL::DB::Manager::PriceRule::PRICE_NEW()) {
      $self->price($number);
    } elsif ($value == SL::DB::Manager::PriceRule::PRICE_REDUCED_MASTER_DATA()) {
      $self->reduction($number);
    } elsif ($value == SL::DB::Manager::PriceRule::PRICE_DISCOUNT()) {
      $self->discount($number);
    } else {
      die 'unknown price_or_discount value';
    }
    $self->price_or_discount_state($value);
  }
  $self->price_or_discount_state;
}

sub price_or_discount_as_number {
  my ($self, @slurp) = @_;
  my $type = $self->price_type;

  $self->price(undef)     unless $type == SL::DB::Manager::PriceRule::PRICE_NEW();
  $self->reduction(undef) unless $type == SL::DB::Manager::PriceRule::PRICE_REDUCED_MASTER_DATA();
  $self->discount(undef)  unless $type == SL::DB::Manager::PriceRule::PRICE_DISCOUNT();


  if ($type == SL::DB::Manager::PriceRule::PRICE_NEW()) {
    return $self->price_as_number(@slurp)
  } elsif ($type == SL::DB::Manager::PriceRule::PRICE_REDUCED_MASTER_DATA()) {
    return $self->reduction_as_number(@slurp);
  } elsif ($type == SL::DB::Manager::PriceRule::PRICE_DISCOUNT()) {
    return $self->discount_as_number(@slurp)
  } else {
    die 'unknown price_or_discount';
  }
}

sub init_price_or_discount_state {
    defined $_[0]->price     ? SL::DB::Manager::PriceRule::PRICE_NEW()
  : defined $_[0]->reduction ? SL::DB::Manager::PriceRule::PRICE_REDUCED_MASTER_DATA()
  : defined $_[0]->discount  ? SL::DB::Manager::PriceRule::PRICE_DISCOUNT()
  :                            SL::DB::Manager::PriceRule::PRICE_NEW();
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The name must not be empty.')              if !$self->name;
  push @errors, $::locale->text('Price or discount must not be zero.')      if !$self->price && !$self->discount && !$self->reduction;
  push @errors, $::locale->text('Price rules must have at least one rule.') if !@{[ $self->items ]};
  push @errors, $_->validate                                                for $self->items;

  return @errors;
}

sub clone_and_reset_deep {
  my ($self) = @_;

  my $clone = $self->clone_and_reset;
  $clone->items(map { $_->clone_and_reset } $self->items);
  $clone->name('');

  return $clone;
}

sub full_description {
  my ($self) = @_;

  my $items = $self->item_summary;
  my $price = $self->price_or_discount
            ? t8('Discount #1%', $self->discount_as_number)
            : t8('Price #1', $self->price_as_number);

  sprintf "%s: %s (%s)", $self->name, $price, $items;
}

sub item_summary {
  join ', ', map { $_->full_description } $_[0]->items;
}

sub in_use {
  my ($self) = @_;

  # is use is in this case used by record_items for their current price source
  # so, get any of those that might have it
  require SL::DB::OrderItem;
  require SL::DB::DeliveryOrderItem;
  require SL::DB::InvoiceItem;

  my $price_source_spec = 'price_rules' . '/' . $self->id;

     SL::DB::Manager::OrderItem->get_all_count(query => [ active_price_source => $price_source_spec ])
  || SL::DB::Manager::DeliveryOrderItem->get_all_count(query => [ active_price_source => $price_source_spec ])
  || SL::DB::Manager::InvoiceItem->get_all_count(query => [ active_price_source => $price_source_spec ]);
}

sub priority_as_text {
  my ($self) = @_;

  return t8('Override') if $self->priority == 4;
  t8('Normal');
}


1;
