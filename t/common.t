use strict;

use Test::More;

use lib 't';
use Support::TestSetup;

Support::TestSetup::login();

use SL::Common;

sub test_truncate {
  is(Common::truncate('nothing to do', at => -1),  '...',           'truncation length < 0: at least 3');
  is(Common::truncate('nothing to do', at => 0),   '...',           'truncation length = 0: at least 3');
  is(Common::truncate('nothing to do', at => 1),   '...',           'truncation length = 1: at least 3');
  is(Common::truncate('nothing to do', at => 2),   '...',           'truncation length = 2: at least 3');
  is(Common::truncate('nothing to do', at => 3),   '...',           'truncation length = 3: at least 3');
  is(Common::truncate('nothing to do', at => 4),   'n...',          'truncation length = 4');
  is(Common::truncate('nothing to do', at => 9),   'nothin...',     'text length equal to truncation + 4');
  is(Common::truncate('nothing to do', at => 10),  'nothing...',    'text length equal to truncation + 3');
  is(Common::truncate('nothing to do', at => 11),  'nothing ...',   'text length equal to truncation + 2');
  is(Common::truncate('nothing to do', at => 12),  'nothing t...',  'text length equal to truncation + 1');
  is(Common::truncate('nothing to do', at => 13),  'nothing to do', 'text length equal to truncation');
  is(Common::truncate('nothing to do', at => 14),  'nothing to do', 'text length equal to truncation - 1');
  is(Common::truncate('nothing to do', at => 15),  'nothing to do', 'text length equal to truncation - 2');
  is(Common::truncate('nothing to do', at => 16),  'nothing to do', 'text length equal to truncation - 3');
  is(Common::truncate('nothing to do', at => 200), 'nothing to do', 'text length smaller than truncation');

  is(Common::truncate('012345678901234567890123456789012345678901234567890123456789'), '01234567890123456789012345678901234567890123456...', 'default truncation length of 50');

  # Test stripping
  is(Common::truncate("nothing\n\rat\rall\n\n", at => 50, strip => 1), "nothing\n\rat\rall", 'strip = 1, at = 50');
  is(Common::truncate("nothing\n\rat\rall\n\n", at => 13, strip => 1), "nothing\n\ra...",    'strip = 1, at = 13');

  is(Common::truncate("nothing\n\rat\rall\n\n", at => 50, strip => 'full'), "nothing at all", 'strip = full, at = 50');
  is(Common::truncate("nothing\n\rat\rall\n\n", at => 13, strip => 'full'), "nothing at...",  'strip = full, at = 13');

  is(Common::truncate("nothing\n\rat\rall\n\n", at => 50, strip => 'newlines'), "nothing at all", 'strip = newlines, at = 50');
  is(Common::truncate("nothing\n\rat\rall\n\n", at => 13, strip => 'newlines'), "nothing at...",  'strip = newlines, at = 13');

  is(Common::truncate("nothing\n\rat\rall\n\n", at => 50, strip => 'newline'), "nothing at all", 'strip = newline, at = 50');
  is(Common::truncate("nothing\n\rat\rall\n\n", at => 13, strip => 'newline'), "nothing at...",  'strip = newline, at = 13');
}

test_truncate();

done_testing;

1;
