use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use List::MoreUtils qw(uniq);
use Support::TestSetup;
use Test::Exception;
use SL::Dev::ALL qw(:ALL);

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::DeliveryOrder;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::TaxZone;

my ($customer, @parts, $buchungsgruppe, $buchungsgruppe7, $unit, $employee, $tax, $tax7, $taxzone);
my ($transdate);

sub clear_up {
  SL::DB::Manager::Order->delete_all(all => 1);
  SL::DB::Manager::DeliveryOrder->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
};

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(buchungsgruppe unit customer part tax);

  clear_up();

  $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%', %{ $params{buchungsgruppe} }) || croak "No accounting group";
  $buchungsgruppe7 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%')                                || croak "No accounting group for 7\%";
  $unit            = SL::DB::Manager::Unit->find_by(name => 'kg', %{ $params{unit} })                                      || croak "No unit";
  $employee        = SL::DB::Manager::Employee->current                                                                    || croak "No employee";
  $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{tax} })                           || croak "No tax";
  $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                                              || croak "No tax for 7\%";
  $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland')                                           || croak "No taxzone";

  $customer     = new_customer(
    name        => 'Test Customer',
    taxzone_id  => $taxzone->id,
    %{ $params{customer} }
  )->save;

  @parts = ();
  push @parts, new_part(
    partnumber         => 'T4254',
    description        => 'Fourty-two fifty-four',
    lastcost           => 1.93,
    sellprice          => 2.34,
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part1} }
  )->save;

  push @parts, new_part(
    partnumber         => 'T0815',
    description        => 'Zero EIGHT fifteeN @ 7%',
    lastcost           => 5.473,
    sellprice          => 9.714,
    buchungsgruppen_id => $buchungsgruppe7->id,
    unit               => $unit->name,
    %{ $params{part2} }
  )->save;

  push @parts, new_part(
    partnumber         => 'T888',
    description        => 'Triple 8',
    lastcost           => 0,
    sellprice          => 0.6,
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part3} }
  )->save;

}

sub new_invoice {
  my %params  = @_;

  return create_sales_invoice(
    transdate   => $transdate,
    taxzone_id  => $taxzone->id,
    %params,
  );
}

sub new_item {
  my (%params) = @_;

  my $part = delete($params{part}) || $parts[0];

  return create_invoice_item(
    part => $part,
    %params,
  );
}

sub test_default_invoice_one_item_19_tax_not_included() {
  reset_state();

  my $item = new_item(qty => 2.5);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
  );

  my $taxkey = $item->part->get_taxkey(date => $transdate, is_sales => 1, taxzone => $invoice->taxzone_id);

  # sellprice 2.34 * qty 2.5 = 5.85
  # 19%(5.85) = 1.1115; rounded = 1.11
  # total rounded = 6.96

  # lastcost 1.93 * qty 2.5 = 4.825; rounded 4.83
  # line marge_total = 1.02
  # line marge_percent = 17.4358974358974

  my $title = 'default invoice, one item, 19% tax not included';
  my %data  = $invoice->calculate_prices_and_taxes;

  is($item->marge_total,        1.02,             "${title}: item marge_total");
  is($item->marge_percent,      17.4358974358974, "${title}: item marge_percent");
  is($item->marge_price_factor, 1,                "${title}: item marge_price_factor");

  is($invoice->netamount,       5.85,             "${title}: netamount");
  is($invoice->amount,          6.96,             "${title}: amount");
  is($invoice->marge_total,     1.02,             "${title}: marge_total");
  is($invoice->marge_percent,   17.4358974358974, "${title}: marge_percent");

  is_deeply(\%data, {
    allocated                                    => {},
    amounts                                      => {
      $buchungsgruppe->income_accno_id($taxzone) => {
        amount                                   => 5.85,
        tax_id                                   => $tax->id,
        taxkey                                   => 3,
      },
    },
    amounts_cogs                                 => {},
    assembly_items                               => [
      [],
    ],
    exchangerate                                 => 1,
    taxes_by_chart_id                            => {
      $tax->chart_id                             => 1.11,
    },
    taxes_by_tax_id                              => {
      $tax->id                                   => 1.1115,
    },
    items                                        => [
      { linetotal                                => 5.85,
        linetotal_cost                           => 4.83,
        sellprice                                => 2.34,
        tax_amount                               => 1.1115,
        taxkey_id                                => $taxkey->id,
      },
    ],
    rounding                                    =>  0,
  }, "${title}: calculated data");
}

