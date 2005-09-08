######################################################################
# SQL-Ledger Accounting
# Copyright (c) 2001
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
# menu for text based browsers (lynx)
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#   DS. 2001-08-07  access control
#   CBB 2002-02-09  Refactored HTML out to subroutines
#######################################################################

$menufile = "menu.ini";
use SL::Menu;


1;
# end of main



sub display {

  $menu = new Menu "$menufile";
  $menu = new Menu "custom_$menufile" if (-f "custom_$menufile");
  $menu = new Menu "$form->{login}_$menufile" if (-f "$form->{login}_$menufile");
  
  @menuorder = $menu->access_control(\%myconfig);

  $form->{title} = "SQL-Ledger $form->{version}";
  
  $form->header;

  $offset = int (21 - $#menuorder)/2;

  print "<pre>";
  print "\n" x $offset;
  print "</pre>";

  print qq|<center><table>|;

  map { print "<tr><td>".$menu->menuitem(\%myconfig, \%$form, $_).$locale->text($_).qq|</a></td></tr>|; } @menuorder;

  print qq'
</table>

</body>
</html>
';

  # display the company logo
#  $argv = "login=$form->{login}&password=$form->{password}&path=$form->{path}&action=company_logo&noheader=1";
#  exec "./login.pl", $argv;
  
}


sub section_menu {

  $menu = new Menu "$menufile", $form->{level};
  
  # build tiered menus
  @menuorder = $menu->access_control(\%myconfig, $form->{level});

  foreach $item (@menuorder) {
    $a = $item;
    $item =~ s/^$form->{level}--//;
    push @neworder, $a unless ($item =~ /--/);
  }
  @menuorder = @neworder;
 
  $level = $form->{level};
  $level =~ s/--/ /g;

  $form->{title} = $locale->text($level);
  
  $form->header;

  $offset = int (21 - $#menuorder)/2;
  print "<pre>";
  print "\n" x $offset;
  print "</pre>";
  
  print qq|<center><table>|;

  foreach $item (@menuorder) {
    $label = $item;
    $label =~ s/$form->{level}--//g;

    # remove target
    $menu->{$item}{target} = "";

    print "<tr><td>".$menu->menuitem(\%myconfig, \%$form, $item, $form->{level}).$locale->text($label)."</a></td></tr>";
  }
  
  print qq'</table>

</body>
</html>
';

}


sub acc_menu {
  
  &section_menu;
  
}


sub menubar {
  $menu = new Menu "$menufile", "";
  
  # build menubar
  @menuorder = $menu->access_control(\%myconfig, "");

  @neworder = ();
  map { push @neworder, $_ unless ($_ =~ /--/) } @menuorder;
  @menuorder = @neworder;

  print "<p>";
  $form->{script} = "menu.pl";

  foreach $item (@menuorder) {
    $label = $item;

    # remove target
    $menu->{$item}{target} = "";

    print $menu->menuitem(\%myconfig, \%$form, $item, "").$locale->text($label)." | ";
  }
  
}

