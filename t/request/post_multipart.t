use strict;
use utf8;

use lib 't';
BEGIN {
  unshift @INC, 'modules/override';
}

use Support::TestSetup;
use Test::More tests => 2;
use Data::Dumper;
require Test::Deep;
use Encode;

use SL::Request;

Support::TestSetup::login();

open my $fh, '<', 't/request/post_multipart_1' or die "can't load test";
my $data = do { $/ = undef; <$fh> };

my $t = {};
my $tt = {};

local $ENV{CONTENT_TYPE} = 'multipart/form-data; boundary=---------------------------23281168279961';
SL::Request::_parse_multipart_formdata($t, $tt, $data);


my $blob = Encode::encode('utf-8', qq|\x{feff}Stunde;Montag;Dienstag;Mittwoch;Donnerstag;Freitag
1;Mathe;Deutsch;Englisch;Mathe;Kunst
2;Sport;Französisch;Geschichte;Sport;Geschichte
3;Sport;"Religion ev;kath";Kunst;;Kunst|);

my $t_cmp = {
          'profile' => {
                       'name' => undef,
                       'type' => undef
                     },
          'quote_char' => undef,
          'file' => $blob,
          'custom_sep_char' => undef,
          'sep_char' => undef,
          'settings' => {
                        'article_number_policy' => undef,
                        'sellprice_places' => undef,
                        'charset' => undef,
                        'apply_buchungsgruppe' => undef,
                        'full_preview' => undef,
                        'part_type' => undef,
                        'default_unit' => undef,
                        'default_buchungsgruppe' => undef,
                        'duplicates' => undef,
                        'numberformat' => undef,
                        'sellprice_adjustment_type' => undef,
                        'shoparticle_if_missing' => undef,
                        'sellprice_adjustment' => undef
                      },
          'custom_escape_char' => undef,
          'action_test' => undef,
          'custom_quote_char' => undef,
          'escape_char' => undef,
          'action' => undef
        };
$t_cmp->{ATTACHMENTS}{file}{data} =  \$t_cmp->{'file'};


is_deeply $t, $t_cmp;

is_deeply $tt,
        {
          'profile' => {
                       'name' => '',
                       'type' =>'parts',
                     },
          'file' => undef,
          'quote_char' => 'quote',
          'custom_sep_char' => '',
          'sep_char' => 'semicolon',
          'settings' => {
                        'article_number_policy' => 'update_prices',
                        'sellprice_places' => 2,
                        'charset' => 'UTF-8',
                        'apply_buchungsgruppe' => 'all',
                        'full_preview' => '0',
                        'part_type' => 'part',
                        'default_unit' => 'g',
                        'default_buchungsgruppe' => '815',
                        'duplicates' => 'no_check',
                        'numberformat' => '1.000,00',
                        'sellprice_adjustment_type' => 'percent',
                        'shoparticle_if_missing' => '0',
                        'sellprice_adjustment' =>'0'
                      },
          'custom_escape_char' => '',
          'action_test' => 'Test und Vorschau',
          'ATTACHMENTS' => {
                           'file' => {
                                     'filename' => 'from_wikipedia.csv'
                                   }
                         },
          'custom_quote_char' => '',
          'escape_char' => 'quote',
          'action' => 'CsvImport/dispatch',
          'FILENAME' => 'from_wikipedia.csv'
        };
