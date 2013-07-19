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

use strict;

sub new {
  $main::lxdebug->enter_sub();

  my ($type, @menufiles) = @_;
  my $self               = bless {}, $type;

  my @order;

  foreach my $menufile (grep { -f } @menufiles) {
    my $inifile = Inifile->new($menufile);

    push @order, @{ delete($inifile->{ORDER}) || [] };
    $self->{$_} = $inifile->{$_} for keys %{ $inifile };
  }

  $self->{ORDER} = \@order;

  $self->set_access();

  $main::lxdebug->leave_sub();

  return $self;
}

sub menuitem_new {
  $main::lxdebug->enter_sub(LXDebug::DEBUG2());

  my ($self, $name, $item) = @_;

  my $form        =  $main::form;
  my $myconfig    = \%main::myconfig;

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

  $main::lxdebug->leave_sub(LXDebug::DEBUG2());
}

sub access_control {
  $main::lxdebug->enter_sub(2);

  my ($self, $myconfig, $menulevel) = @_;

  my @menu = ();

  if (!$menulevel) {
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

  my $form        =  $main::form;
  my $auth        =  $main::auth;
  my $myconfig    = \%main::myconfig;

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
        $form->error("Error in menu.ini for entry ${key}: missing '('");
      }
      $cur_ary = $stack[-1];

    } elsif (($token eq "|") || ($token eq "&")) {
      push @{$cur_ary}, $token;

    } else {
      push @{$cur_ary}, $auth->check_right($form->{login}, $token, 1);
    }
  }

  if ($access) {
    $form->error("Error in menu.ini for entry ${key}: unrecognized token at the start of '$access'\n");
  }

  if (1 < scalar @stack) {
    $main::form->error("Error in menu.ini for entry ${key}: Missing ')'\n");
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

  { no strict 'refs';
  # ToDO: fix this. nuke and pave algorithm without type checking screams for problems.
  map { delete @{$self->{$_}}{qw(GRANTED IS_MENU NUM_VISIBLE_CHILDREN VISIBLE ACCESS)} if ($_ ne 'ORDER') } keys %{ $self };
  }
}

sub dump_visible {
  my $self = shift;
  foreach my $key (@{ $self->{ORDER} }) {
    my $entry = $self->{$key};
    $main::lxdebug->message(0, "$entry->{GRANTED} $entry->{VISIBLE} $entry->{NUM_VISIBLE_CHILDREN} $key");
  }
}

1;

