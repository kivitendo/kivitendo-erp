use Test::More tests => 17;
use Test::Exception;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use Support::TestSetup;
use SL::DB::Part;
use SL::Dev::Part qw(new_part);

Support::TestSetup::login();

SL::DB::Manager::Part->delete_all(all => 1, cascade => 1);

# silence the Test::Harness warn handler
local $SIG{__WARN__} = sub {};

# test simple transaction

my $part = new_part();
SL::DB->client->with_transaction(sub {
  $part->save;
  ok 1, 'part saved';
  1;
}) or do {
  ok 0, 'error saving part';
};

# test failing transaction
my $part2 = new_part(partnumber => $part->partnumber); # woops, duplicate partnumber
SL::DB->client->with_transaction(sub {
  $part2->save;
  ok 0, 'part saved';
  1;
}) or do {
  ok 1, 'saving part with duplicate partnumber generates graceful error';
};

# test transaction with run time exception
dies_ok {
  SL::DB->client->with_transaction(sub {
    $part->method_that_does_not_exist;
    ok 0, 'this should have died';
    1;
  }) or do {
    ok 0, 'this should not get here';
  };
} 'method not found in transaction died as expect';

# test transaction with hook error
# TODO - not possible to test without locally adding hooks in run time

# test if error gets correctly stored in db->error
$part2 = new_part(partnumber => $part->partnumber); # woops, duplicate partnumber
SL::DB->client->with_transaction(sub {
  $part2->save;
  ok 0, 'part saved';
  1;
}) or do {
  like(SL::DB->client->error, qr/unique.constraint/i, 'error is in db->error');
};

# test stacked transactions
# 1. test that it works
SL::DB->client->with_transaction(sub {
  $part->sellprice(1);
  $part->save;

  SL::DB->client->with_transaction(sub {
    $part->sellprice(2);
    $part->save;
  }) or do {
    ok 0, 'error saving part';
  };

  $part->sellprice(3);
  $part->save;
  1;
}) or do {
  ok 0, 'error saving part';
};

$part->load;
is $part->sellprice, "3.00000", 'part saved';

# 2. with a transaction rollback
SL::DB->client->with_transaction(sub {
  $part->sellprice(1);
  $part2->save;
  $part->save;

  SL::DB->client->with_transaction(sub {
    $part->sellprice(2);
    $part->save;
  }) or do {
    ok 0, 'should not get here';
  };

  $part->sellprice(3);
  $part->save;
  ok 0, 'should not get here';
  1;
}) or do {
  ok 1, 'sql error skips rest of the transaction';
};


SL::DB->client->with_transaction(sub {
  $part->sellprice(1);
  $part->save;

  SL::DB->client->with_transaction(sub {
    $part->sellprice(2);
    $part->save;
    $part2->save;
  }) or do {
    ok 0, 'should not get here';
  };

  $part->sellprice(3);
  $part->save;
  ok 0, 'should not get here';
  1;
}) or do {
  ok 1, 'sql error in nested transaction rolls back';
  like(SL::DB->client->error, qr/unique.constraint/i, 'error from nested transaction is in db->error');
};

$part->load;
is $part->sellprice, "3.00000", 'saved part is not affected';



SL::DB->client->with_transaction(sub {
  $part->sellprice(1);
  $part->save;

  SL::DB->client->with_transaction(sub {
    $part->sellprice(2);
    $part->save;
  }) or do {
    ok 0, 'should not get here';
  };

  $part->sellprice(4);
  $part->save;
  $part2->save;
  ok 0, 'should not get here';
  1;
}) or do {
  ok 1, 'sql error after nested transaction rolls back';
};

$part->load;
is $part->sellprice, "3.00000", 'saved part is not affected';

eval {
  SL::DB->client->with_transaction(sub {
    $part->sellprice(1);
    $part->not_existing_function();
    $part->save;

    SL::DB->client->with_transaction(sub {
      $part->sellprice(2);
      $part->save;
    }) or do {
      ok 0, 'should not get here';
    };

    $part->sellprice(4);
    $part->save;
    ok 0, 'should not get here';
    1;
  }) or do {
    ok 0, 'should not get here';
  };
  1;
} or do {
  ok 1, 'runtime exception error before nested transaction rolls back';
};

$part->load;
is $part->sellprice, "3.00000", 'saved part is not affected';

eval {
  SL::DB->client->with_transaction(sub {
    $part->sellprice(1);
    $part->save;

    SL::DB->client->with_transaction(sub {
      $part->sellprice(2);
      $part->not_existing_function();
      $part->save;
    }) or do {
      ok 0, 'should not get here';
    };

    $part->sellprice(4);
    $part->save;
    ok 0, 'should not get here';
    1;
  }) or do {
    ok 0, 'should not get here';
  };
  1;
} or do {
  ok 1, 'runtime exception error in nested transaction rolls back';
};

$part->load;
is $part->sellprice, "3.00000", 'saved part is not affected';


eval {
  SL::DB->client->with_transaction(sub {
    $part->sellprice(1);
    $part->save;

    SL::DB->client->with_transaction(sub {
      $part->sellprice(2);
      $part->save;
    }) or do {
      ok 0, 'should not get here';
    };

    $part->sellprice(4);
    $part->save;
    $part->not_existing_function();
    ok 0, 'should not get here';
    1;
  }) or do {
    ok 0, 'should not get here';
  };
  1;
} or do {
  ok 1, 'runtime exception error after nested transaction rolls back';
};

$part->load;
is $part->sellprice, "3.00000", 'saved part is not affected';
