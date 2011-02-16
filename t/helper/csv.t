use Test::More;
use SL::Dispatcher;
use utf8;

use_ok 'SL::Helper::Csv';
my $csv;

$csv = SL::Helper::Csv->new(
  file   => \"Kaffee;\n",
  header => [ 'description' ],
);

isa_ok $csv->_csv, 'Text::CSV';
isa_ok $csv->_io, 'IO::File';
isa_ok $csv->parse, 'SL::Helper::Csv', 'parsing returns self';
is_deeply $csv->get_data, [ { description => 'Kaffee' } ], 'simple case works';

$csv->class('SL::DB::Part');

is $csv->get_objects->[0]->description, 'Kaffee', 'get_object works';
####

SL::Dispatcher::pre_startup_setup();

$::form = Form->new;
$::myconfig{numberformat} = '1.000,00';
$::myconfig{dateformat} = 'dd.mm.yyyy';
$::locale = Locale->new('de');

$csv = SL::Helper::Csv->new(
  file   => \"Kaffee;0.12;12,2;1,5234\n",
  header => [ 'description', 'sellprice', 'lastcost_as_number', 'listprice' ],
  header_acc => { listprice => 'listprice_as_number' },
  class  => 'SL::DB::Part',
);
$csv->parse;

is $csv->get_objects->[0]->sellprice, 0.12, 'numeric attr works';
is $csv->get_objects->[0]->lastcost, 12.2, 'attr helper works';
is $csv->get_objects->[0]->listprice, 1.5234, 'header_acc works';

#####


$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description,sellprice,lastcost_as_number,listprice,
Kaffee,0.12,'12,2','1,5234'
EOL
  sep_char => ',',
  quote_char => "'",
  header_acc => { listprice => 'listprice_as_number' },
  class  => 'SL::DB::Part',
);
$csv->parse;
is scalar @{ $csv->get_objects }, 1, 'auto header works';
is $csv->get_objects->[0]->description, 'Kaffee', 'get_object works on auto header';

#####


$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
;;description;sellprice;lastcost_as_number;
#####;Puppy;Kaffee;0.12;12,2;1,5234
EOL
  class  => 'SL::DB::Part',
);
$csv->parse;
is scalar @{ $csv->get_objects }, 1, 'bozo header doesn\'t blow things up';

#####

$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description;partnumber;sellprice;lastcost_as_number;
Kaffee;;0.12;12,2;1,5234
Beer;1123245;0.12;12,2;1,5234
EOL
  class  => 'SL::DB::Part',
);
$csv->parse;
is scalar @{ $csv->get_objects }, 2, 'multiple objects work';
is $csv->get_objects->[0]->description, 'Kaffee', 'first object';
is $csv->get_objects->[1]->partnumber, '1123245', 'second object';

####

$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description;partnumber;sellprice;lastcost_as_number;
Kaffee;;0.12;1,221.52
Beer;1123245;0.12;1.5234
EOL
  numberformat => '1,000.00',
  class  => 'SL::DB::Part',
);
$csv->parse;
is $csv->get_objects->[0]->lastcost, '1221.52', 'formatnumber';

######

$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
"description;partnumber;sellprice;lastcost_as_number;
Kaffee;;0.12;1,221.52
Beer;1123245;0.12;1.5234
EOL
  numberformat => '1,000.00',
  class  => 'SL::DB::Part',
);
is $csv->parse, undef, 'broken csv header won\'t get parsed';


done_testing();
# vim: ft=perl
