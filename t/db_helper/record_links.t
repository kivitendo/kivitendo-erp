use Test::More tests => 66;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;
use Test::Deep qw(cmp_bag);
use List::Util qw(max);

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::TaxZone;

my ($customer, $currency_id, $buchungsgruppe, $employee, $vendor, $taxzone);
my ($link, $links, $o1, $o2, $d, $i);

sub clear_up {
  SL::DB::Manager::DeliveryOrder->delete_all(all => 1);
  SL::DB::Manager::Order->delete_all(all => 1);
  SL::DB::Manager::Invoice->delete_all(all => 1);
  SL::DB::Manager::Part->delete_all(all => 1);
  SL::DB::Manager::Customer->delete_all(all => 1);
  SL::DB::Manager::Vendor->delete_all(all => 1);
};

sub reset_state {
  my %params = @_;

  $params{$_} ||= {} for qw(buchungsgruppe unit customer part tax);

  clear_up();

  $buchungsgruppe  = SL::DB::Manager::Buchungsgruppe->find_by(description => 'Standard 19%', %{ $params{buchungsgruppe} }) || croak "No accounting group";
  $employee        = SL::DB::Manager::Employee->current                                                                    || croak "No employee";
  $taxzone         = SL::DB::Manager::TaxZone->find_by( description => 'Inland')                                           || croak "No taxzone";

  $currency_id     = $::instance_conf->get_currency_id;

  $customer     = SL::DB::Customer->new(
    name        => 'Test Customer',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    %{ $params{customer} }
  )->save;

  $vendor     = SL::DB::Vendor->new(
    name        => 'Test Vendor',
    currency_id => $currency_id,
    taxzone_id  => $taxzone->id,
    %{ $params{vendor} }
  )->save;
}

sub new_order {
  my %params  = @_;

  return SL::DB::Order->new(
    customer_id => $customer->id,
    currency_id => $currency_id,
    employee_id => $employee->id,
    salesman_id => $employee->id,
    taxzone_id  => $taxzone->id,
    quotation   => 0,
    %params,
  )->save;
}

sub new_delivery_order {
  my %params  = @_;

  return SL::DB::DeliveryOrder->new(
    customer_id => $customer->id,
    currency_id => $currency_id,
    employee_id => $employee->id,
    salesman_id => $employee->id,
    taxzone_id  => $taxzone->id,
    order_type => SALES_DELIVERY_ORDER_TYPE,
    %params,
  )->save;
}

sub new_invoice {
  my %params  = @_;

  return SL::DB::Invoice->new(
    customer_id => $customer->id,
    currency_id => $currency_id,
    employee_id => $employee->id,
    salesman_id => $employee->id,
    gldate      => DateTime->today_local->to_kivitendo,
    invoice     => 1,
    taxzone_id  => $taxzone->id,
    type        => 'invoice',
    %params,
  )->save;
}

Support::TestSetup::login();

reset_state();

$o1 = new_order();
$i  = new_invoice();

$link = $o1->link_to_record($i);

# try to add a link
is ref $link, 'SL::DB::RecordLink', 'link_to_record returns new link';
is $link->from_table, 'oe', 'from_table';
is $link->from_id, $o1->id, 'from_id';
is $link->to_table, 'ar', 'to_table';
is $link->to_id, $i->id, 'to_id';

# retrieve link
$links = $o1->linked_records;
is $links->[0]->id, $i->id, 'simple retrieve';

$links = $o1->linked_records(direction => 'to', to => 'Invoice');
is $links->[0]->id, $i->id, 'direct retrieve 1';

$links = $o1->linked_records(direction => 'to', to => 'SL::DB::Invoice');
is $links->[0]->id, $i->id, 'direct retrieve 2 (with SL::DB::)';

$links = $o1->linked_records(direction => 'to', to => [ 'Invoice', 'Order' ]);
is $links->[0]->id, $i->id, 'direct retrieve 3 (array target)';

$links = $o1->linked_records(direction => 'both', both => 'Invoice');
is $links->[0]->id, $i->id, 'direct retrieve 4 (direction both)';

$links = $i->linked_records(direction => 'from', from => 'Order');
is $links->[0]->id, $o1->id, 'direct retrieve 4 (direction from)';

# what happens if we delete a linked record?
$o1->delete;

$links = $i->linked_records(direction => 'from', from => 'Order');
is @$links, 0, 'no dangling link after delete';

# can we distinguish between types?
$o1 = new_order(quotation => 1);
$o2 = new_order();
$o1->link_to_record($o2);

$links = $o2->linked_records(direction => 'from', from => 'Order', query => [ quotation => 1 ]);
is $links->[0]->id, $o1->id, 'query restricted retrieve 1';

