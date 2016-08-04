# -*- Mode: perl; indent-tabs-mode: nil -*-
#
# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code are the Bugzilla Tests.
#
# The Initial Developer of the Original Code is Zach Lipton
# Portions created by Zach Lipton are
# Copyright (C) 2001 Zach Lipton.  All
# Rights Reserved.
#
# Contributor(s): Zach Lipton <zach@zachlipton.com>
#                 Jacob Steenhagen <jake@bugzilla.org>
#                 David D. Kilzer <ddkilzer@theracingworld.com>


#################
#Bugzilla Test 2#
####GoodPerl#####

use strict;

use lib 't';

use Support::Files;

use Test::More tests => scalar @Support::Files::testitems * 3;

my @testitems = @Support::Files::testitems; # get the files to test.

foreach my $file (@testitems) {
    $file =~ s/\s.*$//; # nuke everything after the first space (#comment)
    next if (!$file); # skip null entries
    if (! open (FILE, $file)) {
        ok(0,"could not open $file --WARNING");
    }
    my $file_line1 = <FILE>;
    close (FILE);

    $file =~ m/.*\.(.*)/;
    my $ext = $1;

    if ($file_line1 !~ m/^#\!/) {
        ok(1,"$file does not have a shebang");
    } else {
        my $flags;
        if (!defined $ext || $ext eq "pl") {
            # standalone programs aren't taint checked yet
            $flags = "w";
        } elsif ($ext eq "pm") {
            ok(0, "$file is a module, but has a shebang");
            next;
        } elsif ($ext eq "cgi") {
            # cgi files must be taint checked
            $flags = "wT";
        } else {
            ok(0, "$file has shebang but unknown extension");
            next;
        }

        if ($file_line1 =~ m#^\#\!/usr/bin/perl\s#) {
            if ($file_line1 =~ m#\s-$flags#) {
                ok(1,"$file uses standard perl location and -$flags");
            } else {
              TODO: {
                local $TODO = q(warning isn't supported globally);
                ok(0,"$file is MISSING -$flags --WARNING");
              }
            }
        } else {
            ok(0,"$file uses non-standard perl location");
        }
    }
}

foreach my $file (@testitems) {
    my $found_use_strict = 0;
    $file =~ s/\s.*$//; # nuke everything after the first space (#comment)
    next if (!$file); # skip null entries
    if (! open (FILE, $file)) {
        ok(0,"could not open $file --WARNING");
        next;
    }
    while (my $file_line = <FILE>) {
        if ($file_line =~ m/^\s*use strict/) {
            $found_use_strict = 1;
            last;
        }
    }
    close (FILE);
    if ($found_use_strict) {
        ok(1,"$file uses strict");
    } else {
        ok(0,"$file DOES NOT use strict --WARNING");
    }
}


# note, the html checker is not really thorough.
# in particular it will not find standard tags with parameters.
# the estimate whether a file is dirty or not is still pretty helpful, as it will catch most of the closing tags.
# if you are in doubt about a specific file, you still have to check it manually.
my $tags = qr/b|i|u|h[1-6]|a href.*|input|form|br|textarea|table|tr|td|th|body|head|html|p|button|select|option|script/;
foreach my $file (@testitems) {
    my $found_html_count = 0;
    my $found_html       = '';
    $file =~ s/\s.*$//; # nuke everything after the first space (#comment)

    next if (!$file); # skip null entries
    if (! open (FILE, $file)) {
        ok(0,"could not open $file --WARNING");
        next;
    }
    while (my $file_line = <FILE>) {
        last if $file_line =~ /^__END__/;
        if ($file_line =~ m/(<\/?$tags>)/o) {
            $found_html_count++;
            $found_html .= $1;
        }
    }
    close (FILE);
    if (!$found_html_count) {
        ok(1,"$file does not contain HTML");
    } elsif ($found_html_count < 50) {
      TODO: { local $TODO = q(Even little amounts of HTML should go away....);
        ok(0,"$file contains at least $found_html_count html tags.");
      }
    } else {
      ok(0,"$file contains at least $found_html_count html tags.");
    }
}

exit 0;
