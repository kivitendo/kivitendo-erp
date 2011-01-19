#!/usr/bin/perl

BEGIN {
  unshift @INC, "modules/override"; # Use our own versions of various modules (e.g. YAML).
  push    @INC, "modules/fallback"; # Only use our own versions of modules if there's no system version.
}

use DBI;
use Data::Dumper;

use SL::LXDebug;

use SL::Form;
use SL::Template;

$sendmail   = "| /usr/sbin/sendmail -t";

$| = 1;

$lxdebug = LXDebug->new();

$form = new Form;
$form->{"script"} = "oe.pl";

$ENV{'HOME'} = getcwd() . "/$userspath";

my $template = SL::Template::create(type => 'OpenDocument', file_name => '', form => $form, myconfig => \%myconfig, userspath => $userspath);

if (@ARGV && ($ARGV[0] eq "-r")) {
  system("ps auxww | " .
         "grep -v awk | " .
         "awk '/^www-data.*(soffice|Xvfb)/ { print \$2 }' | " .
         "xargs -r kill");
  sleep(10);
}

exit(1) unless ($template->spawn_xvfb());
exit(2) unless ($template->spawn_openoffice());
exit(0);
