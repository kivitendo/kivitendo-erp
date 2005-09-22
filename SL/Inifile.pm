#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
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
#=====================================================================
#
# routines to retrieve / manipulate win ini style files
# ORDER is used to keep the elements in the order they appear in .ini
#
#=====================================================================

package Inifile;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $file, $level) = @_;

  my $id = "";
  my $skip;

  $type = ref($self) || $self;

  open FH, "$file" or Form->error("$file : $!");

  while (<FH>) {
    next if /^(#|;|\s)/;
    last if /^\./;

    chop;

    # strip comments
    s/\s*(#|;).*//g;

    # remove any trailing whitespace
    s/^\s*(.*?)\s*$/$1/;

    if (/^\[/) {
      s/(\[|\])//g;

      $id = $_;

      # if there is a level skip
      if ($skip = ($id !~ /^$level/)) {
        next;
      }

      push @{ $self->{ORDER} }, $_;

      next;

    }

    if (!$skip) {

      # add key=value to $id
      my ($key, $value) = split /=/, $_, 2;

      $self->{$id}{$key} = $value;
    }

  }
  close FH;

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

1;

