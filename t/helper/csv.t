use Test::More tests => 29;
use SL::Dispatcher;
use Data::Dumper;
use utf8;

use_ok 'SL::Helper::Csv';
my $csv;

$csv = SL::Helper::Csv->new(
  file   => \"Kaffee\n",
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
  dispatch => { listprice => 'listprice_as_number' },
  class  => 'SL::DB::Part',
);
$csv->parse;

is $csv->get_objects->[0]->sellprice, 0.12, 'numeric attr works';
is $csv->get_objects->[0]->lastcost, 12.2, 'attr helper works';
is $csv->get_objects->[0]->listprice, 1.5234, 'dispatch works';

#####


$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description,sellprice,lastcost_as_number,listprice,
Kaffee,0.12,'12,2','1,5234'
EOL
  sep_char => ',',
  quote_char => "'",
  dispatch => { listprice => 'listprice_as_number' },
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

######

$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description;partnumber;sellprice;lastcost_as_number;
"Kaf"fee";;0.12;1,221.52
Beer;1123245;0.12;1.5234
EOL
  numberformat => '1,000.00',
  class  => 'SL::DB::Part',
);
is $csv->parse, undef, 'broken csv content won\'t get parsed';
is_deeply $csv->errors, [ '"Kaf"fee";;0.12;1,221.52'."\n", 2023, 'EIQ - QUO character not allowed', 5, 2 ], 'error';

####

$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description;partnumber;sellprice;lastcost_as_number;wiener;
Kaffee;;0.12;1,221.52;ja wiener
Beer;1123245;0.12;1.5234;nein kein wieder
EOL
  numberformat => '1,000.00',
  ignore_unknown_columns => 1,
  class  => 'SL::DB::Part',
);
$csv->parse;
is $csv->get_objects->[0]->lastcost, '1221.52', 'ignore_unkown_columns works';

#####

$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description;partnumber;sellprice;lastcost_as_number;buchungsgruppe;
Kaffee;;0.12;1,221.52;Standard 7%
Beer;1123245;0.12;1.5234;16 %
EOL
  numberformat => '1,000.00',
  class  => 'SL::DB::Part',
  profile => {
    buchungsgruppe => "buchungsgruppen.description",
  }
);
$csv->parse;
isa_ok $csv->get_objects->[0]->buchungsgruppe, 'SL::DB::Buchungsgruppe', 'deep dispatch auto vivify works';
is $csv->get_objects->[0]->buchungsgruppe->description, 'Standard 7%', '...and gets set correctly';


#####

$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description;partnumber;sellprice;lastcost_as_number;make_1;model_1;
  Kaffee;;0.12;1,221.52;213;Chair 0815
Beer;1123245;0.12;1.5234;
EOL
  numberformat => '1,000.00',
  class  => 'SL::DB::Part',
  profile => {
    make_1 => "makemodels.0.make",
    model_1 => "makemodels.0.model",
  }
);
$csv->parse;
my @mm = $csv->get_objects->[0]->makemodel;
is scalar @mm,  1, 'one-to-many dispatch';
is $csv->get_objects->[0]->makemodels->[0]->model, 'Chair 0815', '... and works';

#####


$csv = SL::Helper::Csv->new(
  file   => \<<EOL,
description;partnumber;sellprice;lastcost_as_number;make_1;model_1;make_2;model_2;
 Kaffee;;0.12;1,221.52;213;Chair 0815;523;Table 15
EOL
  numberformat => '1,000.00',
  class  => 'SL::DB::Part',
  profile => {
    make_1 => "makemodels.0.make",
    model_1 => "makemodels.0.model",
    make_2 => "makemodels.1.make",
    model_2 => "makemodels.1.model",
  }
);
$csv->parse;

print Dumper($csv->errors);

my @mm = $csv->get_objects->[0]->makemodel;
is scalar @mm,  1, 'multiple one-to-many dispatch';
is $csv->get_objects->[0]->makemodels->[0]->model, 'Chair 0815', '...check 1';
is $csv->get_objects->[0]->makemodels->[0]->make, '213', '...check 2';
is $csv->get_objects->[0]->makemodels->[1]->model, 'Table 15', '...check 3';
is $csv->get_objects->[0]->makemodels->[1]->make, '523', '...check 4';

# vim: ft=perl
