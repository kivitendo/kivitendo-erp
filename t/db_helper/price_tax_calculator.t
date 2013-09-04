use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Part;
use SL::DB::Unit;

my ($customer, $currency_id, @parts, $buchungsgruppe, $buchungsgruppe7, $unit, $employee, $tax, $tax7);

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(buchungsgruppe unit customer part tax);

  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);

  $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%', %{ $params{buchungsgruppe} }) || croak "No accounting group";
  $buchungsgruppe7 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%')                                || croak "No accounting group for 7\%";
  $unit            = SL::DB::Manager::Unit->find_by(name => 'kg', %{ $params{unit} })                                      || croak "No unit";
  $employee        = SL::DB::Manager::Employee->current                                                                    || croak "No employee";
  $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19, %{ $params{tax} })                           || croak "No tax";
  $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                                              || croak "No tax for 7\%";

  $currency_id     = $::instance_conf->get_currency_id;

  $customer     = SL::DB::Customer->new(
    name        => 'Test Customer',
    currency_id => $currency_id,
    %{ $params{customer} }
  )->save;

  @parts = ();
  push @parts, SL::DB::Part->new(
    partnumber         => 'T4254',
    description        => 'Fourty-two fifty-four',
    lastcost           => 1.93,
    sellprice          => 2.34,
    buchungsgruppen_id => $buchungsgruppe->id,
    unit               => $unit->name,
    %{ $params{part1} }
  )->save;

  push @parts, SL::DB::Part->new(
    partnumber         => 'T0815',
    description        => 'Zero EIGHT fifteeN @ 7%',
    lastcost           => 5.473,
    sellprice          => 9.714,
    buchungsgruppen_id => $buchungsgruppe7->id,
    unit               => $unit->name,
    %{ $params{part2} }
  )->save;
}

sub new_invoice {
  my %params  = @_;

  return SL::DB::Invoice->new(
    customer_id => $customer->id,
    currency_id => $currency_id,
    employee_id => $employee->id,
    salesman_id => $employee->id,
    gldate      => DateTime->today_local->to_kivitendo,
    taxzone_id  => 0,
    transdate   => DateTime->today_local->to_kivitendo,
    invoice     => 1,
    type        => 'invoice',
    %params,
  );
}

sub new_item {
  my (%params) = @_;

  my $part = delete($params{part}) || $parts[0];

  return SL::DB::InvoiceItem->new(
    parts_id    => $part->id,
    lastcost    => $part->lastcost,
    sellprice   => $part->sellprice,
    description => $part->description,
    unit        => $part->unit,
    %params,
  );
}

sub test_default_invoice_one_item_19_tax_not_included() {
  reset_state();

  my $item    = new_item(qty => 2.5);
  my $invoice = new_invoice(
    taxincluded  => 0,
    invoiceitems => [ $item ],
  );

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
    allocated                            => {},
    amounts                              => {
      $buchungsgruppe->income_accno_id_0 => {
        amount                           => 5.85,
        tax_id                           => $tax->id,
        taxkey                           => 3,
      },
    },
    amounts_cogs                         => {},
    assembly_items                       => [
      [],
    ],
    exchangerate                         => 1,
    taxes                                => {
      $tax->chart_id                     => 1.11,
    },
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
    allocated                             => {},
    amounts                               => {
      $buchungsgruppe->income_accno_id_0  => {
        amount                            => 5.85,
        tax_id                            => $tax->id,
        taxkey                            => 3,
      },
      $buchungsgruppe7->income_accno_id_0 => {
        amount                            => 11.66,
        tax_id                            => $tax7->id,
        taxkey                            => 2,
      },
    },
    amounts_cogs                          => {},
    assembly_items                        => [
      [], [],
    ],
    exchangerate                          => 1,
    taxes                                 => {
      $tax->chart_id                      => 1.11,
      $tax7->chart_id                     => 0.82,
    },
  }, "${title}: calculated data");
}

Support::TestSetup::login();

test_default_invoice_one_item_19_tax_not_included();
test_default_invoice_two_items_19_7_tax_not_included();

done_testing();