sub test_default_invoice_two_items_19_7_tax_not_included() {
  reset_state();

  my $item1   = new_item(qty => 2.5);
  my $item2   = new_item(qty => 1.2, part => $parts[1]);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2 ],
  );

  my $taxkey1 = $item1->part->get_taxkey(date => $transdate, is_sales => 1, taxzone => $invoice->taxzone_id);
  my $taxkey2 = $item2->part->get_taxkey(date => $transdate, is_sales => 1, taxzone => $invoice->taxzone_id);

  # item 1:
  # sellprice 2.34 * qty 2.5 = 5.85
  # 19%(5.85) = 1.1115; rounded = 1.11
  # total rounded = 6.96

  # lastcost 1.93 * qty 2.5 = 4.825; rounded 4.83
  # line marge_total = 1.02
  # line marge_percent = 17.4358974358974

  # item 2:
  # sellprice 9.714 * qty 1.2 = 11.6568 rounded 11.66
  # 7%(11.6568) = 0.815976; rounded = 0.82
  # 7%(11.66)   = 0.8162
  # total rounded = 12.48

  # lastcost 5.473 * qty 1.2 = 6.5676; rounded 6.57
  # line marge_total = 5.09
  # line marge_percent = 43.6535162950257

  my $title = 'default invoice, two item, 19/7% tax not included';
  my %data  = $invoice->calculate_prices_and_taxes;

  is($item1->marge_total,        1.02,             "${title}: item1 marge_total");
  is($item1->marge_percent,      17.4358974358974, "${title}: item1 marge_percent");
  is($item1->marge_price_factor, 1,                "${title}: item1 marge_price_factor");

  is($item2->marge_total,        5.09,             "${title}: item2 marge_total");
  is($item2->marge_percent,      43.6535162950257, "${title}: item2 marge_percent");
  is($item2->marge_price_factor, 1,                "${title}: item2 marge_price_factor");

  is($invoice->netamount,        5.85 + 11.66,     "${title}: netamount");
  is($invoice->amount,           6.96 + 12.48,     "${title}: amount");
  is($invoice->marge_total,      1.02 + 5.09,      "${title}: marge_total");
  is($invoice->marge_percent,    34.8943460879497, "${title}: marge_percent");

  is_deeply(\%data, {
    allocated                                     => {},
    amounts                                       => {
      $buchungsgruppe->income_accno_id($taxzone)  => {
        amount                                    => 5.85,
        tax_id                                    => $tax->id,
        taxkey                                    => 3,
      },
      $buchungsgruppe7->income_accno_id($taxzone) => {
        amount                                    => 11.66,
        tax_id                                    => $tax7->id,
        taxkey                                    => 2,
      },
    },
    amounts_cogs                                  => {},
    assembly_items                                => [
      [], [],
    ],
    exchangerate                                  => 1,
    taxes_by_chart_id                             => {
      $tax->chart_id                              => 1.11,
      $tax7->chart_id                             => 0.82,
    },
    taxes_by_tax_id                               => {
      $tax->id                                    => 1.1115,
      $tax7->id                                   => 0.8162,
    },
    items                                        => [
      { linetotal                                => 5.85,
        linetotal_cost                           => 4.83,
        sellprice                                => 2.34,
        tax_amount                               => 1.1115,
        taxkey_id                                => $taxkey1->id,
      },
      { linetotal                                => 11.66,
        linetotal_cost                           => 6.57,
        sellprice                                => 9.714,
        tax_amount                               => 0.8162,
        taxkey_id                                => $taxkey2->id,
      },
    ],
    rounding                                    =>  0,
  }, "${title}: calculated data");
}

