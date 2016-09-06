use Test::More tests => 33;

use strict;

use lib 't';

use Carp;
use Data::Dumper;
use Support::TestSetup;
use Test::Exception;

use List::MoreUtils qw(pairwise);
use SL::Controller::CsvImport;

my $DEBUG = 0;

use_ok 'SL::Controller::CsvImport::Part';

use SL::DB::Buchungsgruppe;
use SL::DB::Currency;
use SL::DB::Customer;
use SL::DB::Language;
use SL::DB::Warehouse;
use SL::DB::Bin;

my ($translation, $bin1_1, $bin1_2, $bin2_1, $bin2_2, $wh1, $wh2, $bugru, $cvarconfig );

Support::TestSetup::login();

sub reset_state {
  # Create test data

  clear_up();

  $translation     = SL::DB::Language->new(
    description    => 'Englisch',
    article_code   => 'EN',
    template_code  => 'EN',
  )->save;
  $translation     = SL::DB::Language->new(
    description    => 'Italienisch',
    article_code   => 'IT',
    template_code  => 'IT',
  )->save;
  $wh1 = SL::DB::Warehouse->new(
    description    => 'Lager1',
    sortkey        => 1,
  )->save;
  $bin1_1 = SL::DB::Bin->new(
    description    => 'Ort1_von_Lager1',
    warehouse_id   => $wh1->id,
  )->save;
  $bin1_2 = SL::DB::Bin->new(
    description    => 'Ort2_von_Lager1',
    warehouse_id   => $wh1->id,
  )->save;
  $wh2 = SL::DB::Warehouse->new(
    description    => 'Lager2',
    sortkey        => 2,
  )->save;
  $bin2_1 = SL::DB::Bin->new(
    description    => 'Ort1_von_Lager2',
    warehouse_id   => $wh2->id,
  )->save;
  $bin2_2 = SL::DB::Bin->new(
    description    => 'Ort2_von_Lager2',
    warehouse_id   => $wh2->id,
  )->save;

  $cvarconfig = SL::DB::CustomVariableConfig->new(
    module   => 'IC',
    name     => 'mycvar',
    type     => 'text',
    description => 'mein schattz',
    searchable  => 1,
    sortkey => 1,
    includeable => 0,
    included_by_default => 0,
  )->save;
}

$bugru = SL::DB::Manager::Buchungsgruppe->find_by(description => { like => 'Standard%19%' });

reset_state();

#####
sub test_import {
  my ($file,$settings) = @_;
  my @profiles;
  my $controller = SL::Controller::CsvImport->new();

  my $csv_part_import = SL::Controller::CsvImport::Part->new(
    settings   => $settings,
    controller => $controller,
    file       => $file,
  );

  $csv_part_import->test_run(0);
  $csv_part_import->csv(SL::Helper::Csv->new(file                    => $csv_part_import->file,
                                             profile                 => [{ profile => $csv_part_import->profile,
                                                                           class   => $csv_part_import->class,
                                                                           mapping => $csv_part_import->controller->mappings_for_profile }],
                                             encoding                => 'utf-8',
                                             ignore_unknown_columns  => 1,
                                             strict_profile          => 1,
                                             case_insensitive_header => 1,
                                             sep_char                => ';',
                                             quote_char              => '"',
                                             ignore_unknown_columns  => 1,
                                            ));

  $csv_part_import->csv->parse;

  $csv_part_import->controller->errors([ $csv_part_import->csv->errors ]) if $csv_part_import->csv->errors;

  return if ( !$csv_part_import->csv->header || $csv_part_import->csv->errors );

  my $headers         = { headers => [ grep { $csv_part_import->csv->dispatcher->is_known($_, 0) } @{ $csv_part_import->csv->header } ] };
  $headers->{methods} = [ map { $_->{path} } @{ $csv_part_import->csv->specs->[0] } ];
  $headers->{used}    = { map { ($_ => 1) }  @{ $headers->{headers} } };
  $csv_part_import->controller->headers($headers);
  $csv_part_import->controller->raw_data_headers({ used => { }, headers => [ ] });
  $csv_part_import->controller->info_headers({ used => { }, headers => [ ] });

  my $objects  = $csv_part_import->csv->get_objects;
  my @raw_data = @{ $csv_part_import->csv->get_data };

  $csv_part_import->controller->data([ pairwise { no warnings 'once'; { object => $a, raw_data => $b, errors => [], information => [], info_data => {} } } @$objects, @raw_data ]);

  $csv_part_import->check_objects;

  # don't try and save objects that have errors
  $csv_part_import->save_objects unless scalar @{$csv_part_import->controller->data->[0]->{errors}};

  return $csv_part_import->controller->data;
}

