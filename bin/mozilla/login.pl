#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
######################################################################
# SQL-Ledger Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#######################################################################

use SL::DB::Default;
use SL::Form;
use SL::Git;
use DateTime;
use POSIX qw(floor);

require "bin/mozilla/common.pl";
require "bin/mozilla/todo.pl";

use strict;

our $form;
our $auth;

sub company_logo {
  $main::lxdebug->enter_sub();

  my %myconfig = %main::myconfig;
  $form->{todo_list}  =  create_todo_list('login_screen' => 1) if (!$::request->is_mobile) and (!$form->{no_todo_list}) and ($main::auth->check_right($::myconfig{login}, 'productivity'));

  $form->{stylesheet} =  $myconfig{stylesheet};
  $form->{title}      =  $::locale->text('kivitendo');
  $form->{interface}  = $::dispatcher->interface_type;
  $form->{client}     = $::auth->client;
  $form->{defaults}   = SL::DB::Default->get;

  my $git             = SL::Git->new;
  ($form->{git_head}) = $git->get_log(since => 'HEAD~1', until => 'HEAD') if $git->is_git_installation;

  my $td = DateTime->today;
  $form->{xmas}       = '_xmas'   if ($td->month == 12 && $td->day  < 27);
  $form->{xmas}       = '_mir'    if ($td->month ==  2 && $td->day == 24);
  $form->{xmas}       = '_easter' if _is_between($td->subtract_datetime(_easter_date_catholic($td->year))->delta_days(), -2, 1);
  $form->{xmas}       = '_easter' if _is_between($td->subtract_datetime(_easter_date_orthodox($td->year))->delta_days(), -2, 1);

  # create the logo screen
  $form->header() unless $form->{noheader};

  print $form->parse_html_template('login/company_logo', { version => $::form->read_version });

  $main::lxdebug->leave_sub();
}

sub _is_between {
  my ($x, $a, $b) = @_;

  $x >= $a && $x <= $b;
}

sub _easter_date_catholic {
  # Western Easter Date Algorithm New Scientist 1961
  my ($Y) = @_;
  my ($a, $b, $c, $d, $e, $g, $h, $i, $k, $l, $m, $n, $p);

  $a = $Y % 19;
  $b = floor($Y/100);
  $c = $Y % 100;
  $d = floor($b/4);
  $e = $b % 4;
  $g = floor((8*$b+13)/25);
  $h = (19*$a + $b - $d - $g + 15) % 30;
  $i = floor($c/4);
  $k = $c % 4;
  $l = (32 + 2*$e + 2*$i - $h - $k) % 7;
  $m = floor(($a+11*$h+19*$l)/433);
  $n = floor(($h+$l+-7*$m+90)/25);
  $p = ($h + $l - 7*$m + 33*$n + 19) % 32;

  DateTime->new(year => $Y, month => $n, day => $p);
}

sub _easter_date_orthodox {
  # Eastern Easter Date Meeus's Julian algorithm
  # Astronomical Algorithms (1991, p. 69)
  my ($Y) = @_;
  my ($a, $b, $c, $d, $e, $doy, $month, $day);

  $a = $Y % 4;
  $b = $Y % 7;
  $c = $Y % 19;
  $d = (19*$c + 15) % 30;
  $e = (2*$a+4*$b-$d+34) % 7;
  $doy = $d+$e+114;
  $month = floor($doy/31);  # Julian date
  $day   = ($doy % 31) + 1; # Julian date

  my @a = (31, 30, 31);
  $day += 13;
  if ($day > $a[$month-3]) {
    $day -= $a[$month-3];
    $month += 1;
  }

  DateTime->new(year => $Y, month => $month, day => $day);
}

1;

__END__
