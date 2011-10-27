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


done_testing;

1;
