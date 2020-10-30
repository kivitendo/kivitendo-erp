use Test::More tests => 60;

use lib 't';

use Data::Dumper;

use DateTime;
use_ok 'SL::Helper::DateTime';

my $local_tz   = DateTime::TimeZone->new(name => 'local');
my $mon_012345 = DateTime->new(year => 2014, month => 6, day => 23, hour => 1, minute => 23, second => 45, time_zone => $local_tz);

sub mon { DateTime->new(year => 2014, month => 6, day => 23) }
sub tue { DateTime->new(year => 2014, month => 6, day => 24) }
sub wed { DateTime->new(year => 2014, month => 6, day => 25) }
sub thu { DateTime->new(year => 2014, month => 6, day => 26) }
sub fri { DateTime->new(year => 2014, month => 6, day => 27) }
sub sat { DateTime->new(year => 2014, month => 6, day => 28) }
sub sun { DateTime->new(year => 2014, month => 6, day => 29) }


is mon->add_businessdays(days => 5)->day_of_week, 1, "mon + 5 => mon";
is mon->add_businessdays(days => 12)->day_of_week, 3, "mon + 12 => wed";
is fri->add_businessdays(days => 2)->day_of_week, 2, "fri + 2 => tue";
is tue->add_businessdays(days => 9)->day_of_week, 1, "tue + 9 => mon";
is tue->add_businessdays(days => 8)->day_of_week, 5, "tue + 8 => fri";

# same with 6day week
is mon->add_businessdays(businessweek => 6, days => 5)->day_of_week, 6, "mon + 5 => sat (6dw)";
is mon->add_businessdays(businessweek => 6, days => 12)->day_of_week, 1, "mon + 12 => mon (6dw)";
is fri->add_businessdays(businessweek => 6, days => 2)->day_of_week, 1, "fri + 2 => mon (6dw)";
is tue->add_businessdays(businessweek => 6, days => 9)->day_of_week, 5, "tue + 9 => fri (6dw)";
is tue->add_businessdays(businessweek => 6, days => 8)->day_of_week, 4, "tue + 8 => thu (6dw)";

# absolute dates

is mon->add_businessdays(days => 5), mon->add(days => 7), "mon + 5 => mon (date)";
is mon->add_businessdays(days => 12), mon->add(days => 16), "mon + 12 => wed (date)";
is fri->add_businessdays(days => 2), fri->add(days => 4), "fri + 2 => tue (date)";
is tue->add_businessdays(days => 9), tue->add(days => 13), "tue + 9 => mon (date)";
is tue->add_businessdays(days => 8), tue->add(days => 10), "tue + 8 => fri (date)";

# same with 6day week
is mon->add_businessdays(businessweek => 6, days => 5), mon->add(days => 5), "mon + 5 => sat (date) (6dw)";
is mon->add_businessdays(businessweek => 6, days => 12), mon->add(days => 14), "mon + 12 => mon (date) (6dw)";
is fri->add_businessdays(businessweek => 6, days => 2), fri->add(days => 3), "fri + 2 => mon (date) (6dw)";
is tue->add_businessdays(businessweek => 6, days => 9), tue->add(days => 10), "tue + 9 => fri (date) (6dw)";
is tue->add_businessdays(businessweek => 6, days => 8), tue->add(days => 9), "tue + 8 => thu (date) (6dw)";


# same with subtract

is mon->subtract_businessdays(days => 5)->day_of_week, 1, "mon - 5 => mon";
is mon->subtract_businessdays(days => 12)->day_of_week, 4, "mon - 12 => thu";
is fri->subtract_businessdays(days => 2)->day_of_week, 3, "fri - 2 => wed";
is tue->subtract_businessdays(days => 9)->day_of_week, 3, "tue - 9 => wed";
is tue->subtract_businessdays(days => 8)->day_of_week, 4, "tue - 8 => thu";