$::myconfig{numberformat} = '1000.00';
my $old_locale = $::locale;
# set locale to en so we can match errors
$::locale = Locale->new('en');


my ($entries, $entry, $file);

# different settings for tests
#

my $settings1 = {
                       sellprice_places          => 2,
                       sellprice_adjustment      => 0,
                       sellprice_adjustment_type => 'percent',
                       article_number_policy     => 'update_prices',
                       shoparticle_if_missing    => '0',
                       parts_type                => 'part',
                       default_buchungsgruppe    => ($bugru ? $bugru->id : undef),
                       apply_buchungsgruppe      => 'all',
                };
my $settings2 = {
                       sellprice_places          => 2,
                       sellprice_adjustment      => 0,
                       sellprice_adjustment_type => 'percent',
                       article_number_policy     => 'update_parts',
                       shoparticle_if_missing    => '0',
                       parts_type                => 'part',
                       default_buchungsgruppe    => ($bugru ? $bugru->id : undef),
                       apply_buchungsgruppe      => 'missing',
                       default_unit              => 'Stck',
                };

#
#
# starting test of csv imports
# to debug errors in certain tests, run after test_import:
#   die Dumper($entry->{errors});


##### create part
$file = \<<EOL;
partnumber;sellprice;lastcost;listprice;unit
P1000;100.10;90.20;95.30;kg
EOL
$entries = test_import($file,$settings1);
$entry = $entries->[0];
#foreach my $err ( @{ $entry->{errors} } ) {
#  print $err;
#}
is $entry->{object}->partnumber,'P1000', 'partnumber';
is $entry->{object}->sellprice, '100.1', 'sellprice';
is $entry->{object}->lastcost,   '90.2', 'lastcost';
is $entry->{object}->listprice,  '95.3', 'listprice';

##### update prices of part
$file = \<<EOL;
partnumber;sellprice;lastcost;listprice;unit
P1000;110.10;95.20;97.30;kg
EOL
$entries = test_import($file,$settings1);
$entry = $entries->[0];
is $entry->{object}->sellprice, '110.1', 'updated sellprice';
is $entry->{object}->lastcost,   '95.2', 'updated lastcost';
is $entry->{object}->listprice,  '97.3', 'updated listprice';

##### insert parts with warehouse,bin name

$file = \<<EOL;
partnumber;description;warehouse;bin
P1000;Teil 1000;Lager1;Ort1_von_Lager1
P1001;Teil 1001;Lager1;Ort2_von_Lager1
P1002;Teil 1002;Lager2;Ort1_von_Lager2
P1003;Teil 1003;Lager2;Ort2_von_Lager2
EOL
$entries = test_import($file,$settings2);
$entry = $entries->[0];
is $entry->{object}->description, 'Teil 1000', 'Teil 1000 set';
is $entry->{object}->warehouse_id, $wh1->id, 'Lager1';
is $entry->{object}->bin_id, $bin1_1->id, 'Lagerort1';
$entry = $entries->[2];
is $entry->{object}->description, 'Teil 1002', 'Teil 1002 set';
is $entry->{object}->warehouse_id, $wh2->id, 'Lager2';
is $entry->{object}->bin_id, $bin2_1->id, 'Lagerort1';

