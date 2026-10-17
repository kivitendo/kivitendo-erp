use Test::More;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Support::Integration;

use SL::DB::ApGl;
use SL::DB::Buchungsgruppe;
use SL::DB::Chart;
use SL::DB::Employee;
use SL::DB::GLTransaction;
use SL::DB::InvoiceItem;
use SL::DB::Part;
use SL::DB::PurchaseInvoice;
use SL::DB::RecordLink;
use SL::DB::Tax;
use SL::DB::TaxKey;
use SL::DB::TaxZone;
use SL::DB::TaxzoneChart;
use SL::DB::Vendor;
use SL::DBUtils qw(selectall_hashref_query);
use SL::Dev::ALL qw(:ALL);
use SL::Helper::ReverseCharge;
use SL::IR;

Support::TestSetup::login();
Support::Integration::setup();

my ($tax, $taxzone, $buchungsgruppe, $expense_chart, $old_expense_chart_id, $taxkey);
my ($part, $service, $vendor);

sub setup {
  clear_up();

  # intra-community acquisition: expense chart with a reverse charge tax
  $tax            = SL::DB::Manager::Tax->find_by(taxkey => 19, '!reverse_charge_chart_id' => undef) or die "no reverse charge tax";
  $taxzone        = SL::DB::Manager::TaxZone->find_by(description => 'EU mit USt-ID Nummer')       or die "no taxzone";
  $buchungsgruppe = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%')         or die "no buchungsgruppe";
  $expense_chart  = SL::DB::Manager::Chart->find_by(accno => '3425')                                 or die "no chart 3425";

  my $taxzone_chart     = SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone->id, buchungsgruppen_id => $buchungsgruppe->id);
  $old_expense_chart_id = $taxzone_chart->expense_accno_id;
  $taxzone_chart->update_attributes(expense_accno_id => $expense_chart->id);

  SL::DB::Manager::TaxKey->delete_all(where => [ chart_id => $expense_chart->id, tax_id => $tax->id ]);
  $taxkey = SL::DB::TaxKey->new(
    chart_id  => $expense_chart->id,
    tax_id    => $tax->id,
    taxkey_id => $tax->taxkey,
    startdate => DateTime->new(year => 2000, month => 1, day => 1),
  )->save;
  SL::DB::Manager::Chart->clear_cache if SL::DB::Manager::Chart->can('clear_cache');

  $vendor  = new_vendor(name => 'EU vendor', taxzone_id => $taxzone->id)->save;
  $part    = new_part(   partnumber => 'rc-part',    buchungsgruppen_id => $buchungsgruppe->id)->save;
  $service = new_service(partnumber => 'rc-service', buchungsgruppen_id => $buchungsgruppe->id)->save;
}

sub gl_bookings {
  my ($ap_id) = @_;

  my $query = <<SQL;
    SELECT c.accno, ac.amount
    FROM ap_gl x
    JOIN acc_trans ac ON (ac.trans_id = x.gl_id)
    JOIN chart c      ON (c.id = ac.chart_id)
    WHERE x.ap_id = ?
    ORDER BY c.accno, ac.amount
SQL
  return [ map { [ $_->{accno}, $_->{amount} * 1 ] } @{ selectall_hashref_query($::form, SL::DB->client->dbh, $query, $ap_id) } ];
}

sub ap_bookings {
  my ($ap_id) = @_;

  my $query = <<SQL;
    SELECT c.accno, ac.amount, ac.taxkey
    FROM acc_trans ac
    JOIN chart c ON (c.id = ac.chart_id)
    WHERE ac.trans_id = ?
    ORDER BY c.accno, ac.amount
SQL
  return [ map { [ $_->{accno}, $_->{amount} * 1, $_->{taxkey} ] } @{ selectall_hashref_query($::form, SL::DB->client->dbh, $query, $ap_id) } ];
}

sub post_purchase_invoice {
  my (%params) = @_;

  my ($out, $err, @ret) = make_request('ir', 'add', type => 'invoice');
  my %form = form_from_html($out);

  $form{vendor_id}  = $vendor->id;
  $form{taxzone_id} = $taxzone->id;
  $form{invnumber}  = $params{invnumber};
  $form{currency}   = 'EUR';

  ($out, $err, @ret) = make_request('ir', 'update', %form);
  %form = form_from_html($out);

  my $row = 1;
  foreach my $line (@{ $params{lines} }) {
    $form{"partnumber_$row"} = $line->[0]->partnumber;
    $form{"sellprice_$row"}  = $line->[1];
    ($out, $err, @ret) = make_request('ir', 'update', %form);
    %form = form_from_html($out);
    $row++;
  }

  ($out, $err, @ret) = make_request('ir', 'post', %form);
  is $ret[0], 1, "posting $params{invnumber} does not generate error";
  warn $err if $err;

  my ($id) = $out =~ /ir\.pl\?action=edit&id=(\d+)/;
  ok $id, "posting $params{invnumber} returns redirect to id";

  return $id;
}

