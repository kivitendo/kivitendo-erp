#=====================================================================
# LX-Office ERP
# Copyright (C) 2006/2007
# Web http://www.lx-office.org
#
#=====================================================================
#
#  Author: Udo Spallek, Thomas Kasulke
#   Email: udono@gmx.net, tkasulke@linet-services.de
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Main Test Module: 
# For collecting all the tests in nice Test::Harness environment.
# Study the README for Selenium Installation and testing process 
# and enjoy starting
# #perl t/lx-office.t
# against the unstable release
#======================================================================

  use warnings FATAL => 'all';
  use diagnostics;
  use Carp;
  use Test::Harness;

  my %tests = ("all" => 't/selenium/TestAllTests.t',
               "system" => 't/selenium/TestSystem.t',
               "selling" => 't/selenium/TestSelling.t',
               "masterdata" => 't/selenium/TestMasterData.t',
               "testbed" => 't/selenium/TestCreateTestbed.t',
               "admin" => 't/selenium/TestAdmin.t',
               "accounting" => 't/selenium/TestAccounting.t',
               "payments" => 't/selenium/TestPayments.t',
               "printing" => 't/selenium/TestPrinting.t',
               "programm" => 't/selenium/TestProgramm.t',
               "reports" => 't/selenium/TestReports.t' );
  my $testonly = 0;
  my $nodb = 0;
  my @totest;
  
  eval { require('t/lxtest.conf'); };
  my %lxtest = %{ $lxtest } if ($lxtest);

  sub usage
  {
    print "\n$0 --- creates testscenarios while using Selenium testcases for Lx-Office\n";
    printf "\t\tusage: perl [PERLOPTIONS] $0 [--help] [OPTIONS] [ARGUMENTS]\n\t\t%s\n", "\xAF" x 6;
    print "\t\t --help\t\tshow this usage\n\n";
    printf "\t\toptions:\n\t\t%s\n", "\xAF" x 8;
    print "\t\t  -masterdata\tonly runs testscripts for \"masterdata\"\n";
    print "\t\t  -accounting\tonly runs testscripts for \"accounting\"\n";
    print "\t\t  -system\tonly runs testscripts for \"system\"\n";
    print "\t\t  -payments\tonly runs testscripts for \"payments\"\n";
    print "\t\t  -programm\tonly runs testscripts for \"programm\"\n";
    print "\t\t  -printing\tonly runs testscripts for \"printing\"\n";
    print "\t\t  -reports\tonly runs testscripts for \"reports\"\n";
    print "\t\t  -selling\tonly runs testscripts for \"selling\"\n";
    print "\t\t  -purchase\tonly runs testscripts for \"purchase\"\n";
    print "\t\t  -admin\tonly runs testscripts for \"administration\"\n";
    print "\t\t  -testbed\tcreates a standardized test database\n";
    print "\t\t  -nodb\t\tdoesn't create a db! Only use with \n\t\t\t\t--username, --userpasswd, --dbname, --dbport, --dbhost, --dbuser, --dbpasswd, --rootpasswd arguments!\n";
    print "\t\t  -testsonly\tfinally shows all tests available only\n";
    printf "\n\t\targuments:\n\t\t%s\n","\xAF" x 10;
    print "\t\t  --username=\tuser login name\n";
    print "\t\t  --userpasswd=\tuser login password\n";
    print "\t\t  --dbname=\tname of used db (leave empty whether dbname is seleniumtestdatabase)\n";
    print "\t\t  --dbport=\tport of used db (leave empty whether port is 5432)\n";
    print "\t\t  --dbhost=\thost of used db (leave empty whether host is localhost [127.0.0.1])\n";
    print "\t\t  --dbuser=\tdb username (leave empty whether name is postgres)\n";
    print "\t\t  --dbpasswd=\tthe password for used db (leave empty while none)\n";
    print "\t\t  --rootpasswd=\troot password for admin.pl login\n";
    printf "\t\t  NOTE: Configuration in lxtest.conf will be temporaly overwritten by using this arguments!\n\t\t %s\n", "\xAF" x 6;
    exit;
  }
  
  while ( $#ARGV>=0 )
  {
    $_ = $ARGV[0];

    if ( /^--help$/ ) { usage; last }
    if ( /^-testonly$/) { $testonly = 1; shift; next }
    if ( /^-nodb$/ ) { $nodb = 1; shift; next }
    if ( /^-(masterdata)$/ ) { push @totest, $1; shift; next }
    if ( /^-(system)$/ ) { push @totest, $1; shift; next }
    if ( /^-(selling)$/ ) { push @totest, $1; shift; next }
    if ( /^-(purchase)$/ ) { push @totest, $1; shift; next }
    if ( /^-(testbed)$/ ) { push @totest, $1; shift; next }
    if ( /^-(admin)$/ ) { push @totest, $1; shift; next }
    if ( /^--username=(.*)$/ ) { $lxtest{testuserlogin} = $1; shift; next }
    if ( /^--userpasswd=(.*)$/ ) { $lxtest{testuserpasswd} = $1; shift; next }
    if ( /^--dbname=(.*)$/ ) { $lxtest{db} = $1; shift; next }
    if ( /^--dbport=(.*)$/ ) { $lxtest{dbport} = $1; shift; next }
    if ( /^--dbhost=(.*)$/ ) { $lxtest{dbhost} = $1; shift; next }
    if ( /^--dbuser=(.*)$/ ) { $lxtest{dbuser} = $1; shift; next }
    if ( /^--dbpasswd=(.*)$/ ) { $lxtest{dbpasswd} = $1; shift; next }
    if ( /^--rootpasswd=(.*)$/ ) { $lxtest{rpw} = $1; shift; next }
    if ( /^([A-Z].*)$/ ) { push @totest, shift; next }
    if ( /^-/ ) {
        print STDERR "$0: ERROR: unrecognized option '$_' ?\n";
        usage;
    }
    last;
  }
  
  open TEMPCONF, "+>/tmp/lxtest-temp.conf";
  print TEMPCONF '$lxtest = {'."\n";
  foreach (keys(%lxtest)) {
    print TEMPCONF '"' . $_ . '" => "' . $lxtest{$_} . "\",\n";
  }
  print TEMPCONF '};';
  close TEMPCONF;

  my $testscriptdir = 't/selenium/testscripts/';
  opendir(ROOT, $testscriptdir);
  foreach my $dir ( readdir( ROOT ) ) {
    if(-d $testscriptdir . $dir && $dir ne "begin" && $dir ne "end" && $dir ne "..") {
      opendir(DIR, $testscriptdir . $dir . "/begin");
      foreach ( readdir(DIR) ) {
        $tests{ substr ( substr( $_, 4 ), 0, -2 ) } = $testscriptdir . ($dir eq "." ? "" : $dir . "/") . "begin/" . $_ if ( $_ =~ /^\w\d\d\d.*\.t$/ );
      }
      closedir(DIR);
      opendir(DIR, $testscriptdir . $dir . "/end");
      foreach (readdir(DIR)) {
        $tests{ substr ( substr( $_, 4 ), 0, -2 ) } = $testscriptdir . ($dir eq "." ? "" : $dir . "/") . "end/" . $_ if ( $_ =~ /^\w\d\d\d.*\.t$/ );
      }
      closedir(DIR);
    }
  }
  closedir(ROOT);
  
  push @totest, "all" if(!$totest[0]);
  

## Backendtests:
#  &runtests(
#  );  
  

## Frontendtests:
  
  foreach (@totest) {
    &runtests(
      $tests{$_},
    ) if (!$testonly);
  }
  if($testonly) {
    printf "\tFollowing testscripts are present:\n\t%s\n","\xAF" x 34;;
    foreach (sort(keys(%tests))) {
      print "\t\t" . $_ ."\n" if( /^[A-Z].*$/ );
    }
    printf "\n\t\%s\n\t%s\n","Be ensure, that usage is promitted by login and db status!","\xAF" x 58;
  }

exit 1;