sub test_default_invoice_three_items_sellprice_rounding_discount() {
  reset_state();

  my $item1   = new_item(qty => 1, sellprice => 5.55, discount => .05);
  my $item2   = new_item(qty => 1, sellprice => 5.50, discount => .05);
  my $item3   = new_item(qty => 1, sellprice => 5.00, discount => .05);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item1, $item2, $item3 ],
  );

  my %taxkeys = map { ($_->id => $_->get_taxkey(date => $transdate, is_sales => 1, taxzone => $invoice->taxzone_id)) } uniq map { $_->part } ($item1, $item2, $item3);

  # item 1:
  # discount = sellprice 5.55 * discount (0.05) = 0.2775; rounded 0.28
  # linetotal = sellprice 5.55 * (1 - discount 0.05) * qty 1 = 5.2725; rounded 5.27
  # 19%(5.27) = 1.0013; rounded = 1.00
  # total rounded = 6.27

  # lastcost 1.93 * qty 1 = 1.93; rounded 1.93
  # line marge_total = 5.27 - 1.93 = 3.34
  # line marge_percent = 63.3776091081594

  # item 2:
  # discount = sellprice 5.50 * discount 0.05 = 0.275; rounded 0.28
  # linetotal = sellprice 5.50 * (1 - discount 0.05) * qty 1 = 5.225; rounded 5.23
  # 19%(5.23) = .99370; rounded = 0.99
  # total rounded = 6.22

  # lastcost 1.93 * qty 1 = 1.93; rounded 1.93
  # line marge_total = 5.23 - 1.93 = 3.30
  # line marge_percent = 3.30/5.23 = 0.630975143403442

  # item 3:
  # discount = sellprice 5.00 * discount 0.05 = 0.05 = 0.25; rounded 0.25
  # linetotal = sellprice 5.00 (1 - discount 0.05) * qty 1 = 4.75; rounded 4.75
  # 19%(4.75) = 0.9025; rounded = 0.90
  # total rounded = 5.65

  # lastcost 1.93 * qty 1 = 1.93; rounded 1.93
  # line marge_total = 4.75 - 1.93 = 2.82
  # line marge_percent = 2.82/4.75 = 59.3684210526316

  my $title = 'default invoice, three items, sellprice, rounding, discount';
  my %data  = $invoice->calculate_prices_and_taxes;

  is($item1->marge_total,        3.34,               "${title}: item1 marge_total");
  is($item1->marge_percent,      63.3776091081594,   "${title}: item1 marge_percent");
  is($item1->marge_price_factor, 1,                  "${title}: item1 marge_price_factor");

  is($item2->marge_total,        3.30,               "${title}: item2 marge_total");
  is($item2->marge_percent,      63.0975143403442,   "${title}: item2 marge_percent");
  is($item2->marge_price_factor, 1,                  "${title}: item2 marge_price_factor");

  is($item3->marge_total,        2.82,               "${title}: item3 marge_total");
  is($item3->marge_percent,      59.3684210526316,   "${title}: item3 marge_percent");
  is($item3->marge_price_factor, 1,                  "${title}: item3 marge_price_factor");

  is($invoice->netamount,        5.27 + 5.23 + 4.75, "${title}: netamount");

  # 6.27 + 6.22 + 5.65 = 18.14
  # 1.19*(5.27 + 5.23 + 4.75) = 18.1475; rounded 18.15
  #is($invoice->amount,           6.27 + 6.22 + 5.65, "${title}: amount");
  is($invoice->amount,           18.15,              "${title}: amount");

  is($invoice->marge_total,      3.34 + 3.30 + 2.82, "${title}: marge_total");
  is($invoice->marge_percent,    62.0327868852459,   "${title}: marge_percent");

  is_deeply(\%data, {
    allocated                                    => {},
    amounts                                      => {
      $buchungsgruppe->income_accno_id($taxzone) => {
        amount                                   => 15.25,
        tax_id                                   => $tax->id,
        taxkey                                   => 3,
      },
    },
    amounts_cogs                                 => {},
    assembly_items                               => [
      [], [], [],
    ],
    exchangerate                                 => 1,
    taxes_by_chart_id                            => {
      $tax->chart_id                             => 2.9,
    },
    taxes_by_tax_id                              => {
      $tax->id                                   => 2.89750,
    },
    items                                        => [
      { linetotal                                => 5.27,
        linetotal_cost                           => 1.93,
        sellprice                                => 5.27,
        tax_amount                               => 1.0013,
        taxkey_id                                => $taxkeys{$item1->parts_id}->id,
      },
      { linetotal                                => 5.23,
        linetotal_cost                           => 1.93,
        sellprice                                => 5.23,
        tax_amount                               => 0.9937,
        taxkey_id                                => $taxkeys{$item2->parts_id}->id,
      },
      { linetotal                                => 4.75,
        linetotal_cost                           => 1.93,
        sellprice                                => 4.75,
        tax_amount                               => 0.9025,
        taxkey_id                                => $taxkeys{$item3->parts_id}->id,
      }
    ],
    rounding                                    =>  0,
  }, "${title}: calculated data");
}

