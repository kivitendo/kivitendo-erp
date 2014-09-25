# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PriceRule;

use strict;

use SL::DB::MetaSetup::PriceRule;
use SL::DB::Manager::PriceRule;
use Rose::DB::Object::Helpers qw(clone_and_reset);
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

sub price_or_discount {
  my ($self, $value) = @_;

  if (@_ > 1) {
    my $number = $self->price || $self->discount;
    if ($value) {
      $self->discount($number);
    } else {
      $self->price($number);
    }
    $self->price_or_discount_state($value);
  }
  $self->price_or_discount_state;
}

sub price_or_discount_as_number {
  my ($self, @slurp) = @_;

  $self->price_or_discount ? $self->price(undef)               : $self->discount(undef);
  $self->price_or_discount ? $self->discount_as_number(@slurp) : $self->price_as_number(@slurp);
}

sub init_price_or_discount_state {
    defined $_[0]->price ? 0
  : defined $_[0]->discount ? 1 : 0
}

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The name must not be empty.')              if !$self->name;
  push @errors, $::locale->text('Price or discount must not be zero.')      if !$self->price && !$self->discount;
  push @errors, $::locale->text('Pirce rules must have at least one rule.') if !@{[ $self->items ]};

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

  my $items = join ', ', map { $_->full_description } $self->items;
  my $price = $self->price_or_discount
            ? t8('Discount #1%', $self->discount_as_number)
            : t8('Price #1', $self->price_as_number);

  sprintf "%s: %s (%s)", $self->name, $price, $items;
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
