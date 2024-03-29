use Test::More tests => 40;

use strict;

use lib 't';
use Support::TestSetup;

use_ok('SL::Helper::QrBillParser');

Support::TestSetup::login();

{
  my $code = "SPC\n0200\n1\nCH5204835012345671000\nS\nSample Foundation\nPO Box\n\n3001\nBern\nCH\n\n\n\n\n\n\n\n\nCHF\n\n\n\n\n\n\n\nNON\n\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 1, 'code1valid');
  is($obj->{creditor_information}->{iban}, "CH5204835012345671000", 'code1iban');
  is($obj->{creditor}->{name}, "Sample Foundation", 'code1name');
  is($obj->{payment_amount_information}->{amount}, "", 'code1amount');
}

{
  my $code = "SPC\r\n0200\r\n1\r\nCH4431999123000889012\r\nS\r\nMax Muster & Söhne\r\nMusterstrasse\r\n123\r\n8000\r\nSeldwyla\r\nCH\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n1949.75\r\nCHF\r\nS\r\nSimon Muster\r\nMusterstrasse\r\n1\r\n8000\r\nSeldwyla\r\nCH\r\nQRR\r\n210000000003139471430009017\r\nOrder from 15.10.2020\r\nEPD\r\n//S1/10/1234/11/201021/30/102673386/32/7.7/40/0:30\r\nName AV1: UV;UltraPay005;12345\r\nName AV2: XY;XYService;54321";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 1, 'code2valid');
  is($obj->{creditor_information}->{iban}, "CH4431999123000889012", 'code2iban');
  is($obj->{creditor}->{name}, "Max Muster & Söhne", 'code2name');
  is($obj->{payment_amount_information}->{amount}, "1949.75", 'code2amount');
  is($obj->{payment_reference}->{reference}, "210000000003139471430009017", 'code2reference');
  is($obj->{additional_information}->{unstructured_message}, "Order from 15.10.2020", 'code2unstructured_message');

  is($obj->get_creditor_street_name(), 'Musterstrasse', 'code2street_name');
  is($obj->get_creditor_building_number(), '123', 'code2building_number');
  is($obj->get_creditor_post_code(), '8000', 'code2post_code');
  is($obj->get_creditor_town_name(), 'Seldwyla', 'code2town_name');
}

{
  my $code = "SPC\n0200\n1\nCH5800791123000889012\nS\nMuster Krankenkasse\nMusterstrasse\n12\n8000\nSeldwyla\nCH\n\n\n\n\n\n\n\n211.00\nCHF\nS\nSarah Beispiel\nMusterstrasse\n1\n8000\nSeldwyla\nCH\nSCOR\nRF240191230100405JSH0438\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 1, 'code3valid');
  is($obj->{creditor_information}->{iban}, "CH5800791123000889012", 'code3iban');
  is($obj->{creditor}->{name}, "Muster Krankenkasse", 'code3name');
  is($obj->{payment_amount_information}->{amount}, "211.00", 'code3amount');
  is($obj->{payment_reference}->{reference}, "RF240191230100405JSH0438", 'code3reference');
}

{
  my $code = "SPC\n0200\n1\nCH5800791123000889012\nS\nMax Muster & Söhne\nMusterstrasse\n123\n8000\nSeldwyla\nCH\n\n\n\n\n\n\n\n199.95\nCHF\nS\nSarah Beispiel\nMusterstrasse\n1\n78462\nKonstanz\nDE\nSCOR\nRF18539007547034\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 1, 'code4valid');
  is($obj->{creditor_information}->{iban}, "CH5800791123000889012", 'code4iban');
  is($obj->{creditor}->{name}, "Max Muster & Söhne", 'code4name');
  is($obj->{payment_amount_information}->{amount}, "199.95", 'code4amount');
  is($obj->{payment_reference}->{reference}, "RF18539007547034", 'code4reference');
}

{
  my $code = "SP\n0200\n1\nCH5800791123000889012\nS\nMax Muster & Söhne\nMusterstrasse\n123\n8000\nSeldwyla\nCH\n\n\n\n\n\n199.95\nCHF\nS\nSarah Beispiel\nMusterstrasse\n1\n78462\nKonstanz\nDE\nSCOR\nRF18539007547034\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 0, 'code5invalid');
  is($obj->error, "Test failed: Section: 'header' Field: 'qrtype' Value: 'SP'", 'code5error');
}

{
  my $code = "SPC\n0200\n1\nCH5800791123889012\nS\nMax Muster & Söhne\nMusterstrasse\n123\n8000\nSeldwyla\nCH\n\n\n\n\n\n\n\n199.95\nCHF\nS\nSarah Beispiel\nMusterstrasse\n1\n78462\nKonstanz\nDE\nSCOR\nRF18539007547034\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 0, 'code6invalid');
  is($obj->error, "Test failed: Section: 'creditor_information' Field: 'iban' Value: 'CH5800791123889012'", 'code6error');
}

{
  my $code = "SPC\n0200\n1\nCH5204835012345671000\nK\nSample Foundation\nMusterstrasse 55\n3005 Bern\n\n\nCH\n\n\n\n\n\n\n\n\nCHF\n\n\n\n\n\n\n\nNON\n\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 1, 'code7valid');
  is($obj->get_creditor_street_name(), 'Musterstrasse', 'code7street_name');
  is($obj->get_creditor_building_number(), '55', 'code7building_number');
  is($obj->get_creditor_post_code(), '3005', 'code7post_code');
  is($obj->get_creditor_town_name(), 'Bern', 'code7town_name');
}

{
  my $code = "SPC\n0200\n1\nCH5204835012345671000\nK\nSample Foundation\nMusterstrasse 25b\n3005 Bern\n\n\nCH\n\n\n\n\n\n\n\n\nCHF\n\n\n\n\n\n\n\nNON\n\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 1, 'code8valid');
  is($obj->get_creditor_street_name(), 'Musterstrasse', 'code8street_name');
  is($obj->get_creditor_building_number(), '25b', 'code8building_number');
}

{
  my $code = "SPC\n0200\n1\nCH5204835012345671000\nK\nSample Foundation\nMusterstrasse 25 c\n3005 Bern\n\n\nCH\n\n\n\n\n\n\n\n\nCHF\n\n\n\n\n\n\n\nNON\n\n\nEPD\n";
  my $obj = SL::Helper::QrBillParser->new($code);

  is($obj->is_valid, 1, 'code9valid');
  is($obj->get_creditor_street_name(), 'Musterstrasse', 'code9street_name');
  is($obj->get_creditor_building_number(), '25 c', 'code9building_number');
}
