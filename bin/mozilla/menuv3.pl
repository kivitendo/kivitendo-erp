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

1;

# end of main

sub display {
  $form->header(qq|<link rel="stylesheet" href="css/menuv3.css?id=| .
                int(rand(100000)) . qq|" type="text/css">|);

  print(qq|<body style="padding:0px; margin:0px;">\n|);

  clock_line();

  print qq|

<div id="menu">

| . acc_menu() . qq|

</div>

<div style="clear: both;"></div>

<iframe id="win1" src="login.pl?login=$form->{login}&password=$form->{password}&action=company_logo&path=$form->{path}" width="100%" height="93%" name="main_window" style="position: absolute; border: 0px; z-index: 99; ">
<p>Ihr Browser kann leider keine eingebetteten Frames anzeigen.
</p>
</iframe>
</body>
</html>

|;

}

sub clock_line {

  $fensterlink="menuv3.pl?login=$form->{login}&password=$form->{password}&path=$form->{path}&action=display";
  $fenster = "["."<a href=\"$fensterlink\" target=\"_blank\">neues Fenster</a>]";

  $login = "[Nutzer "
    . $form->{login}
    . " - <a href=\"login.pl?path="
    . $form->{"path"}
    . "&password="
    . $form->{"password"}
    . "&action=logout\" target=\"_top\">"
    . $locale->text('Logout')
    . "</a>] ";
  my ($Sekunden, $Minuten,   $Stunden,   $Monatstag, $Monat,
      $Jahr,     $Wochentag, $Jahrestag, $Sommerzeit)
    = localtime(time);
  my $CTIME_String = localtime(time);
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
  $datum =
      $Wochentage[$Wochentag] . ", der "
    . $Monatstag . "."
    . $Monat . "."
    . $Jahr . " - ";

  #$zeit="<div id='Uhr'>".$Stunden.":".$Minuten.":".$Sekunden."</div>";
  $zeit = "<div id='Uhr'>" . $Stunden . ":" . $Minuten . "</div>";
  print qq|
<script type="text/javascript">
<!--
var h=$Stunden; var m=$Minuten; var s=$Sekunden;
function clockon() {
  s=++s%60;if(s==0){m=++m%60;if(m==0)h=++h%24;}
  document.getElementById('clock_id').innerHTML = (h<10?'0'+h:h)+":"+(m<10?'0'+m:m)+":"+(s<10?'0'+s:s);
  var timer=setTimeout("clockon()", 1000);
}
//window.onload=clockon
//-->
</script>
<table border="0" width="100%" background="image/bg_titel.gif" cellpadding="0" cellspacing="0">
  <tr>
    <td style="color:white; font-family:verdana,arial,sans-serif; font-size: 12px;"> &nbsp; $fenster &nbsp; [<a href="JavaScript:top.main_window.print()">drucken</a>]</td>
    <td align="right" style="vertical-align:middle; color:white; font-family:verdana,arial,sans-serif; font-size: 12px;" nowrap>
      $login $datum <span id='clock_id' style='position:relative'></span>&nbsp;
    </td>
  </tr>
</table>
|;
}

sub acc_menu {
  $locale = Locale->new($language, "menu");

  $mainlevel = $form->{level};
  $mainlevel =~ s/$mainlevel--//g;
  my $menu = new Menu "$menufile";
  $menu = new Menu "custom_$menufile" if (-f "custom_$menufile");
  $menu = new Menu "$form->{login}_$menufile"
    if (-f "$form->{login}_$menufile");

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
