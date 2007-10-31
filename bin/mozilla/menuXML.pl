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
# three frame layout with refractured menu
#
# CHANGE LOG:
#   DS. 2002-03-25  Created
#  2004-12-14 - New Optik - Marco Welter <mawe@linux-studio.de>
#  2007-10-14 - XMLified  - Holger Will  <holger@treebuilder.de>
#######################################################################

$menufile = "menu.ini";
use SL::Menu;

use CGI::Carp qw(fatalsToBrowser);
use Encode;
1;

# end of main

sub display {
  print "Content-type: text/xml; charset=iso-8859-1\n\n";
  print qq|<?xml version="1.0" encoding="iso-8859-1"?>\n|;
  print qq|<?xml-stylesheet href="xslt/xulmenu.xsl" type="text/xsl"?>\n|;
  print qq|<!DOCTYPE doc [
<!ENTITY szlig "ß">
]>|;
  print qq|<doc>|;
  print qq|<login>|;
  print $form->{login};
  print qq|</login>|;
  print qq|<password>|;
  print $form->{password};
  print qq|</password>|;
  print qq|<name>|;
  print %myconfig->{name};
  print qq|</name>|;
  print qq|<db>|;
  print %myconfig->{dbname};
  print qq|</db>|;
  print qq|<favorites>|;
  my $fav=%myconfig->{favorites};
  my @favorites = split(/;/, $fav);
  foreach (@favorites) {
    print qq|<link name="$_"/>|;
  }
  print qq|</favorites>|;
  print qq|<menu>|;
my $isoencodedmenu=&acc_menu($menu);
 print encode("iso-8859-1",$isoencodedmenu );

  print qq|</menu>|;
  print qq|</doc>|;
  
}


sub acc_menu {
  $locale = Locale->new($language, "menu");

  $mainlevel = $form->{level};
  $mainlevel =~ s/$mainlevel--//g;
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
    my $menu_item_id = $item;
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
        $html .= qq|<item name='${menu_text}' id='${menu_item_id}'>${h}</item>\n|;
      } else {
        $html .= qq|<item name='${menu_text}' id='${menu_item_id}'>${h}</item>\n|;
      }
    } else {
      $html .= qq|<item |;
      $html .= $menu->menuitem_XML(\%myconfig, $form, "${parent}$item",
                                  { "title" => $menu_title,
                                    "target" => $target });
      $html .= qq| name="${menu_text}" id='${menu_item_id}'/>\n|;
    }
  }

  return $html;
}
