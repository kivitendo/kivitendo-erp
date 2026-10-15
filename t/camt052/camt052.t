
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


  # test files do not have end_to_end_id or remote account information set

  for my $tx (@transactions) {
    ok $tx->{line_number},          "file '$file', entry $i, line_number is set";
    ok $tx->{currency},             "file '$file', entry $i, currency is set";
    ok $tx->{amount},               "file '$file', entry $i, amount is set";
    ok $tx->{reference},            "file '$file', entry $i, reference is set";
#    ok $tx->{transaction_code},     "file '$file', entry $i, tx code is set";   # switft don't exist in camt.052
    ok $tx->{local_bank_code},      "file '$file', entry $i, local bank code is set";
    ok $tx->{local_account_number}, "file '$file', entry $i, local acct number is set";
#    ok $tx->{end_to_end_id},        "file '$file', entry $i, e2e id is set";
    ok $tx->{purpose},              "file '$file', entry $i, purpose is set";
#    ok $tx->{remote_name},          "file '$file', entry $i, remote name is set";
#    ok $tx->{remote_bank_code},     "file '$file', entry $i, remote bank code is set";
#    ok $tx->{remote_account_number},"file '$file', entry $i, remote account number is set";


    $i++;
  }
}

done_testing();
