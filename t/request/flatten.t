use Test::More;
use Test::Deep;
use Data::Dumper;

use_ok 'SL::Request', qw(flatten unflatten);

use constant DEBUG => 0;

sub f ($$$) {
  my $flat = flatten($_[0]);
  print Dumper($flat) if DEBUG;

  my $unflat = unflatten($flat);
  print Dumper($unflat) if DEBUG;

  cmp_deeply($flat, $_[1], $_[2]);
  cmp_deeply($unflat, $_[0], $_[2]);
}

f {
  test => 1,
  whut => 2
},
[
  [ test => 1 ],
  [ whut => 2 ],
], 'simple case';

f { a => { b => 2 } },
[
 [ 'a.b' => 2 ]
], 'simple hash nesting';

f { a => [ 2,  4 ] },
[
 [  'a[]' => 2 ],
 [  'a[]' => 4 ],
], 'simple array';

f { a => [ { c => 1, d => 2 }, { c => 3, d => 4 }, ] },
[
  [ 'a[+].c', 1 ],
  [ 'a[].d', 2 ],
  [ 'a[+].c', 3 ],
  [ 'a[].d', 4  ],
], 'array of hashes';

# tests from Hash::Flatten below
f {
  'x' => 1,
  'y' => {
    'a' => 2,
    'b' => {
      'p' => 3,
      'q' => 4
    },
  }
}, bag(
 [ 'x'     => 1, ],
 [ 'y.a'   => 2, ],
 [ 'y.b.p' => 3, ],
 [ 'y.b.q' => 4  ],
), 'Hash::Flatten 1';


f {
  'x' => 1,
  '0' => {
    '1' => 2,
  },
  'a' => [1,2,3],
},
bag (
 ['x'    => 1, ],
 ['0.1'  => 2, ],
 ['a[]'  => 1, ],
 ['a[]'  => 2, ],
 ['a[]'  => 3, ],
), 'Hash::Flatten 2 - weird keys and values';


f {
  'x' => 1,
  'ay' => {
    'a' => 2,
    'b' => {
      'p' => 3,
      'q' => 4
    },
  },
  'y' => [
    'a', 2,
    {
      'baz' => 'bum',
    },
  ]
},
bag(
  [ 'ay.b.p'  => 3,       ],
  [ 'ay.b.q'  => 4,       ],
  [ 'ay.a'    => 2,       ],
  [ 'x'       => 1,       ],
  [ 'y[]'     => 'a',    ],
  [ 'y[]'     => 2        ],
  [ 'y[+].baz' => 'bum',  ],
), 'Hash::Flatten 3 - mixed';

f {
  'x' => 1,
  'y' => [
    [
      'a', 'fool', 'is',
    ],
    [
      'easily', [ 'parted', 'from' ], 'his'
    ],
    'money',
  ]
},
bag(
 [ 'x'        => 1,        ],
 [ 'y[][]'    => 'his',    ],
 [ 'y[][+][]' => 'parted', ],
 [ 'y[][][]'  => 'from',   ],
 [ 'y[+][]'   => 'a',      ],
 [ 'y[+][]'   => 'easily', ],
 [ 'y[][]'    => 'fool',   ],
 [ 'y[][]'    => 'is'      ],
 [ 'y[]'      => 'money',  ],
), 'Hash::Flatten 4 - array nesting';

f {
  'x' => 1,
  'ay' => {
    'a' => 2,
    'b' => {
      'p' => 3,
      'q' => 4
    },
  },
  's' => 'hey',
  'y' => [
    'a', 2, {
      'baz' => 'bum',
    },
  ]
},
bag(
  [ 'x'        => 1,     ],
  [ 's'        => 'hey', ],
  [ 'ay.a'     => 2,     ],
  [ 'y[+].baz' => 'bum', ],
  [ 'ay.b.p'   => 3,     ],
  [ 'y[]'      => 'a',   ],
  [ 'ay.b.q'   => 4,     ],
  [ 'y[]'      => 2      ],
), 'Hash::Flatten 5 - deep mix';

done_testing();
