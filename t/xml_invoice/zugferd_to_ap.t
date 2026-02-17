use Test::More;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use File::Find;
use File::Slurp;
use SL::ZUGFeRD;
use SL::DB::PurchaseInvoice;
use Data::Dumper;
use Support::TestSetup;
use SL::Dev::CustomerVendor qw(new_vendor);
use SL::Dev::Part qw(new_part);
use SL::DB::RecordTemplate;

Support::TestSetup::login();

File::Find::find(sub {
  return unless /(xml|pdf)$/;

#   diag "found file $_";
  test_file($_, SL::ZUGFeRD::RES_OK(), 0);
  test_file($_, SL::ZUGFeRD::RES_OK(), 1);
}, "t/xml_invoice/corpus");


sub test_file {
  my ($filename, $expect_error, $use_tax_totals) = @_;
  local $::instance_conf->data->{zugferd_ap_transaction_use_totals} = $use_tax_totals;

  open my $fh, '<', $filename or die "can't open $filename: $!";
  my $data = do { local $/ = undef; <$fh> };
  close $fh;

  my $res;

  SL::DB::Manager::Vendor->delete_all(all => 1);

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

  return if $res->{result} != SL::ZUGFeRD::RES_OK();

  my $invoice_xml = $res->{invoice_xml};

  if ($use_tax_totals) {
    # we need exactly one tax_total, because
    if (!$invoice_xml->metadata->{tax_totals} || 1 != @{ $invoice_xml->metadata->{tax_totals} }) {
      # diag "skipping $filename with use_tax_totals because it doesn't have exactly one tax_totals entry";
      return;
    }
  } else {
    my %tax_rates;
    $tax_rates{ $_->{tax_rate} }++ for @{ $invoice_xml->items };
    if (keys %tax_rates != 1) { # must have exactly one tax_rate
      # diag "skipping $filename with use_tax_totals because it doesn't have exactly one tax_totals entry";
      return;
    }
  }

  {
    local $TODO = "invoice parses, but contains warnings. likely missing XMP metadata";
    ok 0 == @{$res->{warnings}}, "$filename has no warnings.";
  }

  my $purchase_invoice = SL::DB::PurchaseInvoice->new;

  {
    # fake a vendor with ustid or iban:
    my $vendor = new_vendor();
    $vendor->ustid($invoice_xml->metadata->{ustid});
    $vendor->taxnumber($invoice_xml->metadata->{taxnumber});
    $vendor->save;

    # create a record template for those
    my $template = SL::DB::RecordTemplate->new(
      vendor_id     => $vendor->id,
      currency_id   => $::instance_conf->get_currency_id,
      template_name => 'test',
      template_type => 'ap_transaction',
    );


    my $tax    = SL::DB::Manager::Tax->find_by(rate => $invoice_xml->items->[0]{tax_rate} / 100);
    my $chart  = SL::DB::Manager::Chart->find_by(charttype => 'A', category => 'E'); # any expense type will do

    my $template_item = SL::DB::RecordTemplateItem->new(
      tax   => $tax,
      chart => $chart,
      amount1 => 1,
    );

    $template->items([$template_item]);
    $template->save;
  }

  lives_ok sub { $purchase_invoice->import_zugferd_data($invoice_xml) }, "import of $filename with use tax totals: $use_tax_totals";

  # check some basic things

  ok $purchase_invoice->transactions > 0, "purchase order has items";

  # compute sum over all items
  my $sum = 0;
  $sum += $_->{subtotal} for @{ $invoice_xml->items };
  is $purchase_invoice->netamount, $sum;
}

done_testing;