sub test_default_invoice_one_item_19_tax_not_included_rounding_discount() {
  reset_state();

  my $item   = new_item(qty => 6, part => $parts[2], discount => 0.03);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
  );

  my %taxkeys = map { ($_->id => $_->get_taxkey(date => $transdate, is_sales => 1, taxzone => $invoice->taxzone_id)) } uniq map { $_->part } ($item);

  # 6 parts for 0.60 with 3% discount
  #
  # linetotal = sellprice 0.60 * qty 6 * discount (1 - 0.03) = 3.492 rounded 3.49
  # total = 3.49 + 0.66 = 4.15
  #

  my $title = 'default invoice, one item, sellprice, rounding, discount';
  my %data  = $invoice->calculate_prices_and_taxes;

  is($invoice->netamount,         3.49,              "${title}: netamount");

  is($invoice->amount,            4.15,              "${title}: amount");

  is($invoice->marge_total,       3.49,              "${title}: marge_total");
  is($invoice->marge_percent,      100,              "${title}: marge_percent");

  is_deeply(\%data, {
    allocated                                    => {},
    amounts                                      => {
      $buchungsgruppe->income_accno_id($taxzone) => {
        amount                                   => 3.49,
        tax_id                                   => $tax->id,
        taxkey                                   => 3,
      },
    },
    amounts_cogs                                 => {},
    assembly_items                               => [
      [],
    ],
    exchangerate                                 => 1,
    taxes_by_chart_id                            => {
      $tax->chart_id                             => 0.66,
    },
    taxes_by_tax_id                              => {
      $tax->id                                   => 0.66310,
    },
    items                                        => [
      { linetotal                                => 3.49,
        linetotal_cost                           => 0,
        sellprice                                => 0.58,
        tax_amount                               => 0.6631,
        taxkey_id                                => $taxkeys{$item->parts_id}->id,
      },
    ],
    rounding                                     =>  0,
  }, "${title}: calculated data");
}

