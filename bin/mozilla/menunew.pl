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
#######################################################################

use English qw(-no_match_vars);
use List::Util qw(max);
use URI;

use SL::Menu;

1;

# end of main

sub display {
  $form->header();

#   $form->{force_ul_width} = $ENV{HTTP_USER_AGENT} =~ m/MSIE\s+6\./;
#   $form->{force_ul_width} = $ENV{HTTP_USER_AGENT} !~ m/Opera/;
  $form->{force_ul_width} = 1;
  $form->{date}           = clock_line();
  $form->{menu_items}     = acc_menu();
  my $callback            = $form->unescape($form->{callback});
  $callback               = URI->new($callback)->rel($callback) if $callback;
  $callback               = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;
  $form->{callback}       = $callback;

  print $form->parse_html_template("menu/menunew");
}

sub clock_line {
  my ($Sekunden, $Minuten,   $Stunden,   $Monatstag, $Monat,
      $Jahr,     $Wochentag, $Jahrestag, $Sommerzeit)
    = localtime(time);
  $Monat     += 1;
  $Jahrestag += 1;
  $Monat     = $Monat < 10     ? $Monat     = "0" . $Monat     : $Monat;
  $Monatstag = $Monatstag < 10 ? $Monatstag = "0" . $Monatstag : $Monatstag;
  $Jahr += 1900;
  my @Wochentage = ("Sonntag",    "Montag",  "Dienstag", "Mittwoch",
                    "Donnerstag", "Freitag", "Samstag");
  my @Monatsnamen = ("",       "Januar",    "Februar", "M&auml;rz",
                     "April",  "Mai",       "Juni",    "Juli",
                     "August", "September", "Oktober", "November",
                     "Dezember");
  return
      $Wochentage[$Wochentag] . ", der "
    . $Monatstag . "."
    . $Monat . "."
    . $Jahr . " - ";
}

sub acc_menu {
  $locale = Locale->new($myconfig{countrycode}, "menu");

  my $mainlevel =  $form->{level};
  $mainlevel    =~ s/\Q$mainlevel\E--//g;
  my $menu      = Menu->new('menu.ini');

  $AUTOFLUSH    =  1;

  my $all_items = [];
  create_menu($menu, $all_items);

  my $item = { 'subitems' => $all_items };
  calculate_width($item);

  return $all_items;
}

sub calculate_width {
  my $item           = shift;

  $item->{max_width} = max map { length $_->{title} } @{ $item->{subitems} };

  foreach my $subitem (@{ $item->{subitems} }) {
    calculate_width($subitem) if ($subitem->{subitems});
  }
}

sub create_menu {
  my ($menu, $all_items, $parent, $depth) = @_;
  my $html;

  die if ($depth * 1 > 5);

  my @menuorder  = $menu->access_control(\%myconfig, $parent);
  $parent       .= "--" if ($parent);

  foreach my $name (@menuorder) {
    substr($name, 0, length($parent), "");
    next if (($name eq "") || ($name =~ /--/));

    my $menu_item = $menu->{"${parent}${name}"};
    my $item      = { 'title' => $locale->text($name) };
    push @{ $all_items }, $item;

    if ($menu_item->{submenu} || !defined($menu_item->{module}) || ($menu_item->{module} eq "menu.pl")) {
      $item->{subitems} = [];
      create_menu($menu, $item->{subitems}, "${parent}${name}", $depth * 1 + 1);

    } else {
      $menu->menuitem_new("${parent}${name}", $item);
    }
  }
}
