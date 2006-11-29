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
# Main Test Module: 
# For collecting all the tests in nice Test::Harness environment.
# Study the README for Selenium Installation and testing process 
# and enjoy starting
# #perl t/lx-office.t
# against the unstable release
#======================================================================

  use strict; 
  use warnings FATAL => 'all';
  use diagnostics;
  use Carp;
  use Test::Harness;

  
## Backendtests:
#  &runtests(
#  );  


## Frontendtests:
  &runtests(
    't/selenium/AllTests.t',
  );

exit 1;