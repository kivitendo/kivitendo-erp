use Test::More;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use Support::Integration;

use SL::DB::InvoiceItem;
use SL::DB::Part;
use SL::DB::PartsPriceHistory;
use SL::DB::PurchaseInvoice;
use SL::DB::Vendor;
use SL::DBUtils qw(selectall_hashref_query);
use SL::Dev::ALL qw(:ALL);

use_ok 'SL::IR';

Support::TestSetup::login();
Support::Integration::setup();

#####
my $part1 = new_part(
  sellprice => 10,
  lastcost  => 20,
)->save;
my $part2 = new_part(
  sellprice => 100,
  lastcost  => 200,
)->save;

my $description = "simple purchase invoice 1";
my $vendor      = new_vendor->save;
my $currency    = 'EUR';
my %form;

# make new invoice
my ($out, $err, @ret) = make_request('ir', 'add', type => 'invoice');
is $ret[0], 1, "new purchase invoice";
%form = form_from_html($out);

# set invnumber and currency
$form{invnumber} = $description;
$form{currency}  = $currency;

# set parts (part one is on pos 1 and 3 (!))
$form{partnumber_1}  = $part1->partnumber;
$form{sellprice_1} = 25;

# update
($out, $err, @ret) = make_request('ir', 'update', %form);
is $ret[0], 1, "update purchase invoice with part one";
%form = form_from_html($out);

$form{partnumber_2}  = $part2->partnumber;
$form{sellprice_2} = 250;

# update
($out, $err, @ret) = make_request('ir', 'update', %form);
is $ret[0], 1, "update purchase invoice with part two";
%form = form_from_html($out);

$form{partnumber_3}  = $part1->partnumber;
$form{sellprice_3} = 31;

# update
($out, $err, @ret) = make_request('ir', 'update', %form);
is $ret[0], 1, "update purchase invoice with three";
%form = form_from_html($out);

($out, $err, @ret) = make_request('ir', 'post', %form);
is $ret[0], 1, "posting '$description' does not generate error";
warn $err if $err;

ok $out =~ /ir\.pl\?action=edit&id=(\d+)/, "posting '$description' returns redirect to id";
my $id = $1;

######
my $query = 'SELECT * FROM parts_price_history ORDER BY valid_from DESC, id DESC;';
my $ref   = selectall_hashref_query($::form, $part1->db->dbh, $query);

# check if vendor and ap is set on the right price updates
is $ref->[0]->{part_id},   $part1->id,  "last price update: right part";
is $ref->[0]->{lastcost}, '31.00000',   "last price update: right lastcost";
is $ref->[0]->{vendor_id}, $vendor->id, "last price update: vendor is set";
is $ref->[0]->{ap_id},     $id,         "last price update: ap is set ($id)";

is $ref->[1]->{part_id},   $part2->id,  "second last price update: right part";
is $ref->[1]->{lastcost}, '250.00000',  "second last price update: right lastcost";
is $ref->[1]->{vendor_id}, $vendor->id, "second last price update: vendor is set";
is $ref->[1]->{ap_id},     $id,         "second last price update: ap is set ($id)";

is $ref->[2]->{part_id},   $part1->id,  "third last price update: right part";
is $ref->[2]->{lastcost}, '25.00000',   "third last price update: right lastcost";
is $ref->[2]->{vendor_id}, $vendor->id, "third last price update: vendor is set";
is $ref->[2]->{ap_id},     $id,         "third last price update: ap is set ($id)";

#####

# clear_up
SL::DB::Manager::PartsPriceHistory->delete_all(all => 1);
SL::DB::Manager::InvoiceItem->delete_all(all => 1);
SL::DB::Manager::PurchaseInvoice->delete_all(all => 1);
SL::DB::Manager::Part->delete_all(all => 1);
SL::DB::Manager::Vendor->delete_all(all => 1);

done_testing();

1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
