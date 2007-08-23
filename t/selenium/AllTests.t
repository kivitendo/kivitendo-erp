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
# Selenium Main Caller
# Call all Selenium scripts from here. To use Selenium tests in 
# Lx-Office you need to Install Selenium Remote Control. Take a look at 
# the README Document for further informatinons on installing Selenium 
# and testing Lx-Office and of course writing your own testcases.
#
#######################################################################
  no strict;
  push @INC, ['/t/selenium', \&init_server];
  use vars qw( $lxdebug $lxtest $sel );
  use strict;
  use Carp;

  use Test::WWW::Selenium;
  use Test::More qw(no_plan);
  use IO::Socket;

  if(-f "/tmp/lxtest-temp.conf") {
    eval { require('/tmp/lxtest-temp.conf'); };
  }
  else {
    eval { require('t/lxtest.conf'); };
  }
  if ($@) {
    diag("No test configuration found in t/lxtest.conf.\n
    Maybe you forget to copy t/lxtest.conf.default to t/lxtest.conf. Exit test...\n");
  exit 0;
  }

  sub server_is_running {
    return IO::Socket::INET->new(PeerAddr => $ENV{SRC_HOST} || $lxtest->{seleniumhost},
                                 PeerPort => $ENV{SRC_PORT} || $lxtest->{seleniumport},
                                );
  }
  
#   if (server_is_running) {
#     plan tests => 200; # Need to be cutomized
#   }
  sub init_server {
    if(!server_is_running) {
      print "No selenium server found! "
           ."Maybe you forgot to start it or "
           ."the preferences in t/lxtest.conf doesen't fit to your system";
      exit 0;
    }

    diag('Pretests and initialisation');



    $lxtest->{test_id} = time; # create individual ids by unixtime
    $lxtest->{testuserlogin}   = $lxtest->{testlogin} . $lxtest->{test_id} if(!$lxtest->{testuserlogin});
    $lxtest->{testuserpasswd}  = $lxtest->{test_id} if(!$lxtest->{testuserpasswd});
    $lxtest->{db}              = $lxtest->{db} . $lxtest->{test_id} if(!($lxtest->{db} =~ /^seleniumtestdatabase[0-9]{10}$/));

    ok(defined $lxtest->{rpw}, "Get root password");
  
    ok(defined $lxtest->{dbhost}, "found dbhost in config");
    ok(defined $lxtest->{dbport}, "found dbport in config");
    ok(defined $lxtest->{dbuser}, "found dbuser in config");
    ok(defined $lxtest->{dbpasswd}, "found dbpasswd in config");

    $lxtest->{lxadmin_url} = $lxtest->{lxbaseurl} . "admin.pl";
    $lxtest->{lxadmin_with_get} = $lxtest->{lxadmin_url} . "?rpw=$lxtest->{rpw}&nextsub=list_users&action=Weiter";
    $lxtest->{lxadmin} = $lxtest->{lxadmin_url} . "?rpw=$lxtest->{rpw}&nextsub=list_users&action=Weiter";




    eval { $sel = Test::WWW::Selenium->new(
      host => $lxtest->{seleniumhost},
      port => $lxtest->{seleniumport},
      browser => $lxtest->{seleniumbrowser},
      browser_url => $lxtest->{lxadmin},
      auto_stop => '0',
      );
    };
    if ($@) {
      diag("No Selenium Server running, or wrong preferences\n\n");
      exit 0;
    }
    
    ok(defined $sel, 'Creating Selenium Object');

    diag('Starting Selenium tests...');
    
    foreach my $scriptdir (@_) {
      opendir(SCRIPTS, 't/selenium/testscripts/' . $scriptdir);
      foreach (sort readdir(SCRIPTS)) {
        require_ok("t/selenium/testscripts/". $scriptdir . "/" . $_) if ( $_ =~ /^\w\d\d\d.*\.t$/);
      }
      closedir(SCRIPTS);
    }
    if($!) {
      @! = ("Test fehlgeschlagen!");
    }
    $sel->stop();
  }
  
1;
