use strict;
use Test::More;

use lib 't';

use_ok 'Support::TestSetup';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::Warehouse';
use_ok 'SL::WH';

Support::TestSetup::login();

my $part = SL::DB::Manager::Part->get_first;
is(ref $part, 'SL::DB::Part', 'loading a part to test with id ' . $part->id);

my $wh = SL::DB::Manager::Warehouse->get_first;
is(ref $wh, 'SL::DB::Warehouse', 'loading a warehouse to test with id ' . $wh->id);

my $bin1 = $wh->bins->[0];
is(ref $bin1, 'SL::DB::Bin', 'getting first bin to test with id ' . $bin1->id);

my $bin2 = $wh->bins->[1];
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

my $r1 = $report->();

WH->transfer({
   transfer_type    => 'transfer',
   parts_id         => $part->id,
   src_warehouse_id => $wh->id,
   dst_warehouse_id => $wh->id,
   src_bin_id       => $bin1->id,
   dst_bin_id       => $bin2->id,
   qty              => 4,
   chargenumber     => '',
});

my $r2 = $report->();

is $r1->{qty}, $r2->{qty} + 4, 'transfer one way';

WH->transfer({
   transfer_type    => 'transfer',
   parts_id         => $part->id,
   src_warehouse_id => $wh->id,
   dst_warehouse_id => $wh->id,
   src_bin_id       => $bin2->id,
   dst_bin_id       => $bin1->id,
   qty              => 4,
   chargenumber     => '',
});


my $r3 = $report->();

is $r2->{qty}, $r3->{qty} - 4, 'and back';

done_testing;





1;
