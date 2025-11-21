
use strict;
use lib 't';

use Test::More;
use DateTime;
use SL::Helper::DateTime;

use_ok "SL::Camt053";

my @transactions = SL::Camt053->parse_file('t/camt053/test-camt053');

is 0+@transactions, 3;

is $transactions[0]{line_number},           1;
is $transactions[0]{currency},              'EUR';
is $transactions[0]{transdate}->ymd,        '2014-01-05';
is $transactions[0]{valutadate}->ymd,       '2014-01-05';
is $transactions[0]{amount},                '-754.25';
is $transactions[0]{reference},             'INNDNL2U20141231000142300002844';
#is $transactions[0]{transaction_code},      '';  # not well defined
is $transactions[0]{local_bank_code},       'ABNANL2A';
is $transactions[0]{local_account_number},  'NL77ABNA0574908765';
is $transactions[0]{end_to_end_id},         '435005714488-ABNO33052620';
is $transactions[0]{purpose},               'Insurance policy 857239PERIOD 01.01.2014 - 31.12.2014';
is $transactions[0]{remote_name},           'INSURANCE COMPANY TESTX';
is $transactions[0]{remote_bank_code},      'ABNANL2A';
is $transactions[0]{remote_account_number}, 'NL46ABNA0499998748';

done_testing();
