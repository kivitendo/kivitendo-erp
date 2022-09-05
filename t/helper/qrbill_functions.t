use Test::More tests => 22;

use strict;

use lib 't';
use Support::TestSetup;

use_ok('SL::Helper::QrBillFunctions', qw(assemble_ref_number get_ref_number_formatted
  get_iban_formatted get_amount_formatted));

Support::TestSetup::login();

# assemble_ref_number returns successfully
is_deeply([ assemble_ref_number('123123', 'c1', 'R2022-02') ],
          [ '123123000001000000002022027', undef ],
          'assemble_ref_number_ok1');
is_deeply([ assemble_ref_number('123123', 'c144', 'R5002') ],
          [ '123123000144000000000050026', undef ],
          'assemble_ref_number_ok2');

# assemble_ref_number returns an error
is_deeply([ assemble_ref_number('1231234', 'c1', 'R2022-02') ],
          [ undef, $::locale->text('Bank account id number invalid. Must be 6 digits.') ],
          'assemble_ref_number_err_bank_account_id_too_long ');
is_deeply([ assemble_ref_number('123A12', 'c1', 'R2022-02') ],
          [ undef, $::locale->text('Bank account id number invalid. Must be 6 digits.') ],
          'assemble_ref_number_err_bank_account_id_with_letter');
is_deeply([ assemble_ref_number('123123', 'c1234567', 'R2022-02') ],
          [ undef, $::locale->text('Customer number invalid. Must be less then or equal to 6 digits after non-digits removed.') ],
          'assemble_ref_number_err_customer_number_too_long');
is_deeply([ assemble_ref_number('123123', 'c1', 'R2022-02-5000-3400-5') ],
          [ undef, $::locale->text('Invoice number invalid. Must be less then or equal to 14 digits after non-digits removed.') ],
          'assemble_ref_number_err_invoice_number_too_long');

is(get_ref_number_formatted('123123000001000000002022027'),
   '12 31230 00001 00000 00020 22027',
   'get_ref_number_formatted');

is(get_iban_formatted('CH4431999123000889012'),
   'CH44 3199 9123 0008 8901 2',
   'get_iban_formatted');

is(get_amount_formatted('1000.00'), '1 000.00', 'get_amount_formatted_1000');
is(get_amount_formatted('1.20'), '1.20', 'get_amount_formatted_1');
is(get_amount_formatted('12.20'), '12.20', 'get_amount_formatted_12');
is(get_amount_formatted('980.20'), '980.20', 'get_amount_formatted_980');
is(get_amount_formatted('12500.30'), '12 500.30', 'get_amount_formatted_12500');
is(get_amount_formatted('125400.22'), '125 400.22', 'get_amount_formatted_125400');
is(get_amount_formatted('1255300.30'), '1 255 300.30', 'get_amount_formatted_1255300');
is(get_amount_formatted('12553400.30'), '12 553 400.30', 'get_amount_formatted_12553400');
is(get_amount_formatted('122.'), undef, 'get_amount_formatted_122err');
is(get_amount_formatted('123'), undef, 'get_amount_formatted_123err');
is(get_amount_formatted('12,4'), undef, 'get_amount_formatted_124err');
is(get_amount_formatted('10 5'), undef, 'get_amount_formatted_105err');
is(get_amount_formatted('10a'), undef, 'get_amount_formatted_10aerr');
