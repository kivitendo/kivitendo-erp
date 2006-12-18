#=====================================================================
# LX-Office ERP
# Copyright (C) 2006
# Web http://www.lx-office.org
#
#=====================================================================
#
#  Author: Udo Spallek
#   Email: udono@gmx.net
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
# Selenium Cleanup Script
# To clean up all the messy databases and users while debugging testcases
# 
#######################################################################
  no strict;
  push @INC, ['/t/selenium'];
  use vars qw( $lxdebug $lxtest $sel );
  use strict;
  use Carp;

  use WWW::Selenium;
  use IO::Socket;

  my $cleanedupdb = '';
  my $cleanedupusers = '';

  eval { require('t/lxtest.conf'); };
  if ($@) {
    print "No test configuration found in t/lxtest.conf.\n
    Maybe you forget to copy t/lxtest.conf.default to t/lxtest.conf. Exit test...\n";
  exit 0;
  };

  sub server_is_running {
    return IO::Socket::INET->new(PeerAddr => $ENV{SRC_HOST} || $lxtest->{seleniumhost},
                                 PeerPort => $ENV{SRC_PORT} || $lxtest->{seleniumport},
                                );
  }
  if (server_is_running) {
  }
  else {
    exit 0;
  }

  $lxtest->{testuserlogin}   = $lxtest->{testlogin};
  $lxtest->{db}              = $lxtest->{db};

  $lxtest->{lxadmin} = $lxtest->{lxbaseurl} . "admin.pl?path=$lxtest->{path}&rpw=$lxtest->{rpw}&nextsub=list_users&action=Weiter";

  eval { $sel = WWW::Selenium->new(
    host => $lxtest->{seleniumhost},
    port => $lxtest->{seleniumport},
    browser => $lxtest->{seleniumbrowser},
    browser_url => $lxtest->{lxadmin},
    auto_stop => '0',
    );
  };
  if ($@) {
    print "No Selenium Server running, or wrong preferences\n\n";
    exit 0;
  }


  print "\nStarting Testdebugging Cleanup...\n";


### Delete user

$sel->start;
print "Cleanup all users '$lxtest->{testuserlogin}*'\n";
$sel->open($lxtest->{lxadmin});

my @links= $sel->get_all_links();
my $testuserlogin = $lxtest->{testuserlogin};

foreach my $link (@links) {

  if ($link =~ /$testuserlogin\d\d\d\d\d\d\d\d\d\d/){
    $sel->click("link=$lxtest->{testuserlogin}11*");
    $sel->wait_for_page_to_load($lxtest->{timeout});
    $sel->click("//input[(\@name=\"action\") and (\@value=\"Löschen\")]");
    $sel->wait_for_page_to_load($lxtest->{timeout});
    $cleanedupusers .= "     $link\n";
  }
}

print "Lock the system\n";
$sel->click("//input[(\@name=\"action\") and (\@value=\"System sperren\")]");
$sel->wait_for_page_to_load($lxtest->{timeout});

print "Cleanup all test databasees: '$lxtest->{db}*'\n";

  $sel->click("//input[(\@name=\"action\") and (\@value=\"Datenbankadministration\")]");
  $sel->wait_for_page_to_load($lxtest->{timeout});
  $sel->type("dbhost", $lxtest->{dbhost});
  $sel->type("dbport", $lxtest->{dbport});
  $sel->type("dbuser", $lxtest->{dbuser});
  $sel->type("dbpasswd", $lxtest->{dbpasswd});
 
  $sel->click("//input[(\@name=\"action\") and (\@value=\"Datenbank löschen\")]");
  $sel->wait_for_page_to_load($lxtest->{timeoutlong});

  my $field = $sel->get_body_text();
  my $database= $lxtest->{db};
  my @fields = split('  ', $field);

  
  foreach my $field (@fields) {

    if ($field =~ /$database\d\d\d\d\d\d\d\d\d\d/){
      $sel->open($lxtest->{lxadmin});
      $sel->click("//input[(\@name=\"action\") and (\@value=\"Datenbankadministration\")]");
      $sel->wait_for_page_to_load($lxtest->{timeout});
      $sel->type("dbhost", $lxtest->{dbhost});
      $sel->type("dbport", $lxtest->{dbport});
      $sel->type("dbuser", $lxtest->{dbuser});
      $sel->type("dbpasswd", $lxtest->{dbpasswd});
     
      $sel->click("//input[(\@name=\"action\") and (\@value=\"Datenbank löschen\")]");
      $sel->wait_for_page_to_load($lxtest->{timeoutlong});
      $sel->check("name=db value=$field"); 
      $sel->click("//input[(\@name=\"action\") and (\@value=\"Weiter\")]");
      $cleanedupdb .= "     $field\n";
      
    }
  }
  
$sel->open($lxtest->{lxadmin});
print "Unlock the system\n";

$sel->click("//input[(\@name=\"action\") and (\@value=\"System entsperren\")]");
$sel->wait_for_page_to_load($lxtest->{timeout});

$cleanedupdb = "none.\n" if ($cleanedupdb eq '');
$cleanedupusers = "none.\n" if ($cleanedupusers eq '');

print "Ready. \nReport:\n--- Cleaned up Users:\n$cleanedupusers---Cleaned up Databases:\n$cleanedupdb";

$sel->stop;

exit 1;


