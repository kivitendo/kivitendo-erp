use lib 't';

use Test::More tests => 18;
use Test::Deep;
use Data::Dumper;

use_ok 'Support::TestSetup';
use_ok 'SL::Controller::Helper::ParseFilter';

undef *::any; # Test::Deep exports any (for junctions) and MoreCommon exports any (like in List::Moreutils)

Support::TestSetup::login();
my ($filter, $expected);

sub test ($$$;%) {
  my ($filter, $expect, $msg, %params) = @_;
  my $target = delete $params{target};
  my $args = { parse_filter($filter, %params) };
  my $got  = $args; $target ||= '';
     $got = $filter             if $target =~ /filter/;
     $got = $params{launder_to} if $target =~ /launder/;
  cmp_deeply(
    $got,
    $expect,
    $msg,
  ) or do {
    print STDERR "expected => ", Dumper($expect), "\ngot: => ", Dumper($got), $/;
  }
}

test { }, {
}, 'minimal test';

test {
  name => 'Test',
  whut => 'moof',
}, {
  query => bag(
    name => 'Test',
    whut => 'moof'
  ),
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
  with_objects => bag( 'customer', 'customer.chart' ),
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
  with_objects => bag('customer', 'customer.chart' ),
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
  'query' => bag(
               'invoice.customer.name'  => 'test',
               'customer.name'          => 'test',
            ),
  'with_objects' => bag( 'invoice.customer', 'customer', 'invoice' )
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


########### laundering

test {
  'sellprice:number' => [
    '123,4', '2,34', '0,4',
  ]
}, {
  'sellprice:number' => [ '123,4', '2,34', '0,4' ],
  'sellprice_number' => [ '123,4', '2,34', '0,4' ],
}, 'laundering with array', target => 'filter';

my %args = (
  'sellprice:number' => [
    '123,4', '2,34', '0,4',
  ],
);
test {
  %args,
}, {
  %args
}, 'laundering into launder does not alter filter', target => 'filter', launder_to => {};


test {
  part => {
   'sellprice:number' => '123,4',
  }
}, {
  part => {
    'sellprice:number' => '123,4',
    'sellprice_number' => '123,4'
  }
}, 'deep laundering', target => 'filter';


test {
  part => {
   'sellprice:number' => '123,4',
  }
}, {
  part => {
    'sellprice_number' => '123,4'
  }
}, 'deep laundering, check for laundered hash', target => 'launder', launder_to => { };

### bug: sub objects

test {
  order => {
    customer => {
      'name:substr::ilike' => 'test',
    }
  }
}, {
  query => [ 'order.customer.name' => { ilike => '%test%' } ],
  with_objects => bag('order.customer', 'order'),
}, 'sub objects have to retain their prefix';

