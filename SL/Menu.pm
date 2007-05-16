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
# routines for menu items
#
#=====================================================================

package Menu;

use SL::Inifile;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $menufile) = @_;

  my $self    = {};
  my $inifile = Inifile->new($menufile);

  map { $self->{$_} = $inifile->{$_} } keys %{ $inifile };

  $main::lxdebug->leave_sub();

  bless $self, $type;
}

sub menuitem {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $item) = @_;

  my $module = $form->{script};
  my $action = "section_menu";
  my $target = "";

  if ($self->{$item}{module}) {
    $module = $self->{$item}{module};
  }
  if ($self->{$item}{action}) {
    $action = $self->{$item}{action};
  }
  if ($self->{$item}{target}) {
    $target = $self->{$item}{target};
  }

  my $level = $form->escape($item);

  my $str =
    qq|<a style="vertical-align:top" href=$module?action=$action&level=$level&login=$form->{login}&password=$form->{password}|;

  my @vars = qw(module action target href);

  if ($self->{$item}{href}) {
    $str  = qq|<a href=$self->{$item}{href}|;
    @vars = qw(module target href);
  }

  map { delete $self->{$item}{$_} } @vars;

  # add other params
  foreach my $key (keys %{ $self->{$item} }) {
    $str .= "&" . $form->escape($key, 1) . "=";
    ($value, $conf) = split(/=/, $self->{$item}{$key}, 2);
    $value = $myconfig->{$value} . "/$conf" if ($conf);
    $str .= $form->escape($value, 1);
  }

  if ($target) {
    $str .= qq| target=$target|;
  }

  $str .= ">";

  $main::lxdebug->leave_sub();

  return $str;
}

sub menuitem_v3 {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $item, $other) = @_;

  my $module = $form->{script};
  my $action = "section_menu";
  my $target = "";

  if ($self->{$item}{module}) {
    $module = $self->{$item}{module};
  }
  if ($self->{$item}{action}) {
    $action = $self->{$item}{action};
  }
  if ($self->{$item}{target}) {
    $target = $self->{$item}{target};
  }

  my $level = $form->escape($item);

  my $str = qq|<a href="$module?action=| . $form->escape($action) .
    qq|&level=| . $form->escape($level);
  map({ $str .= "&${_}=" . $form->escape($form->{$_}); } qw(login password));

  my @vars = qw(module action target href);

  if ($self->{$item}{href}) {
    $str  = qq|<a href=$self->{$item}{href}|;
    @vars = qw(module target href);
  }

  map { delete $self->{$item}{$_} } @vars;

  # add other params
  foreach my $key (keys %{ $self->{$item} }) {
    $str .= "&" . $form->escape($key, 1) . "=";
    ($value, $conf) = split(/=/, $self->{$item}{$key}, 2);
    $value = $myconfig->{$value} . "/$conf" if ($conf);
    $str .= $form->escape($value, 1);
  }

  $str .= '"';

  if ($target) {
    $str .= qq| target="| . $form->quote($target) . qq|"|;
  }

  if ($other) {
    foreach my $key (keys(%{$other})) {
      $str .= qq| ${key}="| . $form->quote($other->{$key}) . qq|"|;
    }
  }

  $str .= ">";

  $main::lxdebug->leave_sub();

  return $str;
}

sub menuitemNew {
  my ($self, $myconfig, $form, $item) = @_;

  my $module = $form->{script};
  my $action = "section_menu";

  #if ($self->{$item}{module}) {
  $module = $self->{$item}{module};

  #}
  if ($self->{$item}{action}) {
    $action = $self->{$item}{action};
  }

  my $level = $form->escape($item);
  my $str   =
    qq|$module?action=$action&level=$level&login=$form->{login}&password=$form->{password}|;
  my @vars = qw(module action target href);

  if ($self->{$item}{href}) {
    $str  = qq|$self->{$item}{href}|;
    @vars = qw(module target href);
  }

  map { delete $self->{$item}{$_} } @vars;

  # add other params
  foreach my $key (keys %{ $self->{$item} }) {
    $str .= "&" . $form->escape($key, 1) . "=";
    ($value, $conf) = split(/=/, $self->{$item}{$key}, 2);
    $value = $myconfig->{$value} . "/$conf" if ($conf);
    $str .= $form->escape($value, 1);
  }

  $str .= " ";

}

sub access_control {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig, $menulevel) = @_;

  my @menu = ();

  if ($menulevel eq "") {
    @menu = grep { !/--/ } @{ $self->{ORDER} };
  } else {
    @menu = grep { /^${menulevel}--/ } @{ $self->{ORDER} };
  }

  my @a    = split(/;/, $myconfig->{acs});
  my $excl = ();

  # remove --AR, --AP from array
  grep { ($a, $b) = split(/--/); s/--$a$//; } @a;

  map { $excl{$_} = 1 } @a;

  @a = ();
  map { push @a, $_ unless $excl{$_} } (@menu);

  $main::lxdebug->leave_sub(2);

  return @a;
}

sub generate_acl {
  my ($self, $menulevel, $hash) = @_;

  my @items = $self->access_control(\%main::myconfig, $menulevel);

  $menulevel =~ s/[^A-Za-z_\/\.\+\-]/_/g;
  $hash->{"access_" . lc($menulevel)} = 1 if ($menulevel);

  foreach my $item (@items) {
    $self->generate_acl($item, $hash); #unless ($menulevel);
  }
}

1;

