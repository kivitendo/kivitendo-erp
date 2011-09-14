find t | grep "\.t$" | grep -v '^t/old' | HARNESS_OPTIONS=j:c xargs perl -MTest::Harness -e 'runtests(@ARGV)'
