use Test::More tests => 4;

use strict;
use constant true => 1;

use lib 't';

use File::Spec;
use File::Temp qw(tempdir);

use_ok 'SL::Helper::QrBill';

my $amount = sprintf "%.2f", 1949.75;

my @hrefs = (
  { iban => 'CH4431999123000889012' },
  { address_type => 'S',
    company => 'Max Muster & Söhne',
    street => 'Musterstrasse',
    street_no => '123',
    postalcode => '8000',
    city => 'Seldwyla',
    countrycode => 'CH' },
  { amount => $amount,
    currency => 'CHF' },
  { address_type => 'K',
    name => 'Simon Muster',
    address_row1 => 'Musterstrasse 1',
    address_row2 => '8000 Seldwyla',
    countrycode => 'CH' },
  { type => 'QRR',
    ref_number => '210000000003139471430009017' },
  { unstructured_message => 'Auftrag vom 15.10.2020' },
);

eval { SL::Helper::QrBill->new(@hrefs); };
ok(!$@, 'new()');

my $tmpdir   = tempdir(CLEANUP => true);
my $out_file = File::Spec->catfile($tmpdir, 'out.png');

eval { SL::Helper::QrBill->new(@hrefs)->generate($out_file); };
ok(!$@, 'generate()');

ok(-e $out_file && -s _, '$out_file written');
