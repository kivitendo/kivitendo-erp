use strict;

use lib 't';

use Test::More;

use SL::Controller::BankTransaction;
use SL::DB::AccTransaction;
use SL::DB::BankTransaction;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Chart;
use SL::DB::Currency;
use SL::DB::Employee;
use SL::DB::Exchangerate;
use SL::DB::InvoiceItem;
use SL::DB::PurchaseInvoice;
use SL::DB::TaxZone;
use SL::DB::ValidityToken;
use SL::Dev::CustomerVendor qw(:ALL);
use SL::Dev::Part qw(:ALL);
use SL::Dev::Payment qw(:ALL);
use SL::Form;
use SL::Helper::Number qw(_format_number);
use SL::InstanceConfiguration;

use HTML::Query;
use Support::TestSetup;
use Support::Integration;

my $part;
my $vendor;
my $usd;
my $taxzone;
my $fxgain;
my $fxloss;
my $payment_terms;
my $dt;

sub reset_db {
  SL::DB::Manager::BankTransactionAccTrans->delete_all(all => 1);
  SL::DB::Manager::BankTransaction->delete_all(all => 1);
  SL::DB::Manager::AccTransaction->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Exchangerate->delete_all(all => 1);
  $usd->delete;
  $vendor->delete;
  $part->delete;
  $payment_terms->delete;
}

sub init_db {
  SL::DB::Manager::Exchangerate->delete_all(all => 1);
  $vendor = new_vendor->save;
  $part   = new_part->save;
  $usd    = SL::DB::Manager::Currency->find_by(name => 'USD') // SL::DB::Currency->new(name => 'USD')->save;
  $taxzone = SL::DB::Manager::TaxZone->find_by( description => 'Inland');
  $fxgain = SL::DB::Manager::Chart->find_by(accno => '2660');
  $fxloss = SL::DB::Manager::Chart->find_by(accno => '2150');
  $payment_terms = create_payment_terms();
  $dt    = DateTime->new(year => 1999, month => 1, day => 12);


  SL::DB::Default->get->update_attributes(
    fxgain_accno_id => $fxgain->id,
    fxloss_accno_id => $fxloss->id,
  )->load;
  # reload
  $::instance_conf = SL::InstanceConfiguration->new;

}

######## main test code #######

Support::TestSetup::login();
Support::Integration::setup();
init_db();

{
  my $description = "simple purchase invoice";
  #   vendor 1
  #   part 1
  my $currency = 'USD';
  my $exchangerate = 2.5;
  my $payment_exchangerate = 1.5;

  my %form;

  # make new invoice
  my ($out, $err, @ret) = make_request('ir', 'add', type => 'invoice');
  is $ret[0], 1, "new purchase invoice";
  %form = form_from_html($out);

  # set invnumber and currency
  $form{invnumber}    = $description;
  $form{currency}     = $currency;

  # update
  ($out, $err, @ret) = make_request('ir', 'update', %form);
  is $ret[0], 1, "update purchase invoice with currency";
  %form = form_from_html($out);

  # set part and exchangerate
  $form{exchangerate} = _format_number($exchangerate, -2);
  $form{partnumber_1} = $part->partnumber;

  # update
  ($out, $err, @ret) = make_request('ir', 'update', %form);
  is $ret[0], 1, "update purchase invoice with part and exchangerate";
  %form = form_from_html($out);

  # now set par, exchangerate and payments - this will cause the part to be loaded with the lastcost translated into USD
  $form{paid_1}           = _format_number($part->lastcost / $exchangerate, -2);  # lastcost = 5€ = 2$
  $form{exchangerate_1}   = _format_number($payment_exchangerate, -2);

  ($out, $err, @ret) = make_request('ir', 'post', %form);
  is $ret[0], 1, "posting '$description' does not generate error";
  warn $err if $err;
  ok $out =~ /ir\.pl\?action=edit&id=(\d+)/, "posting '$description' returns redirect to id";
  my $id = $1;

  ($out, $err, @ret) = make_request('ir', 'edit', id => $id );
  is $ret[0], 1, "'$description' did not cause an error";
  warn $err if $err;
  my $q = HTML::Query->new(text => $out);
  is $q->query('input[name=paid_1]')->size, 1, "out '$description' contains paid_1";
  is $q->query('input[name=paid_1]')->first->attr('value'), '2,00', "out '$description' paid_1 is 2,00 (the dollar amount, not the internal 5.00€)";

  is $q->query('#ui-tabs-basic-data th.invtotal')->first->as_text, 'Summe', "'$description' - total present";
  is $q->query('#ui-tabs-basic-data td.invtotal')->first->as_text, '2,38', "'$description' - total should be 2.00 * 1.19 = 2.38";
  is $q->query('#ui-tabs-basic-data input[name=oldtotalpaid]')->first->attr('value'), '2', "'$description' - totalpaid should be 2,00 in dollar, not the internal value";
};

