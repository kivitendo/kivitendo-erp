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
# Selenium Main Caller
# Call all Selenium scripts from here. To use Selenium tests in 
# Lx-Office you need to Install Selenium Remote Control. Take a look at 
# the README Document for further informatinons on installing Selenium 
# and testing Lx-Office and of course writing your own testcases.
#
#######################################################################
  no strict;
  push @INC, ['/t/selenium'];
  use vars qw( $lxdebug $lxtest $sel );
  use strict;
  use Carp;

  use Test::WWW::Selenium;
  use Test::More;
  use IO::Socket;

  eval { require('t/lxtest.conf'); };
  if ($@) {
    diag("No test configuration found in t/lxtest.conf.\n
    Maybe you forget to copy t/lxtest.conf.default to t/lxtest.conf. Exit test...\n");
  exit 0;
  };

  sub server_is_running {
    return IO::Socket::INET->new(PeerAddr => $ENV{SRC_HOST} || $lxtest->{seleniumhost},
                                 PeerPort => $ENV{SRC_PORT} || $lxtest->{seleniumport},
                                );
  }
  if (server_is_running) {
    plan tests => 204; # Need to be cutomized
  }
  else {
    plan skip_all => "No selenium server found! "
                    ."Maybe you forgot to start it or "
                    ."the preferences in t/lxtest.conf doesen't fit to your system";
    exit 0;
  }

  diag('Pretests and initialisation');



  $lxtest->{test_id} = time; # create individual ids by unixtime
  $lxtest->{testuserlogin}   = $lxtest->{testlogin} . $lxtest->{test_id};
  $lxtest->{testuserpasswd}  = $lxtest->{test_id};
  $lxtest->{db}              = $lxtest->{db} . $lxtest->{test_id};

  ok(defined $lxtest->{rpw}, "Get root password");
  
  ok(defined $lxtest->{dbhost}, "found dbhost in config");
  ok(defined $lxtest->{dbport}, "found dbport in config");
  ok(defined $lxtest->{dbuser}, "found dbuser in config");
  ok(defined $lxtest->{dbpasswd}, "found dbpasswd in config");

  $lxtest->{lxadmin} = $lxtest->{lxbaseurl} . "admin.pl?path=$lxtest->{path}&rpw=$lxtest->{rpw}&nextsub=list_users&action=Weiter";





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

  opendir(SCRIPTS, 't/selenium/testscripts');
  my @testscripts = sort readdir(SCRIPTS);
  
  foreach my $script (@testscripts){
    my $file = "t/selenium/testscripts/" . $script;
    require_ok($file) if ( $script =~ /^\d\d\d.*\.t$/ );
  }
  exit 1;

  $sel=''; # Destroy selenium object

  exit 1;

