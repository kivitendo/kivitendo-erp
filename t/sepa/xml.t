use strict;
use utf8;

use lib 't';

use Test::More;

use Support::TestSetup;

use SL::SEPA::XML;

Support::TestSetup::login();

my $sepa_xml = SL::SEPA::XML->new(company    => 'Müller_Söhne & Co; KG',
                                  message_id => 'test');
$sepa_xml->add_transaction({ src_iban      => 'DE46370501980026004705',
                             src_bic       => 'COLSDE33',
                             dst_iban      => 'DE74380601866404413013',
                             dst_bic       => 'GENODED1BRS',
                             company       => 'Årdberg "Kaffee" <AB>',
                             reference     => "1583: Rechnung Dokument_C-74393 [x] {y} a|b\\c !#\$%*=?\@^~\t",
                             amount        => 204.97,
                             end_to_end_id => 'KIVITENDO1' });

my $xml = $sepa_xml->to_xml;

my @texts = $xml =~ m{<(?:Nm|Ustrd)>([^<]*)</}g;
is_deeply(\@texts, [ 'Mueller-Soehne + Co, KG', 'Mueller-Soehne + Co, KG', "Ardberg 'Kaffee' (AB)",
                     '1583: Rechnung Dokument-C-74393 (x) (y) a/b/c ?' ],
          'names and remittance information use the SEPA character set only');

done_testing;
