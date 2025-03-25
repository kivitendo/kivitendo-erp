use strict;
use Test::More tests => 12;

use lib 't';

use SL::Dev::Part qw(new_part);
use SL::Dev::Inventory qw(create_warehouse_and_bins);
use SL::DB::Inventory;
use Support::TestSetup;

Support::TestSetup::login();

use_ok("SL::WH");

my ($wh, $bin, $part);

sub init  {
  ($wh, $bin) = create_warehouse_and_bins(
    warehouse_description => 'Test warehouse',
    bin_description       => 'Test bin',
    number_of_bins        => 1,
  );

  $part = new_part()->save->load;

  my $tt_used = SL::DB::Manager::TransferType->find_by(direction => 'out', description => 'used') or die;
  my $tt_in   = SL::DB::Manager::TransferType->find_by(direction => 'in', description => 'stock') or die;
  my $tt_assembled = SL::DB::Manager::TransferType->find_by(direction => 'in', description => 'assembled') or die;

  my %args = (
    trans_id     => 1,
    bin          => $bin,
    warehouse    => $wh,
    part         => $part,
    qty          => 1,
    employee     => SL::DB::Manager::Employee->current,
    shippingdate => DateTime->now,
  );

  local $::instance_conf->data->{transfer_default_ignore_onhand} = 1;

  SL::DB::Inventory->new(%args, trans_type => $tt_used, qty => -1)->save;
  SL::DB::Inventory->new(%args, trans_type => $tt_used, qty => -1)->save;
  SL::DB::Inventory->new(%args, trans_type => $tt_assembled, qty => 1)->save;

  local $::instance_conf->data->{transfer_default_ignore_onhand} = 0;
  $::locale                 = Locale->new('en');
  my $die_message;
  eval {
    SL::DB::Inventory->new(%args, trans_type => $tt_used, qty => -1)->save;

    1;
  } or do {
    $die_message = $@;
  };

  ok($die_message =~ m/Cannot transfer -1 qty.*/, 'catch negative stock');

  SL::DB::Inventory->new(%args, trans_type => $tt_in, qty => 4)->save;
  is(SL::Helper::Inventory::get_stock(part => $part), "3.00000", 'three stocked');
  SL::DB::Inventory->new(%args, trans_type => $tt_in, qty => 1, chargenumber => 'foo_charge')->save;
  is(SL::Helper::Inventory::get_stock(part => $part), "4.00000", 'four stocked');
  is(SL::Helper::Inventory::get_stock(part => $part, chargenumber => 'foo_charge'), "1.00000", 'one with charge');

  SL::DB::Inventory->new(%args, trans_type => $tt_in, qty => 1, bestbefore => DateTime->today)->save;
  is(SL::Helper::Inventory::get_stock(part => $part, bestbefore_eq => DateTime->today), "1.00000", 'one with bestbefore');

  # only one with chargenumber
  eval {
    SL::DB::Inventory->new(%args, trans_type => $tt_used, qty => -2, chargenumber => 'foo_charge')->save;

    1;
  } or do {
    $die_message = $@;
  };

  ok($die_message =~ m/Cannot transfer -2 qty.*/, 'catch negative stock');

  # only one with bestbefore
  eval {
    SL::DB::Inventory->new(%args, trans_type => $tt_used, qty => -2, bestbefore => DateTime->today)->save;

    1;
  } or do {
    $die_message = $@;
  };

  ok($die_message =~ m/Cannot transfer -2 qty.*/, 'catch negative stock');

  SL::DB::Inventory->new(%args, trans_type => $tt_used, qty => -1, bestbefore => DateTime->today)->save;
  is(SL::Helper::Inventory::get_stock(part => $part, bestbefore_eq => DateTime->today), "0.00000", 'one with bestbefore');

  qty                           => { type => 'numeric', precision => 25, scale => 5 },
  shippingdate                  => { type => 'date', not_null => 1 },
}

sub reset_inventory {
  SL::DB::Manager::Inventory->delete_all(all => 1);
}

reset_inventory();
init();

# l_date = Y
# l_warehouse_from = Y
# l_bin_from = Y
# l_warehouse_to = Y
# l_bin_to = Y
# l_partnumber = Y
# l_partdescription = Y
# l_chargenumber = Y
# l_trans_type = Y
# l_qty = Y
# l_oe_id = Y
# l_projectnumber = Y
# qty_op = dontcare


my @contents = WH->get_warehouse_journal(sort => 'date');

is $contents[0]{qty}, '1.00000', "produce assembly does not multiply qty (1)";
is $contents[1]{qty}, '1.00000', "produce assembly does not multiply qty (2)";
is $contents[2]{qty}, '1.00000', "produce assembly does not multiply qty (3)";

1;
