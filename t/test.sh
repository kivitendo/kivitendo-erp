find t | grep "\.t$" | grep -v '^t/old' | HARNESS_OPTIONS=j:c xargs perl -Imodules/fallback -MTest::Harness -e 'BEGIN { unshift @INC, "modules/override" } runtests(@ARGV)'
