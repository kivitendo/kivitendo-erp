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

$menufile = "menu.ini";
use SL::Menu;
use URI;

1;

# end of main

sub display {
  $form->header(qq|<link rel="stylesheet" href="css/menuv3.css?id=" type="text/css">|);

  $form->{date}     = clock_line();
  $form->{menu}     = acc_menu();
  my $callback      = $form->unescape($form->{callback});
  $callback         = URI->new($callback)->rel($callback) if $callback;
  $callback         = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;
  $form->{callback} = $callback;

  print $form->parse_html_template("menu/menuv3");

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

  $mainlevel = $form->{level};
  $mainlevel =~ s/\Q$mainlevel\E--//g;
  my $menu = new Menu "$menufile";

  $| = 1;

  return print_menu($menu);
}

sub print_menu {
  my ($menu, $parent, $depth) = @_;
  my $html;

  die if ($depth * 1 > 5);

  my @menuorder;

  @menuorder = $menu->access_control(\%myconfig, $parent);

  $parent .= "--" if ($parent);

  foreach my $item (@menuorder) {
    substr($item, 0, length($parent)) = "";
    next if (($item eq "") || ($item =~ /--/));

    my $menu_item = $menu->{"${parent}${item}"};
    my $menu_title = $locale->text($item);
    my $menu_text = $menu_title;

    my $target = "main_window";
    $target = $menu_item->{"target"} if ($menu_item->{"target"});

    if ($menu_item->{"submenu"} || !defined($menu_item->{"module"}) ||
        ($menu_item->{"module"} eq "menu.pl")) {

      my $h = print_menu($menu, "${parent}${item}", $depth * 1 + 1)."\n";
      if (!$parent) {
        $html .= qq|<ul><li><h2>${menu_text}</h2><ul>${h}</ul></li></ul>\n|;
      } else {
        $html .= qq|<li><div class="x">${menu_text}</div><ul>${h}</ul></li>\n|;
      }
    } else {
      $html .= qq|<li>|;
      $html .= $menu->menuitem_v3(\%myconfig, $form, "${parent}$item",
                                  { "title" => $menu_title,
                                    "target" => $target });
      $html .= qq|${menu_text}</a></li>\n|;
    }
  }

  return $html;
}
