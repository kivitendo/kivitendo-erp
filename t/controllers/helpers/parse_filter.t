use lib 't';

use Test::More tests => 41;
use Test::Deep;
use Data::Dumper;

use_ok 'Support::TestSetup';
use_ok 'SL::Controller::Helper::ParseFilter';

use SL::DB::OrderItem;

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
  'sellprice_number_' => { '123,4' => 1, '2,34' => 1, '0,4' => 1 },
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

test {
  part => {
   'sellprice:number' => '2',
   'sellprice:number::' => 'le',
  }
}, {
  part => {
   'sellprice:number' => '2',
   'sellprice:number::' => 'le',
  }
}, 'laundering of indirect filters does not alter', target => 'filter', launder_to => { };

test {
  part => {
   'sellprice:number' => '2',
   'sellprice:number::' => 'le',
  }
}, {
  part => {
    'sellprice_number' => '2',
    'sellprice_number__' => 'le',
  }
}, 'laundering of indirect filters', target => 'launder', launder_to => { };

test {
  part => {
   'sellprice:number' => '2',
   'sellprice:number::' => 'le',
  }
}, {
  part => {
    'sellprice:number' => '2',
    'sellprice:number::' => 'le',
    'sellprice_number' => '2',
    'sellprice_number__' => 'le',
  }
}, 'laundering of indirect filters - inplace', target => 'filter';

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

### class filter dispatch
#
test {
  name => 'Test',
  whut => 'moof',
}, {
  query => bag(
    name => 'Test',
    whut => 'moof'
  ),
}, 'object test simple', class => 'SL::DB::Manager::Part';

test {
  'part_type' => 'assembly',
}, {
  query => [
             'part_type',
             'assembly'
           ] ,
}, 'object test without prefix', class => 'SL::DB::Manager::Part';

test {
  'part.part_type' => 'assembly',
}, {
  query => [
             'part.part_type',
             'assembly'
           ]
}, 'object test with prefix', class => 'SL::DB::Manager::OrderItem';

test {
  'part_type' => [ 'part', 'assembly' ],
}, {
  query => [
             'or',
             [
               'part_type',
               'part',
               'part_type',
               'assembly'
             ]
           ]
}, 'object test without prefix but complex value', class => 'SL::DB::Manager::Part';
test {
  'part.part_type' => [ 'part', 'assembly' ],
}, {
  query => [
             'or',
             [
               'part.part_type',
               'part',
               'part.part_type',
               'assembly'
             ]
           ]
}, 'object test with prefix but complex value', class => 'SL::DB::Manager::OrderItem';

test {
  description => 'test'
}, {
  query => [ description => 'test' ],
  with_objects => [ 'order' ]
}, 'with_objects don\'t get clobbered', with_objects => [ 'order' ];

test {
  customer => {
    description => 'test'
  }
}, {
  query => [ 'customer.description' => 'test' ],
  with_objects => [ 'order', 'customer' ]
}, 'with_objects get extended with auto infered objects', with_objects => [ 'order' ];

test {
  customer => {
    description => 'test'
  }
}, {
  query => [ 'customer.description' => 'test' ],
  with_objects => [ 'order', 'customer' ]
}, 'with_objects get extended with auto infered objects with classes', class => 'SL::DB::Manager::Order',  with_objects => [ 'order' ];

test {
  customer => {
    description => 'test'
  }
}, {
  query => [ 'customer.description' => 'test' ],
  with_objects => [ 'customer' ]
}, 'with_objects: no duplicates', with_objects => [ 'customer' ];

test {
  part => {
   'partnumber:substr::ilike' => '1',
  },
}, {
  query => [
   'part.partnumber', {
     ilike => '%1%'
   }
 ],
 with_objects => [ 'part' ],
}, 'Regression check: prefixing of fallback filtering in relation with custom filters', class => 'SL::DB::Manager::OrderItem';
test {
  'description:substr:multi::ilike' => 'term1 term2',
}, {
  query => [
    and => [
      description => { ilike => '%term1%' },
      description => { ilike => '%term2%' },
    ]
  ]
}, 'simple :multi';

test {
  part => {
    'all:substr:multi::ilike' => 'term1 term2',
  },
}, {
  query => [
    and => [
      or => [
        'part.partnumber'  => { ilike => '%term1%' },
        'part.description' => { ilike => '%term1%' },
        'part.ean'         => { ilike => '%term1%' },
      ],
      or => [
        'part.partnumber'  => { ilike => '%term2%' },
        'part.description' => { ilike => '%term2%' },
        'part.ean'         => { ilike => '%term2%' },
      ],
    ]
  ],
}, 'complex :multi with custom dispatch and prefix', class => 'SL::DB::Manager::OrderItem';

test {
  'description:substr:multi::ilike' => q|term1 "term2 and half" 'term3 and stuff'|,
}, {
  query => [
    and => [
      description => { ilike => '%term1%' },
      description => { ilike => '%term2 and half%' },
      description => { ilike => '%term3 and stuff%' },
    ]
  ]
}, ':multi with complex tokenizing';

# test tokenizing for custom filters by monkeypatching a custom filter into Part
SL::DB::Manager::Part->add_filter_specs(
  test => sub {
    my ($key, $value, $prefix, @additional) = @_;
    return "$prefix$key" => { @additional, $value };
  }
);

test {
  'part.test.what' => 2,
}, {
  query => [
    'part.test' => { 'what', 2 },
  ]
}, 'additional tokens', class => 'SL::DB::Manager::OrderItem';

test {
  'part.test.what:substr::ilike' => 2,
}, {
  query => [
    'part.test' => { 'what', { ilike => '%2%' } },
  ]
}, 'additional tokens + filters + methods', class => 'SL::DB::Manager::OrderItem';

test {
  'orderitems.part.test.what:substr::ilike' => 2,
}, {
  query => [
    'orderitems.part.test' => { 'what', { ilike => '%2%' } },
  ]
}, 'relationship + additional tokens + filters + methods', class => 'SL::DB::Manager::Order';

test {
  part => {
    'obsolete::lazy_bool_eq' => '0',
  },
}, {
  query => [
      or => [
        'part.obsolete' => undef,
        'part.obsolete' => 0
      ],
  ],
  with_objects => [ 'part' ],
}, 'complex methods modifying the key';


test {
  'customer:substr::ilike' => ' Meyer'
}, {
  query => [ customer => { ilike => '%Meyer%' } ]
}, 'auto trim 1';

test {
  'customer:head::ilike' => ' Meyer '
}, {
  query => [ customer => { ilike => 'Meyer%' } ]
}, 'auto trim 2';

test {
  'customer:tail::ilike' => "\nMeyer\x{a0}"
}, {
  query => [ customer => { ilike => '%Meyer' } ]
}, 'auto trim 2';
