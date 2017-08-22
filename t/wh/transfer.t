use strict;
use Test::More;

use lib 't';

use SL::Dev::Part qw(new_part);

use_ok 'Support::TestSetup';
use_ok 'SL::DB::Bin';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::Warehouse';
use_ok 'SL::WH';

use_ok('SL::DB::Inventory');

use constant NAME => 'UnitTestObject';

Support::TestSetup::login();

# Clean up: remove test objects for part, warehouse, bin
my $part = SL::DB::Manager::Part->get_first(partnumber => NAME(), description => NAME());
if ($part) {
  SL::DB::Manager::Inventory->delete_all(where => [ parts_id => $part->id ]);
  $part->delete;
}

SL::DB::Manager::Bin      ->delete_all(where => [ or => [ description => NAME() . "1", description => NAME() . "2" ] ]);
SL::DB::Manager::Warehouse->delete_all(where => [ description => NAME() ]);

# Create test data
$part = new_part(unit => 'mg', description => NAME(), partnumber => NAME())->save();

is(ref($part), 'SL::DB::Part', 'loading a part to test with id ' . $part->id);

my $wh = SL::DB::Warehouse->new(description => NAME(), invalid => 0);
$wh->save;
is(ref $wh, 'SL::DB::Warehouse', 'loading a warehouse to test with id ' . $wh->id);

my $bin1 = SL::DB::Bin->new(description => NAME() . "1", warehouse_id => $wh->id);
$bin1->save;
is(ref $bin1, 'SL::DB::Bin', 'getting first bin to test with id ' . $bin1->id);

my $bin2 = SL::DB::Bin->new(description => NAME() . "2", warehouse_id => $wh->id);
$bin2->save;
is(ref $bin2, 'SL::DB::Bin', 'getting another bin to test with id ' . $bin2->id);

my $report = sub {
  $::form->{l_warehouseid} = 'Y';
  $::form->{l_binid} = 'Y';
  my ($result) = WH->get_warehouse_report(
    warehouse_id => $wh->id,
    bin_id       => $bin1->id,
    partsid      => $part->id,
    chargenumber => '',
  );
  $result->{qty} ||= 0;
  return $result;
};

sub test (&@) {
  my ($arg_sub, @transfers) = @_;
  my $before = $report->();

  WH->transfer(@transfers);

  my $after  = $report->();
  my @args   = $arg_sub->($before, $after);

  is $args[0], $args[1], $args[2];
}

test { shift->{qty}, shift->{qty} + 4, 'transfer one way' } {
   transfer_type    => 'transfer',
   parts_id         => $part->id,
   src_warehouse_id => $wh->id,
   dst_warehouse_id => $wh->id,
   src_bin_id       => $bin1->id,
   dst_bin_id       => $bin2->id,
   qty              => 4,
   chargenumber     => '',
};

#################################################

test { shift->{qty}, shift->{qty} - 4, 'and back' } {
   transfer_type    => 'transfer',
   parts_id         => $part->id,
   src_warehouse_id => $wh->id,
   dst_warehouse_id => $wh->id,
   src_bin_id       => $bin2->id,
   dst_bin_id       => $bin1->id,
   qty              => 4,
   chargenumber     => '',
};

#################################################

test {shift->{qty}, shift->{qty} + 4000000000, 'transfer one way with unit'} {
   transfer_type    => 'transfer',
   parts_id         => $part->id,
   src_warehouse_id => $wh->id,
   dst_warehouse_id => $wh->id,
   src_bin_id       => $bin1->id,
   dst_bin_id       => $bin2->id,
   qty              => 4,
   unit             => 't',
   chargenumber     => '',
};

##############################################

use_ok 'SL::DB::TransferType';

# object interface test

test { shift->{qty}, shift->{qty} + 6.2, 'object transfer one way' } {
   transfer_type    => SL::DB::Manager::TransferType->find_by(description => 'transfer'),
   parts            => $part,
   src_bin          => $bin1,
   dst_bin          => $bin2,
   qty              => 6.2,
   chargenumber     => '',
};

#############################################

test { shift->{qty}, shift->{qty} - 6.2, 'full object transfer back' } {
   transfer_type    => SL::DB::Manager::TransferType->find_by(description => 'transfer'),
   parts            => $part,
   src_bin          => $bin2,
   src_warehouse    => $wh,
   dst_bin          => $bin1,
   dst_warehouse    => $wh,
   qty              => 6.2,
   chargenumber     => '',
};

#############################################

test { shift->{qty}, shift->{qty}, 'back and forth in one transaction' } {
   transfer_type    => SL::DB::Manager::TransferType->find_by(description => 'transfer'),
   parts            => $part,
   src_bin          => $bin2,
   src_warehouse    => $wh,
   dst_bin          => $bin1,
   dst_warehouse    => $wh,
   qty              => 1,
},
{
   transfer_type    => SL::DB::Manager::TransferType->find_by(description => 'transfer'),
   parts            => $part,
   src_bin          => $bin1,
   src_warehouse    => $wh,
   dst_bin          => $bin2,
   dst_warehouse    => $wh,
   qty              => 1,
};

#############################################

test { shift->{qty}, shift->{qty}, 'warehouse reduced interface' } {
   transfer_type    => SL::DB::Manager::TransferType->find_by(description => 'transfer'),
   parts            => $part,
   src_bin          => $bin2,
   dst_bin          => $bin1,
   qty              => 1,
},
{
   transfer_type    => SL::DB::Manager::TransferType->find_by(description => 'transfer'),
   parts            => $part,
   src_bin          => $bin1,
   dst_bin          => $bin2,
   qty              => 1,
};


SL::DB::Manager::Inventory->delete_objects(where => [parts_id => $part->id]);

$bin1->delete;
$bin2->delete;
$wh->delete;
$part->delete;

done_testing;

1;
