find t | grep "\.t$" | grep -v '^t/old' | xargs perl -MExtUtils::Command::MM -e 'test_harness(0)'
