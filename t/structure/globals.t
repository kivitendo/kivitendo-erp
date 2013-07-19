#!/usr/bin/perl

use strict;
use lib 't';
use Support::Files;
use Support::CanonialGlobals ();

my (@globals, $testcount);

BEGIN {
  @globals = map { s/[^a-z_]//; $_ } @Support::CanonialGlobals::globals;
  $testcount = scalar(@Support::Files::testitems);
}

use Test::More tests => $testcount;

# Capture the TESTOUT from Test::More or Test::Builder for printing errors.
# This will handle verbosity for us automatically.
my $fh;
{
    local $^W = 0;  # Don't complain about non-existent filehandles
    if (-e \*Test::More::TESTOUT) {
        $fh = \*Test::More::TESTOUT;
    } elsif (-e \*Test::Builder::TESTOUT) {
        $fh = \*Test::Builder::TESTOUT;
    } else {
        $fh = \*STDOUT;
    }
}

my @testitems = @Support::Files::testitems;

# at last, here we actually run the test...
my $evilwordsregexp = join('|', @globals);

foreach my $file (@testitems) {
    $file =~ s/\s.*$//; # nuke everything after the first space (#comment)
    next if (!$file); # skip null entries

    if (open (FILE, $file)) { # open the file for reading

        my $found_word = '';

        while (my $file_line = <FILE>) { # and go through the file line by line
            if ($file_line =~ /([\$%@](?:main)?::(?!$evilwordsregexp)\w+\b)/i) { # found an evil word
                $found_word = $1;
                last;
            }
        }

        close (FILE);

        if ($found_word) {
            ok(0,"$file: found UNREGISTERED GLOBAL $found_word --WARNING");
        } else {
            ok(1,"$file does only contain registered globals");
        }
    } else {
        ok(0,"could not open $file for globals check --WARNING");
    }
}

exit 0;