$links = $o2->linked_records(direction => 'from', from => 'Order', query => [ quotation => 0 ]);
is @$links, 0, 'query restricted retrieve 2';

# try bidirectional linking
$o1 = new_order();
$o2 = new_order();
$o1->link_to_record($o2, bidirectional => 1);

$links = $o1->linked_records(direction => 'to', to => 'Order');
is $links->[0]->id, $o2->id, 'bidi 1';
$links = $o1->linked_records(direction => 'from', from => 'Order');
is $links->[0]->id, $o2->id, 'bidi 2';
$links = $o1->linked_records(direction => 'both', both => 'Order');
is $links->[0]->id, $o2->id, 'bidi 3';

# funky stuff with both
#
$d = new_delivery_order();
$i = new_invoice();

$o2->link_to_record($d);
$d->link_to_record($i);
# at this point the structure is:
#
#   o1 <--> o2 ---> d ---> i
#

$links = $d->linked_records(direction => 'both', to => 'Invoice', from => 'Order', sort_by => 'customer_id', sort_dir => 1);
is $links->[0]->id, $o2->id, 'both with different from/to 1';
is $links->[1]->id, $i->id,  'both with different from/to 2';

# what happens if we double link?
#
$o2->link_to_record($d);

$links = $o2->linked_records(direction => 'to', to => 'DeliveryOrder');
is @$links, 1, 'double link is only added once 1';

$d->link_to_record($o2, bidirectional => 1);
# at this point the structure is:
#
#   o1 <--> o2 <--> d ---> i
#

$links = $o2->linked_records(direction => 'to', to => 'DeliveryOrder');
is @$links, 1, 'double link is only added once 2';

# doc states that to/from ae optional. test that
$links = $o2->linked_records(direction => 'both');
is @$links, 2, 'links without from/to get all';

# doc states you can limit with direction when giving excess params
$links = $d->linked_records(direction => 'to', to => 'Invoice', from => 'Order');
is $links->[0]->id, $i->id, 'direction to limit params  1';
is @$links, 1, 'direction to limit params 2';

# doc says there will be special values set... lets see
$links = $o1->linked_records(direction => 'to', to => 'Order');
is $links->[0]->{_record_link_direction}, 'to',  '_record_link_direction to';
is $links->[0]->{_record_link}->to_id, $o2->id,  '_record_link to';

$links = $o1->linked_records(direction => 'from', from => 'Order');
is $links->[0]->{_record_link_direction}, 'from',  '_record_link_direction from';
is $links->[0]->{_record_link}->to_id, $o1->id,  '_record_link from';

# check if bidi returns an array of links even if aready existing
my @links = $d->link_to_record($o2, bidirectional => 1);
# at this point the structure is:
#
#   o1 <--> o2 <--> d ---> i
#
is @links, 2, 'bidi returns array of links in array context';

#  via
$links = $o2->linked_records(direction => 'to', to => 'Invoice', via => 'DeliveryOrder');
is $links->[0]->id, $i->id,  'simple case via links (string)';

$links = $o2->linked_records(direction => 'to', to => 'Invoice', via => [ 'DeliveryOrder' ]);
is $links->[0]->id, $i->id,  'simple case via links (arrayref)';

$links = $o1->linked_records(direction => 'to', to => 'Invoice', via => [ 'Order', 'DeliveryOrder' ]);
is $links->[0]->id, $i->id,  'simple case via links (2 hops)';

# multiple links in the same direction from one object
$o1->link_to_record($d);
# at this point the structure is:
#
#   o1 <--> o2 <--> d ---> i
#     \____________,^
#

$links = $o2->linked_records(direction => 'to', to => 'Invoice', via => 'DeliveryOrder');
is $links->[0]->id, $i->id,  'simple case via links (string)';


# o1 must have 2 linked records now:
$links = $o1->linked_records(direction => 'to');
is @$links, 2,  'more than one link';

# as a special funny case, o1 via Order, Order will now yield o2, because it bounces back over itself
{ local $TODO = 'no idea if this is desired';
$links = $o2->linked_records(direction => 'to', to => 'Order', via => [ 'Order', 'Order' ]);
is @$links, 2,  'via links with bidirectional hop over starting object';
}

# for sorting, get all don't bother with the links, we'll just take our records
my @records = ($o2, $i, $o1, $d);
my $sorted;
$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('type', 1, @records);
is_deeply $sorted, [$o1, $o2, $d, $i], 'sorting by type';
$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('type', 0, @records);
is_deeply $sorted, [$i, $d, $o2, $o1], 'sorting by type desc';

$d->donumber(1);
$o1->ordnumber(2);
$i->invnumber(3);
$o2->ordnumber(4);

