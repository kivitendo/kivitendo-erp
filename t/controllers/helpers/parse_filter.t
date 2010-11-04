use lib 't';

use Test::More tests => 13;
use Test::Deep;
use Data::Dumper;

use_ok 'Support::TestSetup';
use_ok 'SL::Controller::Helper::ParseFilter';

Support::TestSetup::login();
my ($filter, $expected);

sub test ($$$) {
  my $got = { parse_filter($_[0]) };
  cmp_deeply(
    $got,
    $_[1],
    $_[2]
  ) or do {
    print STDERR "expected => ", Dumper($_[1]), "\ngot: => ", Dumper($got), $/;
  }
}

test { }, {
}, 'minimal test';

test {
  name => 'Test',
  whut => 'moof',
}, {
  query => [ %{{
    name => 'Test',
    whut => 'moof'
  }} ],
}, 'basic test';

test {
  customer => {
    name => 'rainer',
  }
}, {
  query => [ 'customer.name' => 'rainer' ],
  with_objects => [ 'customer' ],
}, 'joining customers';

test {
  customer => {
    chart => {
      accno => 'test',
    }
  }
}, {
  query => [ 'customer.chart.accno' => 'test' ],
  with_objects => bag( 'customer', 'chart' ),
}, 'nested joins';

test {
  'customer:substr' => 'Meyer'
}, {
  query => [ customer => '%Meyer%' ]
}, 'simple filter substr';

test {
  'customer::ilike' => 'Meyer'
}, {
  query => [ customer => { ilike => 'Meyer' } ]
}, 'simple method ilike';

test {
  customer => {
    chart => {
      'accno:tail::like' => '1200'
    }
  },
},
{
  query => [ 'customer.chart.accno' => { like => '%1200' } ],
  with_objects => bag('customer', 'chart' ),
}, 'all together';


test {
  customer => {
    name => 'test',
  },
  invoice => {
    customer => {
      name => 'test',
    },
  },
}, {
  'query' => [ %{{
               'invoice.customer.name'  => 'test',
               'customer.name'          => 'test',
             }} ],
  'with_objects' => bag( 'invoice', 'customer' )
}, 'object in more than one relationship';

test {
  'orddate:date::' => 'lt',
  'orddate:date' => '20.3.2010',
}, {
    'query' => [
                 'orddate' => { 'lt' => isa('DateTime') }
               ]

}, 'method dispatch and date constructor';

test {
  id => [
    123, 125, 157
  ]
}, {
  query => [ id => [ 123,125,157 ] ],
}, 'arrays as value';

test {
  'sellprice:number' => [
    '123,4', '2,34', '0,4',
  ]
}, {
  query => [
    sellprice => [ 123.4, 2.34, 0.4 ],
  ],
}, 'arrays with filter';

