use Test::More;

use strict;

use lib 't';
use utf8;

use Support::TestSetup;
use SL::Dev::CustomerVendor qw(new_customer new_vendor);

Support::TestSetup::login();

my ($c, $v);


# easy mode link + save + retrieve
$c = new_customer()->save;
$v = new_vendor()->save;

$c->linked_vendor($v);
$c->save;

$c->load;
ok $c->linked_vendor, "linked vendor there after load";


$c = new_customer()->save;
$v = new_vendor()->save;

$v->linked_customer($c);
$v->save;

$v->load;
ok $v->linked_customer, "linked customer there after load";


# accessors without saving
$c = new_customer()->save;
$v = new_vendor()->save;

$c->linked_customer_vendor($v);
is $c->linked_customer_vendor, $v, "linked_customer_vendor roundtrip";

$c->linked_customer_vendor(undef);
is $c->linked_customer_vendor, undef, "linked_customer_vendor roundtrip 2";

$v->linked_customer_vendor($c);
is $v->linked_customer_vendor, $c, "linked_customer_vendor roundtrip 3";

$v->linked_customer_vendor(undef);
is $v->linked_customer_vendor, undef, "linked_customer_vendor roundtrip 4";


$c->linked_vendor($v);
is $c->linked_vendor, $v, "linked_vendor roundtrip";

$c->linked_vendor(undef);
is $c->linked_vendor, undef, "linked_vendor roundtrip 2";

$v->linked_customer($c);
is $v->linked_customer, $c, "linked_customer roundtrip";

$v->linked_customer(undef);
is $v->linked_customer, undef, "linked_customer roundtrip 2";


# cached accessors

$c->linked_customer_vendor_cached($v);
is $c->linked_customer_vendor_cached, $v, "linked_customer_vendor_cached roundtrip";

$c->linked_customer_vendor_cached(undef);
is $c->linked_customer_vendor_cached, undef, "linked_customer_vendor_cached roundtrip 2";

$v->linked_customer_vendor_cached($c);
is $v->linked_customer_vendor_cached, $c, "linked_customer_vendor_cached roundtrip 3";

$v->linked_customer_vendor_cached(undef);
is $v->linked_customer_vendor_cached, undef, "linked_customer_vendor_cached roundtrip 4";


$c->linked_vendor_cached($v);
is $c->linked_vendor_cached, $v, "linked_vendor_cached roundtrip";

$c->linked_vendor_cached(undef);
is $c->linked_vendor_cached, undef, "linked_vendor_cached roundtrip 2";

$v->linked_customer_cached($c);
is $v->linked_customer_cached, $c, "linked_customer_cached roundtrip";

$v->linked_customer_cached(undef);
is $v->linked_customer_cached, undef, "linked_customer_cached roundtrip 2";


# break up link

$c = new_customer()->save;
$v = new_vendor()->save;

$c->linked_vendor($v);
$c->save;

$c->load;
$c->linked_vendor(undef);
$c->save;

$c->load;
ok !defined $c->linked_vendor, "not linked after breakung up";


$v->linked_customer($c);
$v->save;

$v->load;
$v->linked_customer(undef);
$v->save;

$v->load;
ok !defined $v->linked_customer, "not linked after breakung up";

# sync

$c = new_customer()->save;
$v = new_vendor()->save;

$c->load->linked_vendor($v);
$c->obsolete(1);
$c->sync_linked_customer_vendor;
ok $c->linked_vendor->obsolete, "synced before save";

$c->save;

$c->load;

ok $c->linked_vendor->obsolete, "obsolete got synced";

$c = new_customer()->save;
$v = new_vendor()->save;

$v->load->linked_customer($c);
$v->obsolete(1);
$v->sync_linked_customer_vendor;
ok $v->linked_customer->obsolete, "synced before save";
$v->save;

$v->load;

ok $v->linked_customer->obsolete, "obsolete got synced";

# accessor with id + sync

$c = new_customer()->save;
$v = new_vendor()->save;

$c->load->linked_vendor($v->id);
$c->obsolete(1);
$c->sync_linked_customer_vendor;
ok $c->linked_vendor->obsolete, "synced before save";

$c->save;

$c->load;

ok $c->linked_vendor->obsolete, "obsolete got synced";


$c = new_customer()->save;
$v = new_vendor()->save;

$v->load->linked_customer($c->id);
$v->obsolete(1);
$v->sync_linked_customer_vendor;
ok $v->linked_customer->obsolete, "synced before save";
$v->save;

$v->load;

ok $v->linked_customer->obsolete, "obsolete got synced";


# auto sync

$c = new_customer()->save;
$v = new_vendor()->save;

$c->load->linked_vendor($v);
$c->obsolete(1);
$c->save;

$c->load;

ok $c->linked_vendor->obsolete, "obsolete got synced";


$c = new_customer()->save;
$v = new_vendor()->save;

$v->load->linked_customer($c);
$v->obsolete(1);
$v->save;

$v->load;

ok $v->linked_customer->obsolete, "obsolete got synced";


# autosync on saved from database

$c = new_customer()->save;
$v = new_vendor()->save;
$c->linked_vendor($v)->save;
$c->load;

$c->obsolete(1);
$c->save;

$c->load;

ok $c->linked_vendor->obsolete, "obsolete got synced";


$c = new_customer()->save;
$v = new_vendor()->save;
$v->linked_customer($c->id);
$v->load;

$v->obsolete(1);
$v->save;

$v->load;

ok $v->linked_customer->obsolete, "obsolete got synced";

# done

done_testing();

1;
