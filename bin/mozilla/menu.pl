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
#  Contributors: Christopher Browne
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
#######################################################################
#
# thre frame layout with refractured menu
#
# CHANGE LOG:
#   DS. 2002-03-25  Created
#  2004-12-14 - New Optik - Marco Welter <mawe@linux-studio.de>
#######################################################################

my $menufile = "menu.ini";
use SL::Menu;
use Data::Dumper;
use URI;

use strict;

my $framesize = ($ENV{HTTP_USER_AGENT} =~ /links/i) ? "240" : "190";
my $mainlevel;

1;

# end of main

sub display {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  my $callback   = $form->unescape($form->{callback});
  $callback      = URI->new($callback)->rel($callback) if $callback;
  $callback      = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;

  $form->header;

  print qq|
<frameset rows="28px,*" cols="*" framespacing="0" frameborder="0">
  <frame  src="kopf.pl" name="kopf"  scrolling="NO">
  <frameset cols="$framesize,*" framespacing="0" frameborder="0" border="0" >
    <frame src="$form->{script}?action=acc_menu" name="acc_menu"  scrolling="auto" noresize marginwidth="0">
    <frame src="$callback" name="main_window" scrolling="auto">
  </frameset>
  <noframes>
  You need a browser that can read frames to see this page.
  </noframes>
</frameset>
</HTML>
|;

  $main::lxdebug->leave_sub();
}

sub acc_menu {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $mainlevel = $form->{level};
  $mainlevel =~ s/\Q$mainlevel\E--//g;
  my $menu = new Menu "$menufile";

  $form->{title} = $locale->text('Accounting Menu');

  $form->header;

  print qq|
<body class="menu">

|;
  print qq|<div align="left">\n<table width="|
    . $framesize
    . qq|" border=0>\n|;

  &section_menu($menu);

  print qq|</table></div>|;
  print qq|
</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub section_menu {
  $main::lxdebug->enter_sub();
  my ($menu, $level) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $zeige;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);
  while (@menuorder) {
    my $item  = shift @menuorder;
    my $label = $item;
    my $ml    = $item;
    $label =~ s/\Q$level\E--//g;
    $ml    =~ s/--.*//;
    if ($ml eq $mainlevel) { $zeige = 1; }
    else { $zeige = 0; }
    my $spacer = "&nbsp;" x (($item =~ s/--/--/g) * 1);
    $label =~ s/.*--//g;
    my $label_icon = $label . ".gif";
    my $mlab       = $label;
    $label      = $locale->text($label);

    # multi line hack, sschoeling jul06
    # if a label is too long, try to split it at whitespaces, then join it to chunks of less
    # than 20 chars and store it in an array.
    # use this array later instead of the &nbsp;-ed label
    my @chunks = ();
    my ($i,$l) = (-1, 20);
    map {
      if (($l += length $_) < 20) {
        $chunks[$i] .= " $_";
      } else {
        $l = length $_;
        $chunks[++$i] = $_;

      }
    } split / /, $label;
    map { s/ /&nbsp;/ } @chunks;
    # end multi line

    $label =~ s/ /&nbsp;/g;
    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};

    if ($menu->{$item}{submenu}) {
      $menu->{$item}{$item} = !$form->{$item};
      if ($form->{level} && $item =~ /^\Q$form->{level}\E/) {

        # expand menu
        if ($zeige) {
          print
            qq|<tr><td valign=bottom><b>$spacer<img src="image/unterpunkt.png">$label</b></td></tr>\n|;
        }

        # remove same level items
        map { shift @menuorder } grep /^$item/, @menuorder;
        &section_menu($menu, $item);
      } else {
        if ($zeige) {
          print qq|<tr><td>|
            . $menu->menuitem(\%myconfig, \%$form, $item, $level)
            . qq|$label&nbsp;...</a></td></tr>\n|;
        }

        # remove same level items
        map { shift @menuorder } grep /^$item/, @menuorder;
      }
    } else {
      if ($menu->{$item}{module}) {
        if ($form->{$item} && $form->{level} eq $item) {
          $menu->{$item}{$item} = !$form->{$item};
          if ($zeige) {
            print
              qq|<tr><td valign=bottom>$spacer<img src="image/unterpunkt.png">|
              . $menu->menuitem(\%myconfig, \%$form, $item, $level)
              . qq|$label</a></td></tr>\n|;
          }

          # remove same level items
          map { shift @menuorder } grep /^$item/, @menuorder;
          &section_menu($menu, $item);
        } else {
          if ($zeige) {
            if (scalar @chunks <= 1) {
              print
                qq|<tr><td class="hover" height="13" >$spacer<img src="image/unterpunkt.png"  style="vertical-align:text-top">|
                . $menu->menuitem(\%myconfig, \%$form, $item, $level)
                . qq|$label</a></td></tr>\n|;
            } else {
              my $tmpitem = $menu->menuitem(\%myconfig, \%$form, $item, $level);
              print
                qq|<tr><td class="hover" height="13" >$spacer<img src="image/unterpunkt.png"  style="vertical-align:text-top">|
                . $tmpitem
                . qq|$chunks[0]</a></td></tr>\n|;
              map {
                print
                  qq|<tr style="vertical-align:top""><td class="hover">$spacer<img src="image/unterpunkt.png" style="visibility:hidden; width:23; height=2;">|
                  . $tmpitem
                  . qq|$chunks[$_]</a></td></tr>\n|;
              } 1..$#chunks;
            }
          }
        }
      } else {
        my $ml_ = $form->escape($ml);
        print
          qq|<tr><td class="bg" height="22" align="left" valign="middle" ><img src="image/$item.png" style="vertical-align:middle">&nbsp;<a href="menu.pl?action=acc_menu&level=$ml_" class="nohover">$label</a>&nbsp;&nbsp;&nbsp;&nbsp;</td></tr>\n|;
        &section_menu($menu, $item);

        #print qq|<br>\n|;
      }
    }
  }
  $main::lxdebug->leave_sub();
}
