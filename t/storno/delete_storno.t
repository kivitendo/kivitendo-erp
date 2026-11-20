use Test::More;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Support::Integration;

use SL::AP;
use SL::AR;
use SL::DB::Invoice;
use SL::DB::InvoiceItem;
use SL::DB::PartsPriceHistory;
use SL::DB::PurchaseInvoice;
use SL::Dev::ALL qw(:ALL);
use SL::Form;

Support::TestSetup::login();
Support::Integration::setup();

clear_up();

# deleting a storno must reset the cancelled record, so that it is open again

#####
# purchase invoice (ir.pl)
my $part   = new_part(lastcost => 20)->save;
my $vendor = new_vendor->save;
my %form;

my ($out, $err, @ret) = make_request('ir', 'add', type => 'invoice');
%form = form_from_html($out);
$form{vendor_id}    = $vendor->id;
$form{invnumber}    = 'storno purchase invoice';
$form{currency}     = 'EUR';
$form{partnumber_1} = $part->partnumber;
$form{sellprice_1}  = 20;

($out, $err, @ret) = make_request('ir', 'update', %form);
%form = form_from_html($out);

($out, $err, @ret) = make_request('ir', 'post', %form);
ok $out =~ /ir\.pl\?action=edit&id=(\d+)/, "purchase invoice posted";
my $id = $1;

($out, $err, @ret) = make_request('ir', 'edit', id => $id);
%form = form_from_html($out);
($out, $err, @ret) = make_request('ir', 'storno', %form);
ok $out =~ /ir\.pl\?action=edit&id=(\d+)/, "purchase invoice cancelled";
my $storno_id = $1;

my $invoice = SL::DB::PurchaseInvoice->new(id => $id)->load;
ok  $invoice->storno,                                 "purchase invoice is marked as cancelled";
is  $invoice->paid * 1, $invoice->amount * 1,         "purchase invoice is marked as paid";

($out, $err, @ret) = make_request('ir', 'edit', id => $storno_id);
%form = form_from_html($out);
($out, $err, @ret) = make_request('ir', 'yes', %form);

ok !SL::DB::Manager::PurchaseInvoice->find_by(id => $storno_id), "purchase storno is deleted";
$invoice->load;
ok !$invoice->storno,                                 "purchase invoice is no longer cancelled";
is  $invoice->paid * 1, 0,                            "purchase invoice is open again";

#####
# ap transaction (ap.pl) and ar transaction (ar.pl)
for my $case (
  [ 'AP', 'SL::DB::Manager::PurchaseInvoice', create_ap_transaction(invnumber => 'storno ap transaction') ],
  [ 'AR', 'SL::DB::Manager::Invoice',         create_ar_transaction(invnumber => 'storno ar transaction') ],
) {
  my ($module, $manager, $transaction) = @$case;

  my $form = Form->new;
  $form->{id} = $transaction->id;
  $module->storno($form, \%::myconfig, $transaction->id);

  my $storno = $manager->find_by(storno_id => $transaction->id);
  ok $storno, "$module storno created";
  $transaction->load;
  ok $transaction->storno, "$module transaction is marked as cancelled";

  $form = Form->new;
  $form->{id} = $storno->id;
  $module->delete_transaction(\%::myconfig, $form);

  ok !$manager->find_by(id => $storno->id), "$module storno is deleted";
  $transaction->load;
  ok !$transaction->storno,  "$module transaction is no longer cancelled";
  is  $transaction->paid * 1, 0, "$module transaction is open again";
}

clear_up();

done_testing();

sub clear_up {
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::PartsPriceHistory->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
}

1;
