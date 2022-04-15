use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;

use SL::Dev::ALL qw(:ALL);
use SL::DB::PriceRule;
use SL::DB::CustomVariableConfig;

Support::TestSetup::login();

sub reset_db {
  SL::DB::Manager::PriceRule->delete_all(all => 1);
  SL::DB::Manager::CustomVariable->delete_all(all => 1);
  SL::DB::Manager::CustomVariableConfig->delete_all(all => 1);
  SL::DB::Manager::Order->delete_all(all => 1);

  $::request->{_cache} = {};
}

{
  reset_db();

  # cvar price rules.
  # a select cvar price rule for one specific value A
  # and an order where the part has exactly that cvar set to first A and then B

  my $cvar_config = SL::DB::CustomVariableConfig->new(
    module      => 'IC',
    name        => "test",
    description => "test",
    type        => "select",
    options     => "A##B##C##D",
    flags       => "editable=0",
    searchable  => 0,
    includeable => 0,
    included_by_default => 0,
  )->save->load;

  my $name = "price for test A";

  my $price_rule = SL::DB::PriceRule->new(
    name  => $name,
    price => 1,
    type  => "customer",
    items => [
      SL::DB::PriceRuleItem->new(
        custom_variable_configs => $cvar_config,
        value_text              => "A",
        type                    => "cvar",
      ),
    ],
  )->save;

  my $order = create_sales_order()->save->load;

  $order->items_sorted->[0]->part->cvar_by_name('test')->value("A");
  $order->items_sorted->[0]->part->cvar_by_name('test')->save;

  ok(1 == grep({ $_->{name} eq $name } @{ SL::DB::Manager::PriceRule->get_all_matching(record => $order, record_item => $order->items_sorted->[0]) }), "editable=0 price rule matches");

  $order->items_sorted->[0]->part->cvar_by_name('test')->value("B");
  $order->items_sorted->[0]->part->cvar_by_name('test')->save;

  ok(0 == grep({ $_->{name} eq $name } @{ SL::DB::Manager::PriceRule->get_all_matching(record => $order, record_item => $order->items_sorted->[0]) }), "editable=0 price rule does not match");
}

{
  reset_db();

  # now try the same, but with an editable cvar config

  my $cvar_config = SL::DB::CustomVariableConfig->new(
    module      => 'IC',
    name        => "test",
    description => "test2",
    type        => "select",
    options     => "A##B##C##D",
    flags       => "editable=1",
    searchable  => 0,
    includeable => 0,
    included_by_default => 0,
  )->save->load;

  my $name = "price for test A";

  my $price_rule = SL::DB::PriceRule->new(
    name  => $name,
    price => 1,
    type  => "customer",
    items => [
      SL::DB::PriceRuleItem->new(
        custom_variable_configs => $cvar_config,
        value_text              => "A",
        type                    => "cvar",
      ),
    ],
  )->save;

  my $order = create_sales_order()->save->load;
  my $item = $order->items_sorted->[0];

  $item->cvar_by_name('test')->value("A");
  $item->cvar_by_name('test')->save;

  ok(1 == grep({ $_->{name} eq $name } @{ SL::DB::Manager::PriceRule->get_all_matching(record => $order, record_item => $item) }), "editable=1 price rule matches");

  $item->cvar_by_name('test')->value("B");
  $item->cvar_by_name('test')->save;

  ok(0 == grep({ $_->{name} eq $name } @{ SL::DB::Manager::PriceRule->get_all_matching(record => $order, record_item => $item) }), "editable=1 price rule does not match");

}


done_testing();
