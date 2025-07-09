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
# The Original Code are the Bugzilla tests.
#
# The Initial Developer of the Original Code is Jacob Steenhagen.
# Portions created by Jacob Steenhagen are
# Copyright (C) 2001 Jacob Steenhagen. All
# Rights Reserved.
#
# Contributor(s): Jacob Steenhagen <jake@bugzilla.org>
#                 Zach Lipton <zach@zachlipton.com>
#                 David D. Kilzer <ddkilzer@kilzer.net>
#                 Tobias Burnus <burnus@net-b.de>
#

#################
#Bugzilla Test 4#
####Templates####

use strict;

use lib 't';

use Support::Templates;

use File::Spec;
use File::Slurp;
use Template;
use Test::More tests => ( scalar(@referenced_files));

my $template_path = 'templates/design40_webpages/';

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

# test master files for <translate> tag
foreach my $ref (@Support::Templates::referenced_files) {
    my $file = "${template_path}${ref}.html";
    my $data = read_file($file) || die "??? couldn't open $file";
    if ($data =~ /<translate>/) {
        ok(0, "$file uses deprecated <translate> tags.");
    } else {
        ok(1, "$file does not use <translate> tags.");
    }
}

exit 0;
