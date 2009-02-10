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

use SL::Auth;
use SL::Inifile;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, $menufile) = @_;

  my $self    = {};
  my $inifile = Inifile->new($menufile);

  map { $self->{$_} = $inifile->{$_} } keys %{ $inifile };

  bless $self, $type;

  $self->set_access();

  $main::lxdebug->leave_sub();

  return $self;
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

  my $str = qq|<a style="vertical-align:top" href=$module?action=$action&level=$level|;

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

sub menuitem_js {
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

sub menuitem_new {
  $main::lxdebug->enter_sub();

  my ($self, $name, $item) = @_;

  my $form        = $main::form;

  my $module      = $self->{$name}->{module} || $form->{script};
  my $action      = $self->{$name}->{action};

  $item->{target} = $self->{$name}->{target} || "main_window";
  $item->{href}   = $self->{$name}->{href}   || "${module}?action=" . $form->escape($action);

  my @vars = qw(module target href);
  push @vars, 'action' unless ($self->{$name}->{href});

  map { delete $self->{$name}{$_} } @vars;

  # add other params
  foreach my $key (keys %{ $self->{$name} }) {
    my ($value, $conf)  = split(m/=/, $self->{$name}->{$key}, 2);
    $value              = $myconfig->{$value} . "/$conf" if ($conf);
    $item->{href}      .= "&" . $form->escape($key) . "=" . $form->escape($value);
  }

  $main::lxdebug->leave_sub();
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

  my $str = qq|<a href="$module?action=| . $form->escape($action) . qq|&level=| . $form->escape($level);

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

sub menuitem_XML {
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

  my $str = qq| link="$module?action=| . $form->escape($action) .
    qq|&amp;level=| . $form->escape($level);

  my @vars = qw(module action target href);

  if ($self->{$item}{href}) {
    $str  = qq| link=$self->{$item}{href}|;
    @vars = qw(module target href);
  }

  map { delete $self->{$item}{$_} } @vars;

  # add other params
  foreach my $key (keys %{ $self->{$item} }) {
    $str .= "&amp;" . $form->escape($key, 1) . "=";
    ($value, $conf) = split(/=/, $self->{$item}{$key}, 2);
    $value = $myconfig->{$value} . "/$conf" if ($conf);
    $str .= $form->escape($value, 1);
  }

  $str .= '"';



  if ($other) {
    foreach my $key (keys(%{$other})) {
      $str .= qq| ${key}="| . $form->quote($other->{$key}) . qq|"|;
    }
  }


  $main::lxdebug->leave_sub();

  return $str;
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

  $main::lxdebug->leave_sub(2);

  return @menu;
}

sub parse_access_string {
  my $self   = shift;
  my $key    = shift;
  my $access = shift;

  my @stack;
  my $cur_ary = [];

  push @stack, $cur_ary;

  while ($access =~ m/^([a-z_]+|\||\&|\(|\)|\s+)/) {
    my $token = $1;
    substr($access, 0, length($1)) = "";

    next if ($token =~ /\s/);

    if ($token eq "(") {
      my $new_cur_ary = [];
      push @stack, $new_cur_ary;
      push @{$cur_ary}, $new_cur_ary;
      $cur_ary = $new_cur_ary;

    } elsif ($token eq ")") {
      pop @stack;
      if (!@stack) {
        $main::form->error("Error in menu.ini for entry ${key}: missing '('");
      }
      $cur_ary = $stack[-1];

    } elsif (($token eq "|") || ($token eq "&")) {
      push @{$cur_ary}, $token;

    } else {
      push @{$cur_ary}, $main::auth->check_right($main::form->{login}, $token, 1);
    }
  }

  if ($access) {
    $main::form->error("Error in menu.ini for entry ${name}: unrecognized token at the start of '$access'\n");
  }

  if (1 < scalar @stack) {
    $main::form->error("Error in menu.ini for entry ${name}: Missing ')'\n");
  }

  return SL::Auth::evaluate_rights_ary($stack[0]);
}

sub set_access {
  my $self = shift;

  my $key;

  foreach $key (@{ $self->{ORDER} }) {
    my $entry = $self->{$key};

    $entry->{GRANTED}              = $entry->{ACCESS} ? $self->parse_access_string($key, $entry->{ACCESS}) : 1;
    $entry->{IS_MENU}              = $entry->{submenu} || ($key !~ m/--/);
    $entry->{NUM_VISIBLE_CHILDREN} = 0;

    if ($key =~ m/--/) {
      my $parent = $key;
      substr($parent, rindex($parent, '--')) = '';
      $entry->{GRANTED} &&= $self->{$parent}->{GRANTED};
    }

    $entry->{VISIBLE} = $entry->{GRANTED};
  }

  foreach $key (reverse @{ $self->{ORDER} }) {
    my $entry = $self->{$key};

    if ($entry->{IS_MENU}) {
      $entry->{VISIBLE} &&= $entry->{NUM_VISIBLE_CHILDREN} > 0;
    }

    next if (($key !~ m/--/) || !$entry->{VISIBLE});

    my $parent = $key;
    substr($parent, rindex($parent, '--')) = '';
    $self->{$parent}->{NUM_VISIBLE_CHILDREN}++;
  }

#   $self->dump_visible();

  $self->{ORDER} = [ grep { $self->{$_}->{VISIBLE} } @{ $self->{ORDER} } ];

  map { delete @{$self->{$_}}{qw(GRANTED IS_MENU NUM_VISIBLE_CHILDREN VISIBLE ACCESS)} if ($_ ne 'ORDER') } keys %{ $self };
}

sub dump_visible {
  my $self = shift;
  foreach my $key (@{ $self->{ORDER} }) {
    my $entry = $self->{$key};
    $main::lxdebug->message(0, "$entry->{GRANTED} $entry->{VISIBLE} $entry->{NUM_VISIBLE_CHILDREN} $key");
  }
}

1;

