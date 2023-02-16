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
use SL::DB::Project;
use SL::DB::CustomVariableConfig;

Support::TestSetup::login();

sub reset_db {
  SL::DB::Manager::PriceRule->delete_all(all => 1);
  SL::DB::Manager::CustomVariable->delete_all(all => 1);
  SL::DB::Manager::CustomVariableConfig->delete_all(all => 1);
  SL::DB::Manager::Order->delete_all(all => 1);
  SL::DB::Manager::Shipto->delete_all(all => 1);

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
    default_value => "D",
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
    default_value => "D",
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



# k, now for a more broad test:
#
# we can have these modules in cvars:
#  - CT
#  - Contact
#  - IC
#  - Project
#  - ShipTo
#
# and the cvars themselves can have these types:
#  - select
#  - customer
#  - vendor
#  - part
#  - integer
#  - number
#  - date
#  - timestamp
#
#  ...with the numeric and date ones also having comparison ops
#
#
# to be matched against all different record/record items
#
#
# testing all of that is too much, so this will do some combinations:
#   1. a cvar config
#   2. a price_rule that uses both
#   3. record + record item that either uses that or not
#   4. expected behaviour
{
  sub test {
    my ($price_rule, $record, $record_item, $comment, $expected_match) = @_;

    # needed to clear cvar caches in price rule implementation
    $::request->{_cache} = {};

    my $matching_rules = SL::DB::Manager::PriceRule->get_all_matching(record => $record, record_item => $record_item);
    my @does_match = grep { $_->{name} eq $price_rule->name } @$matching_rules;

    if ($expected_match) {
      ok(@does_match && $price_rule->name eq $does_match[0]->name, "$comment - expected match, got @does_match");
    } else {
      ok(!@does_match, "$comment - expected no match, got @does_match");
    }
  }

  {
    reset_db();

    my $name = "before critical customer date";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'CT',
      type => 'date',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
    )->save->load;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "customer",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_date              => DateTime->new(year => 2022, month => 12, day => 9),
          op                      => "lt",
          type                    => "cvar",
        ),
      ],
    )->save;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];

    test($price_rule, $order, $item, $name, 0);

    $order->customer->cvar_by_name($name)->value(DateTime->new(year => 2022, month => 12, day => 12));
    $order->customer->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- too late", 0);

    $order->customer->cvar_by_name($name)->value(DateTime->new(year => 2022, month => 12, day => 5));
    $order->customer->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- early", 1);
  }

  {
    reset_db();

    my $name = "contact number equals 1234";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'Contacts',
      type => 'number',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
    )->save->load;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "customer",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_num               => 1234,
          op                      => "eq",
          type                    => "cvar",
        ),
      ],
    )->save;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];

    test($price_rule, $order, $item, "$name -- no contact", 0);

    $order->contact(SL::DB::Contact->new)->save;

    test($price_rule, $order, $item, "$name -- null", 0);

    $order->contact->cvar_by_name($name)->value(45);
    $order->contact->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- not matching", 0);

    $order->contact->cvar_by_name($name)->value(1234);
    $order->contact->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- matching", 1);
  }

  {
    reset_db();

    my $name = "project part matches";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'Projects',
      type => 'part',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
    )->save->load;

    my $part = new_part()->save;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "customer",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_int               => $part->id,
          type                    => "cvar",
        ),
      ],
    )->save;

    my $project1 = SL::DB::Project->new(
      project_type   => SL::DB::Manager::ProjectType->find_by(description => 'Standard'),
      project_status => SL::DB::Manager::ProjectStatus->find_by(name => 'running'),
    )->save->load;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];

    test($price_rule, $order, $item, "$name -- no project", 0);

    $order->globalproject($project1)->save;

    test($price_rule, $order, $item, "$name -- global project, but no value", 0);

    $order->globalproject->cvar_by_name($name)->value($item->part);
    $order->globalproject->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- global project, not matching", 0);

    $order->globalproject->cvar_by_name($name)->value($part);
    $order->globalproject->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- global project, matching", 1);

    my $project2 = SL::DB::Project->new(
      project_type   => SL::DB::Manager::ProjectType->find_by(description => 'Standard'),
      project_status => SL::DB::Manager::ProjectStatus->find_by(name => 'running'),
    )->save->load;

    $item->project($project2)->save;

    test($price_rule, $order, $item, "$name -- item project, but no value", 0);

    $item->project->cvar_by_name($name)->value($item->part);
    $item->project->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- item project, not matching", 0);

    $item->project->cvar_by_name($name)->value($part);
    $item->project->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- item project, matching", 1);
  }

  {
    reset_db();

    my $name = "part customer matches";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'IC',
      type => 'customer',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
      flags => '',
    )->save->load;

    my $customer = new_customer()->save->load;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "vendor",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_int               => $customer->id,
          type                    => "cvar",
        ),
      ],
    )->save;

    my $order = create_purchase_order()->save->load;
    my $item = $order->items_sorted->[0];

    test($price_rule, $order, $item, "$name -- no value", 0);

    $item->part->cvar_by_name($name)->value(new_customer());
    $item->part->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- not matching", 0);

    $item->part->cvar_by_name($name)->value($customer);
    $item->part->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- matching", 1);
  }

  {
    reset_db();

    my $name = "part number with default value 15 matches 15";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'IC',
      type => 'number',
      name => $name,
      description => $name,
      default_value => 15,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
      flags => '',
    )->save->load;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "customer",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_num               => 15,
          op                      => "eq",
          type                    => "cvar",
        ),
      ],
    )->save;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];

    test($price_rule, $order, $item, "$name -- default value", 1);

    $item->part->cvar_by_name($name)->value(20);
    $item->part->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- not matching", 0);

    $item->part->cvar_by_name($name)->value(15);
    $item->part->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- matching", 1);
  }

  {
    reset_db();

    my $name = "shipto cvar and price rule matching that";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'ShipTo',
      type => 'number',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
      flags => '',
    )->save->load;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "customer",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_num               => 15,
          op                      => "eq",
          type                    => "cvar",
        ),
      ],
    )->save;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];
    my $shipto = SL::DB::Shipto->new;
    $order->shipto($shipto);
    $order->save->load;

    test($price_rule, $order, $item, "$name -- default value", 0);

    $order->shipto->cvar_by_name($name)->value(20);
    $order->shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- not matching", 0);

    $order->shipto->cvar_by_name($name)->value(15);
    $order->shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- matching", 1);
  }

  {
    reset_db();

    my $name = "custom shipto cvar and price rule matching that";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'ShipTo',
      type => 'number',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
      flags => '',
    )->save->load;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "customer",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_num               => 15,
          op                      => "eq",
          type                    => "cvar",
        ),
      ],
    )->save;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];
    my $shipto = SL::DB::Shipto->new(trans_id => $order->id, module => 'OE')->save;

    ok(ref $order->custom_shipto eq 'SL::DB::Shipto', 'custom shipto is readable from order');

    test($price_rule, $order, $item, "$name -- default value", 0);

    $order->custom_shipto->cvar_by_name($name)->value(20);
    $order->custom_shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- not matching", 0);

    $order->custom_shipto->cvar_by_name($name)->value(15);
    $order->custom_shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- matching", 1);
  }

  {
    reset_db();

    my $name = "custom shipto cvar and price rule matching that";

    my $config = SL::DB::CustomVariableConfig->new(
      module => 'ShipTo',
      type => 'number',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
      flags => '',
    )->save->load;

    my $price_rule = SL::DB::PriceRule->new(
      name  => $name,
      price => 1,
      type  => "customer",
      items => [
        SL::DB::PriceRuleItem->new(
          custom_variable_configs => $config,
          value_num               => 15,
          op                      => "eq",
          type                    => "cvar",
        ),
      ],
    )->save;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];
    my $shipto1 = SL::DB::Shipto->new;
    $order->shipto($shipto1);
    my $shipto2 = SL::DB::Shipto->new(trans_id => $order->id, module => 'OE')->save;
    $order->save->load;

    test($price_rule, $order, $item, "$name -- default value", 0);

    $order->custom_shipto->cvar_by_name($name)->value(20);
    $order->custom_shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- not matching custom", 0);

    $order->shipto->cvar_by_name($name)->value(15);
    $order->shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- not matching custom, matching shipto", 0);

    $order->custom_shipto->cvar_by_name($name)->value(15);
    $order->custom_shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- matching both", 1);

    $order->shipto->cvar_by_name($name)->value(20);
    $order->shipto->cvar_by_name($name)->save;
    test($price_rule, $order, $item, "$name -- matching custom, not matching shipto", 1);
  }

  {
    reset_db();

    my $name = "no price rule, but cvars exist with module requirementsspecs or type text";

    my $config1 = SL::DB::CustomVariableConfig->new(
      module => 'RequirementSpecs',
      type => 'number',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
      flags => '',
    )->save->load;

    my $config2 = SL::DB::CustomVariableConfig->new(
      module => 'Customer',
      type => 'text',
      name => $name,
      description => $name,
      searchable  => 0,
      includeable => 0,
      included_by_default => 0,
      flags => '',
    )->save->load;

    my $order = create_sales_order()->save->load;
    my $item = $order->items_sorted->[0];
    $order->save->load;

    test(undef, $order, $item, "$name -- nothing to match", 0);
  }
}

reset_db();

done_testing();
