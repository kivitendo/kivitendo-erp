#!/usr/local/bin/perl -pli.orig

#
# perlcode -> template converter
#
# there's ugly perl generated html in your xy.pl?
# no problem. copy&paste it into a separate html file, remove 'qq|' and '|;' and use this script to fix most of the rest.
#
# use: perl pl2tmpl.pl <file>
#
# will save the original file as file.orig
#

s/\$form->\{(?:"([^}]+)"|([^}]+))\}/[% $+ %]/g;
s/\| \s* \. \s* \$locale->text \( ' ([^']+) ' \) \s* \. \s* qq\|/<translate>$1<\/translate>/xg;
s/\| \s* \. \s* \$locale->text \( " ([^"]+) " \) \s* \. \s* qq\|/<translate>$1<\/translate>/xg;
