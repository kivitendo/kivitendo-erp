use Test::More tests => 44;

use lib 't';

use DateTime;

use_ok 'Support::TestSetup';
use_ok 'SL::DB::Part';
use_ok 'SL::DB::Order';
use_ok 'SL::DB::Invoice';

Support::TestSetup::login();

{
$::myconfig{numberformat} = '1.000,00';
$::myconfig{dateformat} = 'dd.mm.yyyy';
}

my $p = new_ok 'SL::DB::Part';
is($p->sellprice_as_number('2,30'), '2,30');
is($p->sellprice, 2.30);
is($p->sellprice_as_number, '2,30');
is($p->sellprice_as_number('2,3442'), '2,3442');
is($p->sellprice, 2.3442);
is($p->sellprice_as_number, '2,3442');
is($p->listprice_as_null_number('2,30'), '2,30');
is($p->listprice, 2.30);
is($p->listprice_as_null_number, '2,30');
is($p->listprice_as_null_number('2,3442'), '2,3442');
is($p->listprice, 2.3442);
is($p->listprice_as_null_number, '2,3442');
is($p->listprice_as_null_number(''), '');
is($p->listprice, undef);
is($p->listprice_as_null_number, '');
is($p->listprice_as_null_number('0'), '0,00');
is($p->listprice, 0);
is($p->listprice_as_null_number, '0,00');

my $o = new_ok 'SL::DB::Order';
is($o->reqdate_as_date('11.12.2007'), '11.12.2007');
is($o->reqdate->year, 2007);
is($o->reqdate->month, 12);
is($o->reqdate->day, 11);
is($o->reqdate_as_date, '11.12.2007');
$o->reqdate(DateTime->new(year => 2010, month => 4, day => 12));
is($o->reqdate_as_date, '12.04.2010');

is($o->marge_percent_as_percent('40'), '40,00');
is($o->marge_percent, 0.40);
is($o->marge_percent_as_percent, '40,00');
is($o->marge_percent_as_percent('22,4'), '22,40');
is($o->marge_percent, 0.224);
is($o->marge_percent_as_percent, '22,40');
is($o->marge_percent(0.231), 0.231);
is($o->marge_percent_as_percent, '23,10');

# overloaded attr: invoice taxamount
my $i = new_ok 'SL::DB::Invoice';

is($i->taxamount_as_number, '0,00');
$i->amount(12);
$i->netamount(10.34);
is($i->taxamount_as_number, '1,66');

$o->closed(1);
is $o->closed_as_bool_yn, 'Ja', 'bool 1';
$o->closed(0);
is $o->closed_as_bool_yn, 'Nein', 'bool 2';

# undef test: this only works for columns without default, rose will set
# defaults according to the database
$i->taxincluded(undef);
is $i->taxincluded_as_bool_yn, '', 'bool 3';
