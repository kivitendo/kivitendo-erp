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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#=====================================================================
#
# routines to retrieve / manipulate win ini style files
# ORDER is used to keep the elements in the order they appear in .ini
#
#=====================================================================

package Inifile;

use IO::File;

use strict;

sub new {
  $main::lxdebug->enter_sub(2);

  my ($type, $file, %options) = @_;

  my $id = "";
  my $cur;

  my $self = { FILE => $file, ORDER => [] };

  open my $fh, "$file" or $::form->error("$file : $!");

  for (<$fh>) {
    chomp;

    if (!$options{verbatim}) {
      # strip comments
      # remove any trailing whitespace
      s/\s*#.*$//;
      s/^\s*//;
    } else {
      next if m/^\s*#/;
    }

    next unless $_;

    if (m/^\[(.*)\]$/) {
      $id = $1;
      $cur = $self->{$1} ||= { };

      push @{ $self->{ORDER} }, $1;
    } else {
      # add key=value to $id
      my ($key, $value) = split m/=/, $_, 2;

      $cur->{$key} = $value;
    }

  }
  close $fh;

  $main::lxdebug->leave_sub(2);

  return bless $self, $type;
}

sub write {
  $main::lxdebug->enter_sub();

  my ($self) = @_;

  my $file = $self->{FILE};
  my $fh   = IO::File->new($file, "w") || $::form->error("$file : $!");

  foreach my $section_name (sort keys %{ $self }) {
    next if $section_name =~ m/^[A-Z]+$/;

    my $section = $self->{$section_name};
    print $fh "[${section_name}]\n";
    map { print $fh "${_}=$section->{$_}\n" } sort keys %{ $section };
    print $fh "\n";
  }

  $fh->close();

  $main::lxdebug->leave_sub();
}

1;
