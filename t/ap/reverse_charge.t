use Test::More;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Support::Integration;

use SL::DB::ApGl;
use SL::DB::Chart;
use SL::DB::GLTransaction;
use SL::DB::PurchaseInvoice;
use SL::DB::RecordLink;
use SL::DB::Tax;
use SL::DB::Vendor;
use SL::DBUtils qw(selectall_hashref_query);
use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();
Support::Integration::setup();

# AP transactions with a reverse charge tax: the vendor gets the net
# amount, input and output tax are booked in a linked gl transaction

my $tax           = SL::DB::Manager::Tax->find_by(taxkey => 19, '!reverse_charge_chart_id' => undef) or die "no reverse charge tax";
my $expense_chart = SL::DB::Manager::Chart->find_by(accno => '3425') or die "no chart 3425";
my $vendor        = new_vendor(name => 'EU vendor AP')->save;

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

sub unlinked_reverse_charge_gl {
  my $query = <<SQL;
    SELECT COUNT(*) AS count
    FROM gl
    WHERE reference LIKE 'ap-rc-%'
      AND NOT EXISTS (SELECT 1 FROM ap_gl WHERE ap_gl.gl_id = gl.id)
SQL
  return selectall_hashref_query($::form, SL::DB->client->dbh, $query)->[0]->{count};
}

sub post_ap_transaction {
  my (%params) = @_;

  my ($out, $err, @ret) = make_request('ap', 'add');
  my %form = form_from_html($out);

  $form{vendor_id} = $vendor->id;
  $form{invnumber} = $params{invnumber};
  $form{rowcount}  = scalar @{ $params{amounts} } + 1;

  my $row = 1;
  foreach my $amount (@{ $params{amounts} }) {
    $form{"AP_amount_chart_id_$row"} = $expense_chart->id;
    $form{"amount_$row"}             = $amount;
    $form{"taxchart_$row"}           = $tax->id . '--' . $tax->rate;
    $row++;
  }

  delete $form{taxincluded}; # not allowed with reverse charge
  ($out, $err, @ret) = make_request('ap', 'update', %form);
  %form = form_from_html($out);
  delete $form{taxincluded};

  ($out, $err, @ret) = make_request('ap', 'post', %form);
  is $ret[0], 1, "posting $params{invnumber} does not generate error";
  warn $err if $err;

  my $invoice = SL::DB::Manager::PurchaseInvoice->find_by(invnumber => $params{invnumber});
  ok $invoice, "$params{invnumber} exists";

  return $invoice ? $invoice->id : undef;
}

#####
# one row

my $id = post_ap_transaction(invnumber => 'ap-rc-1', amounts => [ '100,00' ]);

is_deeply ap_bookings($id), [ [ '1600', 100, 0 ], [ '3425', -100, 19 ] ],
  'one row: net amount on expense chart with tax key 19, no tax chart';
is_deeply gl_bookings($id), [ [ '1574', -19 ], [ '1774', 19 ] ],
  'one row: linked gl transaction with input and output tax';

#####
# two rows, posted again: no gl transaction stays behind

my $id2 = post_ap_transaction(invnumber => 'ap-rc-2', amounts => [ '100,00', '50,00' ]);

is_deeply gl_bookings($id2), [ [ '1574', -19 ], [ '1574', -9.5 ], [ '1774', 9.5 ], [ '1774', 19 ] ],
  'two rows: one gl transaction per row';

my ($out) = make_request('ap', 'edit', id => $id2);
my %form = form_from_html($out);
delete $form{taxincluded};
my ($out2, $err2, @ret2) = make_request('ap', 'post', %form);
is $ret2[0], 1, 'posting two rows again does not generate error';

is_deeply gl_bookings($id2), [ [ '1574', -19 ], [ '1574', -9.5 ], [ '1774', 9.5 ], [ '1774', 19 ] ],
  'two rows posted again: same linked bookings';
is(unlinked_reverse_charge_gl(), 0, 'two rows posted again: no unlinked reverse charge transactions left');

#####

SL::DB::Manager::GLTransaction->delete_all(where => [ reference => { like => 'ap-rc-%' } ]);
SL::DB::Manager::ApGl->delete_all(all => 1);
SL::DB::Manager::RecordLink->delete_all(all => 1);
SL::DB::Manager::AccTransaction->delete_all(where => [ trans_id => [ grep { $_ } $id, $id2 ] ]);
SL::DB::Manager::PurchaseInvoice->delete_all(where => [ invnumber => { like => 'ap-rc-%' } ]);
$vendor->delete;

done_testing();

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
