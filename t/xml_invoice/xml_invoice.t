use Test::More;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use File::Find;
use File::Slurp;
use SL::ZUGFeRD;
use Data::Dumper;
use Support::TestSetup;

Support::TestSetup::login();

File::Find::find(sub {
  return unless /(xml|pdf)$/;

#   diag "found file $_";
  test_file($_, SL::ZUGFeRD::RES_OK());
}, "t/xml_invoice/corpus");


sub test_file {
  my ($filename, $expect_error) = @_;

  open my $fh, '<', $filename or die "can't open $filename: $!";
  my $data = do { local $/ = undef; <$fh> };
  close $fh;

  my $res;

  eval {
    if ($data =~ /^%PDF/) {
      $res = SL::ZUGFeRD->extract_from_pdf($data);
    } else {
      $res = SL::ZUGFeRD->extract_from_xml($data);
    }

    1;
  } or do {
    ok 0, "failure to parse $filename: $@";
    return;
  };

  is $res->{result}, $expect_error, "$filename: expected result $expect_error, got $res->{result} with message $res->{message}";
#   print Dumper($res);

  return if $res->{result} != SL::ZUGFeRD::RES_OK();

  {
    local $TODO = "invoice parses, but contains warnings. likely missing XMP metadata";
    ok 0 == @{$res->{warnings}}, "$filename has no warnings.";
  }

  ok $res->{invoice_xml}, "$filename has parsed xml data";

  my $invoice = $res->{invoice_xml};

  # minimal set of contents that should be present

  ok $invoice->metadata->{vendor_name}, "$filename contains vendor name";
  ok $invoice->metadata->{gross_total}, "$filename contains net_total";
  ok $invoice->metadata->{net_total}, "$filename contains net_total";
  ok $invoice->metadata->{transdate}, "$filename contains transdate";
  ok $invoice->metadata->{currency}, "$filename contains currency";

  ok $invoice->items, "$filename contains items";

  for my $item (@{ $invoice->items }) {
    ok $item->{price}, "item of $filename contains price";
    ok $item->{subtotal}, "item of $filename contains subtotal";
    ok $item->{tax_rate}, "item of $filename contains tax_rate";
    ok $item->{tax_scheme}, "item of $filename contains tax_scheme";
  }


}

done_testing;