$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('number', 1, @records);
is_deeply $sorted, [$d, $o1, $i, $o2], 'sorting by number';
$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('number', 0, @records);
is_deeply $sorted, [$o2, $i, $o1, $d], 'sorting by number desc';

# again with natural sorting
$d->donumber("a1");
$o1->ordnumber("a3");
$i->invnumber("a7");
$o2->ordnumber("a10");

$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('number', 1, @records);
is_deeply $sorted, [$d, $o1, $i, $o2], 'sorting naturally by number';
$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('number', 0, @records);
is_deeply $sorted, [$o2, $i, $o1, $d], 'sorting naturally by number desc';

$o2->transdate(DateTime->new(year => 2010, month => 3, day => 1));
$i->transdate(DateTime->new(year => 2014, month => 3, day => 19));
$o1->transdate(DateTime->new(year => 2014, month => 5, day => 1));
$d->transdate(DateTime->new(year => 2014, month => 5, day => 2));

# transdate should be used before itime
$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('date', 1, @records);
is_deeply $sorted, [$o2, $i, $o1, $d], 'sorting by transdate';
$sorted = SL::DB::Helper::LinkedRecords->sort_linked_records('date', 0, @records);
is_deeply $sorted, [$d, $o1, $i, $o2], 'sorting by transdate desc';

# now recursive stuff 2, with backlinks
$links = $o1->linked_records(direction => 'to', recursive => 1, save_path => 1);
is @$links, 4, 'recursive finds all 4 (backlink to self because of bidi o1<->o2)';

# because of the link o1->d the longest path should be legth 2. test that
is max(map { $_->{_record_link_depth} } @$links), 2, 'longest path is 2';

$links = $o2->linked_records(direction => 'to', recursive => 1);
is @$links, 4, 'recursive from o2 finds 4';

$links = $o1->linked_records(direction => 'from', recursive => 1, save_path => 1);
is @$links, 3, 'recursive from o1 finds 3 (not i)';

$links = $i->linked_records(direction => 'from', recursive => 1, save_path => 1);
is @$links, 3, 'recursive from i finds 3 (not i)';

$links = $o1->linked_records(direction => 'both', recursive => 1, save_path => 1);
is @$links, 4, 'recursive dir=both does not give duplicates';


# test batch mode
#
#
#

reset_state();

$o1 = new_order();
$o2 = new_order();
my $i1 = new_invoice();
my $i2 = new_invoice();

$o1->link_to_record($i1);
$o2->link_to_record($i2);

$links = $o1->linked_records(direction => 'to', to => 'Invoice', batch => [ $o1->id, $o2->id ]);
is_deeply [ map { $_->id } @$links ], [ $i1->id , $i2->id ], "batch works";

$links = $o1->linked_records(direction => 'to', recursive => 1, batch => [ $o1->id, $o2->id ]);
cmp_bag [ map { $_->id } @$links ], [ $i1->id , $i2->id ], "batch works recursive";

$links = $o1->linked_records(direction => 'to', to => 'Invoice', batch => [ $o1->id, $o2->id ], by_id => 1);
# $::lxdebug->dump(0,  "links", $links);
is @{ $links->{$o1->id} }, 1, "batch by_id 1";
is @{ $links->{$o2->id} }, 1, "batch by_id 2";
is keys %$links, 2, "batch by_id 3";
is $links->{$o1->id}[0]->id, $i1->id, "batch by_id 4";
is $links->{$o2->id}[0]->id, $i2->id, "batch by_id 5";

$links = $o1->linked_records(direction => 'to', recursive => 1, batch => [ $o1->id, $o2->id ], by_id => 1);
is @{ $links->{$o1->id} }, 1, "batch recursive by_id 1";
is @{ $links->{$o2->id} }, 1, "batch recursive by_id 2";
is keys %$links, 2, "batch recursive by_id 3";
is $links->{$o1->id}[0]->id, $i1->id, "batch recursive by_id 4";
is $links->{$o2->id}[0]->id, $i2->id, "batch recursive by_id 5";

$links = $o1->linked_records(direction => 'both', recursive => 1, batch => [ $o1->id, $o2->id ], by_id => 1);
is @{ $links->{$o1->id} }, 1, "batch recursive by_id direction both 1";
is @{ $links->{$o2->id} }, 1, "batch recursive by_id direction both 2";
is keys %$links, 2, "batch recursive by_id direction both 3";
is $links->{$o1->id}[0]->id, $i1->id, "batch recursive by_id direction both 4";
is $links->{$o2->id}[0]->id, $i2->id, "batch recursive by_id direction both 5";

clear_up();

1;