{
  my $description = "ap transaction from redmine #563";
  #   20 on 4710 Verpackungsmaterial
  #   20 payment on 1000 kasse
  my $currency             = 'USD';
  my $exchangerate         = 1.1;
  my $payment_exchangerate = 1.3;
  my $chart                = SL::DB::Manager::Chart->find_by(accno => '4710');
  my %form;

  # make new ap transaction
  my ($out, $err, @ret) = make_request('ap', 'add');
  is $ret[0], 1, "new ap transaction";
  %form = form_from_html($out);

  # set chart, amount, currency, invnumber
  $form{AP_amount_chart_id_1} = $chart->id;
  $form{amount_1}             = 20;
  $form{currency}             = 'USD';
  $form{invnumber} = $description;

  # make new ap transaction
  ($out, $err, @ret) = make_request('ap', 'update', %form);
  is $ret[0], 1, "update ap transaction with currency";
  %form = form_from_html($out);

  # add exchangerate and payments
  $form{paid_1}                = 20;
  $form{exchangerate}    = _format_number($exchangerate, -2);
  $form{exchangerate_1}   = _format_number($payment_exchangerate, -2);

  ($out, $err, @ret) = make_request('ap', 'post', %form);
  is $ret[0], 1, "posting '$description' did not cause an error";

  my $invoice = SL::DB::Manager::PurchaseInvoice->find_by(invnumber => $description);
  ok $invoice, "posting '$description' can be found in the database";

  ($out, $err, @ret) = make_request('ap', 'edit', id => $invoice->id);
  is $ret[0], 1, "loading '$description' did not cause an error";
  warn $err if $err;

  my $q = HTML::Query->new(text => $out);
  is $q->query('input[name=paid_1]')->size, 1, "out '$description' contains paid_1";
  is $q->query('input[name=paid_1]')->first->attr('value'), '20,00', "out '$description' paid_1 is 20 (the dollar amount, not the internal amount)";
}

{
  my $testname     = 'ap_transaction_fx_gain_fees';
  my $usd_amount   = 83300;
  my $fx_rate      = 2;
  my $fx_rate_bank = 1.75;
  my $eur_amount   = $usd_amount * $fx_rate;

  my $netamount     = $eur_amount;
  my $amount        = $eur_amount;
  my $buysell       = 'sell';
  my $eur_payment   = $usd_amount * $fx_rate_bank;
  my $usd_payment   = $eur_payment / $fx_rate_bank; # for rounding issues

  my $bank              = SL::DB::Manager::Chart->find_by(description => 'Bank');
  my $bank_account = SL::DB::Manager::BankAccount->find_by(chart_id => $bank->id) // SL::DB::BankAccount->new(
    account_number => '123',
    bank_code      => '123',
    iban           => '123',
    bic            => '123',
    bank           => '123',
    chart_id       => $bank->id,
    name           => $bank->description,
  )->save;

  my $ex = SL::DB::Manager::Exchangerate->find_by(currency_id => $usd->id, transdate => $dt)
        ||              SL::DB::Exchangerate->new(currency_id => $usd->id, transdate   => $dt);
  $ex->update_attributes($buysell => $fx_rate);

  my $ap_chart = SL::DB::Manager::Chart->get_first(query => [ link => 'AP' ], sort_by => 'accno');
  my $ap_amount_chart = SL::DB::Manager::Chart->get_first(query => [ link => 'AP_amount' ], sort_by => 'accno');
  my $invoice   = SL::DB::PurchaseInvoice->new(
    invoice      => 0,
    invnumber    => $testname,
    amount       => $amount,
    netamount    => $netamount,
    transdate    => $dt,
    taxincluded  => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $usd->id,
    transactions => [],
    notes        => 'ap_transaction_fx',
  );
  $invoice->add_ap_amount_row(
    amount     => $netamount,
    chart      => $ap_amount_chart,
    tax_id     => 0,
  );

  $invoice->create_ap_row(chart => $ap_chart);
  $invoice->save;
  my $ap_transaction_fx = $invoice;

  # check exchangerate
  is($ap_transaction_fx->currency->name   , 'USD'     , "$testname: USD currency");
  is($ap_transaction_fx->get_exchangerate , '2.00000' , "$testname: fx rate record");
  my $bt = create_bank_transaction(record        => $ap_transaction_fx,
                                   bank_chart_id => $bank->id,
                                   transdate     => $dt,
                                   valutadate    => $dt,
                                   amount        => $eur_payment,
                                   exchangerate  => $fx_rate_bank,
                                  ) or die "Couldn't create bank_transaction";

  local $::form = Form->new;
  $::form->{invoice_ids} = {
    $bt->id => [ $ap_transaction_fx->id ]
  };
  $::form->{"book_fx_bank_fees_" . $bt->id . "_" . $ap_transaction_fx->id}  = 1;
  $::form->{"exchangerate_"      . $bt->id . "_" . $ap_transaction_fx->id}  = "1,75"; # will be parsed
  $::form->{"currency_id_"       . $bt->id . "_" . $ap_transaction_fx->id}  = $usd->id;

  my ($stdout, $stderr, @result);
  {
    open(my $out_fh, '>', \$stdout) or die;
    open(my $err_fh, '>', \$stderr) or die;

    local *STDOUT = $out_fh;
    local *STDERR = $err_fh;
    my $bt_controller = SL::Controller::BankTransaction->new;
    @result = $bt_controller->action_save_invoices;
  };
  ok !$stderr, "ap_transaction '$testname' can be booked with BackTransaction controller";

  $invoice = SL::DB::Manager::PurchaseInvoice->find_by(invnumber => $testname);

  # now load with old code
  my ($out, $err, @ret) = make_request('ap', 'edit', id => $invoice->id);
  is $ret[0], 1, "loading '$testname' did not cause an error";
  warn $err if $err;

  my $q = HTML::Query->new(text => $out);
  is $q->query('input[name=paid_1]')->size, 1, "out '$testname' contains paid_1";
  is $q->query('input[name=paid_1]')->first->attr('value'), _format_number($usd_payment, -2), "out '$testname' paid_1 is $usd_payment (the dollar amount, not the internal amount)";
}

reset_db();
done_testing();

1;