setup();

#####
# purchase invoice: vendor gets the net amount, input and output tax booked separately

my $id      = post_purchase_invoice(invnumber => 'rc-1', lines => [ [ $part, 100 ], [ $service, 50 ] ]);
my $invoice = SL::DB::PurchaseInvoice->new(id => $id)->load;

is $invoice->amount    * 1, 150, 'invoice amount is the net amount';
is $invoice->netamount * 1, 150, 'invoice netamount';

is_deeply ap_bookings($id), [ [ '1600', 150, 0 ], [ '3425', -150, 19 ] ],
  'invoice books net expense with tax key 19, no tax charts';

is_deeply gl_bookings($id), [ [ '1574', -28.5 ], [ '1774', 28.5 ] ],
  'reverse charge transaction books input and output tax';

is(SL::DB::Manager::RecordLink->get_all_count(where => [ from_table => 'ap', from_id => $id, to_table => 'gl' ]), 1,
  'record link from invoice to reverse charge transaction');

# the form shows the reverse charge tax, not included in the total
my ($out) = make_request('ir', 'edit', id => $id);
my %form  = form_from_html($out);
like   $out, qr/(?:Reverse Charge, nicht im Rechnungsbetrag|reverse charge, not part of the total)/, 'form marks the reverse charge tax';
like   $out, qr/28,50/,  'form shows reverse charge tax amount';
unlike $out, qr/178,50/, 'form does not add the reverse charge tax to the total';

#####
# post again: old reverse charge transaction is replaced

$form{sellprice_1} = 200;
my ($out2, $err2, @ret2) = make_request('ir', 'post', %form);
is $ret2[0], 1, 'posting again does not generate error';
warn $err2 if $err2;

is_deeply gl_bookings($id), [ [ '1574', -47.5 ], [ '1774', 47.5 ] ],
  'posting again replaces the reverse charge transaction';
is(SL::DB::Manager::ApGl->get_all_count(where => [ ap_id => $id ]), 1, 'still one reverse charge transaction');

#####
# storno: reverse charge transaction with reversed amounts

($out) = make_request('ir', 'edit', id => $id);
%form  = form_from_html($out);
my ($out3, $err3, @ret3) = make_request('ir', 'storno', %form);
is $ret3[0], 1, 'storno does not generate error';
warn $err3 if $err3;

my $storno = SL::DB::Manager::PurchaseInvoice->find_by(storno_id => $id);
ok $storno, 'storno invoice exists';
is_deeply gl_bookings($storno->id), [ [ '1574', 47.5 ], [ '1774', -47.5 ] ],
  'storno reverses input and output tax';
is_deeply gl_bookings($id), [ [ '1574', -47.5 ], [ '1774', 47.5 ] ],
  'original reverse charge transaction stays';

#####
# delete: reverse charge transaction is deleted, too

# same price as the last cost: no price history entry, which would block deleting
my $id_to_delete = post_purchase_invoice(invnumber => 'rc-2', lines => [ [ $service, 50 ] ]);
my $gl_id        = SL::DB::Manager::ApGl->find_by(ap_id => $id_to_delete)->gl_id;

my $delete_form = Form->new('');
$delete_form->{id} = $id_to_delete;
ok(IR->delete_invoice(\%::myconfig, $delete_form), 'invoice with reverse charge can be deleted');
is(SL::DB::Manager::GLTransaction->get_all_count(where => [ id => $gl_id ]), 0, 'reverse charge transaction is deleted');

#####
# helper: several entries, posting again replaces all of them

my $ap = create_minimal_purchase_invoice(vendor => $vendor, invnumber => 'rc-helper');
my %params = (ap_id => $ap->id, transdate => DateTime->today_local->to_kivitendo, reference => 'rc-helper');

SL::Helper::ReverseCharge->post_bookings(%params, entries => [ { tax => $tax, taxamount => 19 }, { tax => $tax, taxamount => 1.9 } ]);
is(SL::DB::Manager::ApGl->get_all_count(where => [ ap_id => $ap->id ]), 2, 'one transaction per entry');

