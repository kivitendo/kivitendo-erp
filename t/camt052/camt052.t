
use strict;
use lib 't';

use Test::More;
use DateTime;
use SL::Helper::DateTime;
use File::Find;

use_ok "SL::Camt052";

File::Find::find(sub {
  return unless /xml$/;

#   diag "found file $_";
  my @transactions = SL::Camt052->parse_file($_);
  test_tx($_, @transactions);
}, "t/camt052/tests");

sub test_tx {
  my ($file, @transactions) = @_;

  my $i = 0;

  for my $tx (@transactions) {
    ok $tx->{line_number},          "file '$file', entry $i, line_number is set";
    ok $tx->{currency},             "file '$file', entry $i, currency is set";
    ok $tx->{amount},               "file '$file', entry $i, amount is set";
    ok $tx->{reference},            "file '$file', entry $i, reference is set";
#    ok $tx->{transaction_code},     "file '$file', entry $i, tx code is set";   # switft don't exist in camt.052
    ok $tx->{local_bank_code},      "file '$file', entry $i, local bank code is set";
    ok $tx->{local_account_number}, "file '$file', entry $i, local acct number is set";
    ok $tx->{end_to_end_id},        "file '$file', entry $i, e2e id is set";
    ok $tx->{purpose},              "file '$file', entry $i, purpose is set";
    ok $tx->{remote_name},          "file '$file', entry $i, remote name is set";
    ok $tx->{remote_bank_code},     "file '$file', entry $i, remote bank code is set";
    ok $tx->{remote_account_number},"file '$file', entry $i, remote account number is set";


    $i++;
  }
}


# is 0+@transactions, 3;
#
# is $transactions[0]{line_number},           1;
# is $transactions[0]{currency},              'EUR';
# is $transactions[0]{transdate}->ymd,        '2014-01-05';
# is $transactions[0]{valutadate}->ymd,       '2014-01-05';
# is $transactions[0]{amount},                '-754.25';
# is $transactions[0]{reference},             'INNDNL2U20141231000142300002844';
# #is $transactions[0]{transaction_code},      '';  # not well defined
# is $transactions[0]{local_bank_code},       'ABNANL2A';
# is $transactions[0]{local_account_number},  'NL77ABNA0574908765';
# is $transactions[0]{end_to_end_id},         '435005714488-ABNO33052620';
# is $transactions[0]{purpose},               'Insurance policy 857239PERIOD 01.01.2014 - 31.12.2014';
# is $transactions[0]{remote_name},           'INSURANCE COMPANY TESTX';
# is $transactions[0]{remote_bank_code},      'ABNANL2A';
# is $transactions[0]{remote_account_number}, 'NL46ABNA0499998748';
#
done_testing();