sub test_default_invoice_one_item_19_tax_not_included_rounding_discount_huge_qty() {
  reset_state();

  my $item   = new_item(qty => 100000, part => $parts[2], discount => 0.03, sellprice => 0.10);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
  );

  my %taxkeys = map { ($_->id => $_->get_taxkey(date => $transdate, is_sales => 1, taxzone => $invoice->taxzone_id)) } uniq map { $_->part } ($item);

  my $title = 'default invoice, one item, 19% tax not included, rounding, discount, huge qty';
  my %data  = $invoice->calculate_prices_and_taxes;

  is($invoice->netamount,         9700,              "${title}: netamount");

  is($invoice->amount,           11543,              "${title}: amount");

  is($invoice->marge_total,       9700,              "${title}: marge_total");
  is($invoice->marge_percent,      100,              "${title}: marge_percent");

  is_deeply(\%data, {
    allocated                                    => {},
    amounts                                      => {
      $buchungsgruppe->income_accno_id($taxzone) => {
        amount                                   => 9700,
        tax_id                                   => $tax->id,
        taxkey                                   => 3,
      },
    },
    amounts_cogs                                 => {},
    assembly_items                               => [
      [],
    ],
    exchangerate                                 => 1,
    taxes_by_chart_id                            => {
      $tax->chart_id                             => 1843,
    },
    taxes_by_tax_id                              => {
      $tax->id                                   => 1843,
    },
    items                                        => [
      { linetotal                                => 9700,
        linetotal_cost                           => 0,
        sellprice                                => 0.1,
        tax_amount                               => 1843,
        taxkey_id                                => $taxkeys{$item->parts_id}->id,
      },
    ],
    rounding                                    =>  0,
  }, "${title}: calculated data");
}

sub test_default_invoice_one_item_19_tax_not_included_rounding_discount_big_qty_low_sellprice() {
  reset_state();

  my $item   = new_item(qty => 10001, sellprice => 0.007, discount => 0.035);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
  );

  my %taxkeys = map { ($_->id => $_->get_taxkey(date => $transdate, is_sales => 1, taxzone => $invoice->taxzone_id)) } uniq map { $_->part } ($item);

  # item 1:
  # discount = sellprice 0.007 * discount (0.035) = 0.000245; rounded 0.00
  # sellprice = sellprice 0.007 - discount 0.00 = 0.007
  # linetotal = sellprice 0.007 * qty 10001 * (1 - 0.035) = 67.556755; rounded 67.56
  # 19%(67.56) = 12.8364; rounded = 12.84
  # total rounded = 80.40

  # lastcost 1.93 * qty 10001 = 19301.93; rounded 19301.93
  # line marge_total = 67.56-19301.93 = -19234.37
  # line marge_percent = 100*-19234.37/67.56 = -28470.0562462996

  my $title = 'default invoice one item 19 tax not included rounding discount big qty low sellprice';
  my %data  = $invoice->calculate_prices_and_taxes;

  is($invoice->netamount,                 67.56,    "${title}: netamount");

  is($invoice->amount,                    80.40,    "${title}: amount");

  is($invoice->marge_total,           -19234.37,    "${title}: marge_total");
  is($invoice->marge_percent, -28470.0562462996,    "${title}: marge_percent");

  is_deeply(\%data, {
    allocated                                    => {},
    amounts                                      => {
      $buchungsgruppe->income_accno_id($taxzone) => {
        amount                                   => 67.56,
        tax_id                                   => $tax->id,
        taxkey                                   => 3,
      },
    },
    amounts_cogs                                 => {},
    assembly_items                               => [
      [],
    ],
    exchangerate                                 => 1,
    taxes_by_chart_id                            => {
      $tax->chart_id                             => 12.84,
    },
    taxes_by_tax_id                              => {
      $tax->id                                   => 12.8364,
    },
    items                                        => [
      { linetotal                                => 67.56,
        linetotal_cost                           => 19301.93,
        sellprice                                => 0.007,
        tax_amount                               => 12.8364,
        taxkey_id                                => $taxkeys{$item->parts_id}->id,
      },
    ],
    rounding                                    =>  0,
  }, "${title}: calculated data");
}


Support::TestSetup::login();

$transdate = DateTime->today_local;
$transdate->set_year(2019) if $transdate->year == 2020; # use year 2019 in 2020, because of tax rate change in Germany

test_default_invoice_one_item_19_tax_not_included();
test_default_invoice_two_items_19_7_tax_not_included();
test_default_invoice_three_items_sellprice_rounding_discount();
test_default_invoice_one_item_19_tax_not_included_rounding_discount();
test_default_invoice_one_item_19_tax_not_included_rounding_discount_huge_qty();
test_default_invoice_one_item_19_tax_not_included_rounding_discount_big_qty_low_sellprice();

clear_up();
done_testing();

# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