SL::Helper::ReverseCharge->post_bookings(%params, entries => [ { tax => $tax, taxamount => 19 }, { tax => $tax, taxamount => 1.9 } ]);
is(SL::DB::Manager::ApGl->get_all_count(where => [ ap_id => $ap->id ]), 2, 'posting again replaces all transactions');
is_deeply gl_bookings($ap->id), [ [ '1574', -19 ], [ '1574', -1.9 ], [ '1774', 1.9 ], [ '1774', 19 ] ],
  'amounts of both transactions';

SL::Helper::ReverseCharge->post_bookings(%params, entries => [ { tax => $tax, taxamount => 0.001 } ]);
is(SL::DB::Manager::ApGl->get_all_count(where => [ ap_id => $ap->id ]), 0, 'zero amounts are skipped');

# a link to another gl transaction set by hand stays
my $manual_gl = SL::DB::GLTransaction->new(
  employee_id => SL::DB::Manager::Employee->current->id,
  transdate   => DateTime->today_local,
  reference   => 'rc-manual',
  description => 'manual',
  taxincluded => 0,
)->add_chart_booking(chart => $expense_chart,                                   debit  => 10, tax_id => 0)
 ->add_chart_booking(chart => SL::DB::Manager::Chart->find_by(accno => '1200'), credit => 10, tax_id => 0)
 ->post;
SL::DB::RecordLink->new(from_table => 'ap', from_id => $ap->id, to_table => 'gl', to_id => $manual_gl->id)->save;

SL::Helper::ReverseCharge->post_bookings(%params, entries => [ { tax => $tax, taxamount => 19 } ]);
SL::Helper::ReverseCharge->delete_bookings($ap->id);
is(SL::DB::Manager::RecordLink->get_all_count(where => [ from_table => 'ap', from_id => $ap->id, to_table => 'gl', to_id => $manual_gl->id ]), 1,
  'links to other gl transactions stay');
is(SL::DB::Manager::ApGl->get_all_count(where => [ ap_id => $ap->id ]), 0, 'delete_bookings removes all transactions');

#####
# price tax calculator (new invoice controller): no tax on the amount, net amount by tax

my $record = SL::DB::PurchaseInvoice->new(
  vendor_id    => $vendor->id,
  taxzone_id   => $taxzone->id,
  currency_id  => $::instance_conf->get_currency_id,
  transdate    => DateTime->today_local,
  invoice      => 1,
  record_type  => 'purchase_invoice',
  invoiceitems => [ SL::DB::InvoiceItem->new(parts_id => $service->id, qty => 2, sellprice => 50, unit => $service->unit, description => 'x') ],
);
my %data = $record->calculate_prices_and_taxes;

is $record->amount    * 1, 100, 'calculator: amount without tax';
is $record->netamount * 1, 100, 'calculator: netamount';
is_deeply $data{taxes_by_tax_id},          {},                  'calculator: no taxes';
is_deeply $data{reverse_charge_by_tax_id}, { $tax->id => 100 }, 'calculator: net amount for the reverse charge tax';

$ap->post_reverse_charge_bookings($data{reverse_charge_by_tax_id});
is_deeply gl_bookings($ap->id), [ [ '1574', -19 ], [ '1774', 19 ] ], 'purchase invoice books input and output tax';

clear_up();

done_testing();

sub clear_up {
  SL::DB::Manager::GLTransaction->delete_all(where => [ id => [ map { $_->gl_id } @{ SL::DB::Manager::ApGl->get_all } ] ])
    if SL::DB::Manager::ApGl->get_all_count;
  SL::DB::Manager::ApGl->delete_all(all => 1);
  SL::DB::Manager::GLTransaction->delete_all(where => [ reference => 'rc-manual' ]);
  SL::DB::Manager::RecordLink->delete_all(all => 1);
  SL::DB::Manager::PartsPriceHistory->delete_all(all => 1);
  SL::DB::Manager::InvoiceItem->delete_all(all => 1);
  SL::DB::Manager::AccTransaction->delete_all(all => 1);
  SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);

  $taxkey->delete if $taxkey;
  undef $taxkey;
  if ($old_expense_chart_id) {
    SL::DB::Manager::TaxzoneChart->find_by(taxzone_id => $taxzone->id, buchungsgruppen_id => $buchungsgruppe->id)
      ->update_attributes(expense_accno_id => $old_expense_chart_id);
    undef $old_expense_chart_id;
  }
}

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