# same with 6day week
is mon->subtract_businessdays(businessweek => 6, days => 5)->day_of_week, 2, "mon - 5 => tue (6dw)";
is mon->subtract_businessdays(businessweek => 6, days => 12)->day_of_week, 1, "mon - 12 => mon (6dw)";
is fri->subtract_businessdays(businessweek => 6, days => 4)->day_of_week, 1, "fri - 4 => mon (6dw)";
is tue->subtract_businessdays(businessweek => 6, days => 9)->day_of_week, 5, "tue - 9 => fri (6dw)";
is tue->subtract_businessdays(businessweek => 6, days => 8)->day_of_week, 6, "tue - 8 => sat (6dw)";

# absolute dates

is mon->subtract_businessdays(days => 5), mon->add(days => -7), "mon - 5 => mon (date)";
is mon->subtract_businessdays(days => 12), mon->add(days => -18), "mon - 12 => thu (date)";
is fri->subtract_businessdays(days => 2), fri->add(days => -2), "fri - 2 => wed (date)";
is tue->subtract_businessdays(days => 9), tue->add(days => -13), "tue - 9 => wed (date)";
is tue->subtract_businessdays(days => 8), tue->add(days => -12), "tue - 8 => thu (date)";

# same with 6day week
is mon->subtract_businessdays(businessweek => 6, days => 5), mon->add(days => -6), "mon - 5 => tue (date) (6dw)";
is mon->subtract_businessdays(businessweek => 6, days => 12), mon->add(days => -14), "mon - 12 => mon (date) (6dw)";
is fri->subtract_businessdays(businessweek => 6, days => 4), fri->add(days => -4), "fri - 4 => mon (date) (6dw)";
is tue->subtract_businessdays(businessweek => 6, days => 9), tue->add(days => -11), "tue - 9 => fri (date) (6dw)";
is tue->subtract_businessdays(businessweek => 6, days => 8), tue->add(days => -10), "tue - 8 => sat (date) (6dw)";

# add with negative days?
is mon->add_businessdays(businessweek => 6, days => -5), mon->add(days => -6), "mon - 5 => tue (date) (6dw)";
is mon->add_businessdays(businessweek => 6, days => -12), mon->add(days => -14), "mon - 12 => mon (date) (6dw)";
is fri->add_businessdays(businessweek => 6, days => -4), fri->add(days => -4), "fri - 4 => mon (date) (6dw)";
is tue->add_businessdays(businessweek => 6, days => -9), tue->add(days => -11), "tue - 9 => fri (date) (6dw)";
is tue->add_businessdays(businessweek => 6, days => -8), tue->add(days => -10), "tue - 8 => sat (date) (6dw)";

# what if staring date falls into eekend?
is sun->add_businessdays(days => 1), sun->add(days => 1), "1 day after sun is mon";
is sat->add_businessdays(days => 1), sat->add(days => 2), "1 day after sut is mon";
is sun->add_businessdays(days => -1), sun->add(days => -2), "1 day before sun is fri";
is sat->add_businessdays(days => -1), sat->add(days => -1), "1 day before sut is fri";

# parsing YYYY-MM-DD formatted strings
is(DateTime->from_ymd(),                                 undef,                                     "no argument results in undef");
is(DateTime->from_ymd(''),                               undef,                                     "empty argument results in undef");
is(DateTime->from_ymd('chunky bacon'),                   undef,                                     "invalid argument results in undef");
is(DateTime->from_ymd('2014-06-23'),                     $mon_012345->clone->truncate(to => 'day'), "2014-06-23 is parsed correctly");
is(DateTime->from_ymd('2014-06-23')->strftime('%H%M%S'), '000000',                                  "2014-06-23 is parsed correctly");

# parsing YYYY-MM-DDTHH:MM:SS formatted strings
is(DateTime->from_ymdhms(),                      undef,       "no argument results in undef");
is(DateTime->from_ymdhms(''),                    undef,       "empty argument results in undef");
is(DateTime->from_ymdhms('chunky bacon'),        undef,       "invalid argument results in undef");
is(DateTime->from_ymdhms('2014-06-23T01:23:45'), $mon_012345, "2014-06-23T01:23:45 is parsed correctly");
is(DateTime->from_ymdhms('2014-06-23 01:23:45'), $mon_012345, "2014-06-23 01:23:45 is parsed correctly");
