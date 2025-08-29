use Test::More;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Carp;
use List::Util qw(sum);
use SL::DB::Chart;
use SL::DB::Default;
use SL::DB::TaxzoneChart;
use SL::Helper::Number qw(_round_total);
use SL::ZUGFeRD;

use SL::Dev::ALL qw(:ALL);
use Support::TestSetup;

Support::TestSetup::login();

sub clear_up {
  my ($additional_objects_to_delete) = @_;

  SL::DB::Manager::InvoiceItem->delete_all (all => 1);
  SL::DB::Manager::Invoice->delete_all     (all => 1);
  SL::DB::Manager::Part->delete_all        (all => 1);
  SL::DB::Manager::BankAccount->delete_all (all => 1);

  $_->delete for @$additional_objects_to_delete;
};

my $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%') || croak "No accounting group";
my $buchungsgruppe7 = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 7%')  || croak "No accounting group for 7\%";
my $unit            = SL::DB::Manager::Unit->find_by(name => 'Stck')                          || croak "No unit";
my $employee        = SL::DB::Manager::Employee->current                                      || croak "No employee";
my $tax             = SL::DB::Manager::Tax->find_by(taxkey => 3, rate => 0.19)                || croak "No tax";
my $tax7            = SL::DB::Manager::Tax->find_by(taxkey => 2, rate => 0.07)                || croak "No tax for 7\%";
my $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland')             || croak "No taxzone";

my $defaults = SL::DB::Manager::Default->get_all(limit => 1)->[0];
$defaults->update_attributes(
  company         => 'Bundeszentralamt für Steuern',
  address_street1 => 'An der Küppe',
  address_zipcode => '53225',
  address_city    => 'Bonn',
  address_country => 'Deutschland',
  co_ustid        => 'DE259582878'
);

my $bank_account =  SL::DB::BankAccount->new(
    account_number  => '123',
    bank_code       => '123',
    iban            => '123',
    bic             => '123',
    bank            => '123',
    chart_id        => SL::DB::Manager::Chart->find_by(description => 'Bank')->id,
    name            => SL::DB::Manager::Chart->find_by(description => 'Bank')->description,
)->save;

my $customer = new_customer(
  name                    => 'Finanzamt für Steuerstrafsachen und Steuerfahndung Bochum',
  street                  => 'Uhlandstr.',
  city                    => 'Bochum',
  zipcode                 => '44791',
  taxzone_id              => $taxzone->id,
  c_vendor_routing_id     => '05911-12003-47',
  create_zugferd_invoices => 2,
)->save;

my @parts = ();
push @parts, new_part(
  partnumber         => 'T4254',
  description        => 'Fourty-two fifty-four',
  lastcost           => 55.00,
  sellprice          => 59.99,
  buchungsgruppen_id => $buchungsgruppe->id,
  unit               => $unit->name,
)->save;

push @parts, new_part(
  partnumber         => 'T0815',
  description        => 'Zero EIGHT fifteeN @ 7%',
  lastcost           => 5.473,
  sellprice          => 9.714,
  buchungsgruppen_id => $buchungsgruppe7->id,
  unit               => $unit->name,
)->save;

my $discount = 0;
#my $discount = 2.5/100; # for triggering a rounding error

my $item1   = create_invoice_item(qty => 1, discount => $discount, part => $parts[0]);
my $item2   = create_invoice_item(qty => 1, discount => $discount, part => $parts[1]);
my $invoice = create_sales_invoice(
  transdate   => '2025-08-28',
  duedate     => '2025-08-28',
  taxzone_id  => $taxzone->id,
  customer    => $customer,
  taxincluded  => 0,
  invoiceitems => [ $item1, $item2 ],
);

my $xml = $invoice->create_zugferd_data;
my $res = SL::ZUGFeRD->extract_from_xml($xml);

my $t19  = _round_total($parts[0]->sellprice*(1-$discount)*19/100);
my $t7   = _round_total($parts[1]->sellprice*(1-$discount)* 7/100);

my @taxes = sort { $a->{tax_rate} <=> $b->{tax_rate} } @{$res->{invoice_xml}->{_taxes}};

is($taxes[0]->{amount}, $t7, "tax 7 is right");
is($taxes[1]->{amount}, $t19, "tax 19 is right");
is($res->{invoice_xml}->{_metadata}->{tax_total}, $t7 + $t19, "tax total is right");

my $tax_sum = sum map { $_->{amount}} @taxes;
is($res->{invoice_xml}->{_metadata}->{tax_total}, $tax_sum, "tax total equals sum of taxes");

# Create a new buchungsgruppe with a different chart for the used taxzone,
# but with the same tax as $buchungsgruppe.
my $bg_waste = $buchungsgruppe->clone_and_reset;
$bg_waste->save;
my $income_chart = SL::DB::Manager::Chart->find_by(description => 'Erlöse Abfallverwertung') || croak "no income chart 'Erlöse Abfallverwertung'";
my @new_taxzonecharts;
foreach my $taxzone_chart (@{$buchungsgruppe->taxzonecharts}) {
  my $new_taxzonechart = $taxzone_chart->clone_and_reset;
  $new_taxzonechart->buchungsgruppen_id($bg_waste->id);
  $new_taxzonechart->income_accno_id($income_chart->id) if $taxzone_chart->taxzone_id == $taxzone->id;
  $new_taxzonechart->save;
  push @new_taxzonecharts, $new_taxzonechart;
}

push @parts, new_part(
  partnumber         => 'W001',
  description        => 'recycle waste 001 @19%',
  sellprice          => 9.99,
  buchungsgruppen_id => $bg_waste->id,
  unit               => $unit->name,
  part_type          => 'service',
)->save;
my $item3 = create_invoice_item(qty => 1, discount => $discount, part => $parts[2]);

$invoice->add_items($item3);
$invoice->save;

$xml = $invoice->create_zugferd_data;
$res = SL::ZUGFeRD->extract_from_xml($xml);

@taxes = sort { $a->{tax_rate} <=> $b->{tax_rate} } @{$res->{invoice_xml}->{_taxes}};

$t19 += _round_total($parts[2]->sellprice*(1-$discount)*19/100);

is(scalar @taxes, 2, "only two taxes with new buchungsgruppe and same tax");
is($taxes[0]->{amount}, $t7, "tax 7 is right with new buchungsgruppe and same tax");
is($taxes[1]->{amount}, $t19, "tax 19 is right with new buchungsgruppe and same tax");
is($res->{invoice_xml}->{_metadata}->{tax_total}, $t7 + $t19, "tax total is right with new buchungsgruppe and same tax");

$tax_sum = sum map { $_->{amount} } @taxes;
is($res->{invoice_xml}->{_metadata}->{tax_total}, $tax_sum, "tax total equals sum of taxes with new buchungsgruppe and same tax");


clear_up([@new_taxzonecharts, $bg_waste, $customer]);

done_testing;

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