##### update warehouse and bin
$file = \<<EOL;
partnumber;description;warehouse;bin
P1000;Teil 1000;Lager2;Ort1_von_Lager2
P1001;Teil 1001;Lager1;Ort1_von_Lager1
P1002;Teil 1002;Lager2;Ort1_von_Lager1
P1003;Teil 1003;Lager2;kein Lagerort
EOL
$entries = test_import($file,$settings2);
$entry = $entries->[0];
is $entry->{object}->description, 'Teil 1000', 'Teil 1000 set';
is $entry->{object}->warehouse_id, $wh2->id, 'Lager2';
is $entry->{object}->bin_id, $bin2_1->id, 'Lagerort1';
$entry = $entries->[2];
my $err1 = @{ $entry->{errors} }[0];
#print "'".$err1."'\n";
is $entry->{object}->description, 'Teil 1002', 'Teil 1002 set';
is $entry->{object}->warehouse_id, $wh2->id, 'Lager2';
is $err1, 'Error: Bin Ort1_von_Lager1 is not from warehouse Lager2','kein Lager von Lager2';
$entry = $entries->[3];
$err1 = @{ $entry->{errors} }[0];
#print "'".$err1."'\n";
is $entry->{object}->description, 'Teil 1003', 'Teil 1003 set';
is $entry->{object}->warehouse_id, $wh2->id, 'Lager2';
is $err1, 'Error: Invalid bin name kein Lagerort','kein Lagerort';

##### add translations
$file = \<<EOL;
partnumber;description;description_EN;notes_EN;description_IT;notes_IT
P1000;Teil 1000;descr EN 1000;notes EN;descr IT 1000;notes IT
P1001;Teil 1001;descr EN 1001;notes EN;descr IT 1001;notes IT
P1002;Teil 1002;descr EN 1002;notes EN;descr IT 1002;notes IT
P1003;Teil 1003;descr EN 1003;notes EN;descr IT 1003;notes IT
EOL
$entries = test_import($file,$settings2);
$entry = $entries->[0];
is $entry->{object}->description, 'Teil 1000', 'Teil 1000 set';
is $entry->{raw_data}->{description_EN},'descr EN 1000','EN set';
is $entry->{raw_data}->{description_IT},'descr IT 1000','IT set';
my $l = @{$entry->{object}->translations}[0];
is $l->translation,'descr EN 1000','EN trans set';
is $l->longdescription, 'notes EN','EN notes set';
$l = @{$entry->{object}->translations}[1];
is $l->translation,'descr IT 1000','IT trans set';
is $l->longdescription, 'notes IT','IT notes set';

##### add customvar
$file = \<<EOL;
partnumber;cvar_mycvar
P1000;das ist der ring
P1001;nicht der nibelungen
P1002;sondern vom
P1003;Herr der Ringe
EOL
$entries = test_import($file,$settings2);
$entry = $entries->[0];
is $entry->{object}->partnumber, 'P1000', 'P1000 set';
is $entry->{raw_data}->{cvar_mycvar},'das ist der ring','CVAR set';
is @{$entry->{object}->custom_variables}[0]->text_value,'das ist der ring','Cvar mit richtigem Weert';

clear_up(); # remove all data at end of tests

# end of tests


sub clear_up {
  SL::DB::Manager::Part       ->delete_all(all => 1);
  SL::DB::Manager::Translation->delete_all(all => 1);
  SL::DB::Manager::Language   ->delete_all(all => 1);
  SL::DB::Manager::Bin        ->delete_all(all => 1);
  SL::DB::Manager::Warehouse  ->delete_all(all => 1);
  SL::DB::Manager::CustomVariableConfig->delete_all(all => 1);
}


1;

#####
# vim: ft=perl
# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
