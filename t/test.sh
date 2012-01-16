find t | grep "\.t$" | grep -v '^t/old' | HARNESS_OPTIONS=j:c xargs perl -Imodules/override -MTest::Harness -e 'BEGIN { push @INC, "modules/fallback" } runtests(@ARGV)'
