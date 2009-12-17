#!/usr/bin/perl -pli.orig

#
# template converter -> T8 converter
#
# wanna get rid of those <translate> tags?
# no problem. use this script to fix most it.
#
# use: perl tmpl2t8.pl <file>
#
# will save the original file as file.orig
#
s/$/[% USE T8 %]/ if $. == 1;
s/<translate>([^<]+)<\/translate>/[%- '$1' | \$T8 %]/xg;
