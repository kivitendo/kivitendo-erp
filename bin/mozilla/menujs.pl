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
#  2004-12-14 - Holger Lindemann
#######################################################################

$menufile = "menu.ini";
use SL::Menu;
use CGI::Carp qw(fatalsToBrowser);

1;

# end of main

sub display {

  $form->header;

  &clock_line;

  &acc_menu;

  print qq|
<iframe id="win1" src="login.pl?login=$form->{login}&password=$form->{password}&action=company_logo" width="100%" height="93%" name="main_window" style="position: absolute; border:0px;">
<p>Ihr Browser kann leider keine eingebetteten Frames anzeigen.
</p>
</iframe>
</body>
</html>

|;

}

sub clock_line {

  $fensterlink="menujs.pl?login=$form->{login}&password=$form->{password}&action=display";
  $fenster = "["."<a href=\"$fensterlink\" target=\"_blank\">neues Fenster</a>]";

  $login = "[Nutzer "
    . $form->{login}
    . " - <a href=\"login.pl?password="
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
function clockon() {
  var now = new Date();
  var h = now.getHours();
  var m = now.getMinutes();
  document.getElementById('clock_id').innerHTML = (h<10?'0'+h:h)+":"+(m<10?'0'+m:m);
  var timer=setTimeout("clockon()", 10000);
}
window.onload=clockon
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
  $mainlevel = $form->{level};
  $mainlevel =~ s/$mainlevel--//g;
  my $menu = new Menu "$menufile";

  $| = 1;

  print qq|
<style>
<!--

.itemBorder {
  border: 1px solid black
}

.itemText {
  text-decoration: none;
  color: #000000;
  font: 12px Arial, Helvetica
}

.rootItemText {
  text-decoration: none;
  color: #ffffff;
  font: 12px Arial, Helvetica
}

.menu {
  color:#ffffff;
  background:url(image/bg_css_menu.png) repeat bottom;
  border:1px solid;
  border-color:#ccc #888 #555 #bbb;
}

-->
</style>

<script type="text/javascript">
<!--
var isDOM = (document.getElementById ? true : false); 
var isIE4 = ((document.all && !isDOM) ? true : false);
var isNS4 = (document.layers ? true : false);
//var KO = (navigator.appName=="Konqueror" \|\| navigator.appName=="Opera") ;
var KO = ((navigator.userAgent.indexOf('Opera',0) != -1) \|\| (navigator.userAgent.indexOf('Konqueror',0) != -1));
function getRef(id) {
	if (isDOM) return document.getElementById(id);
	if (isIE4) return document.all[id];
	if (isNS4) return document.layers[id];
}
function getSty(id) {
	return (isNS4 ? getRef(id) : getRef(id).style);
} 
var popTimer = 0;
var litNow = new Array();
function popOver(menuNum, itemNum) {
	if (KO) document.getElementById("win1").style.visibility = "hidden";
	clearTimeout(popTimer);
	hideAllBut(menuNum);
	litNow = getTree(menuNum, itemNum);
	changeCol(litNow, true);
	targetNum = menu[menuNum][itemNum].target;
	if (targetNum > 0) {
		thisX = parseInt(menu[menuNum][0].ref.left) + parseInt(menu[menuNum][itemNum].ref.left);
		thisY = parseInt(menu[menuNum][0].ref.top) + parseInt(menu[menuNum][itemNum].ref.top);
		with (menu[targetNum][0].ref) {
			left = parseInt(thisX + menu[targetNum][0].x);
			top = parseInt(thisY + menu[targetNum][0].y);
			visibility = 'visible';
		}
	}
}
function popOut(menuNum, itemNum) {
	if ((menuNum == 0) && !menu[menuNum][itemNum].target)
		hideAllBut(0)
		if (KO) document.getElementById("win1").style.visibility = "visible";
	else
		popTimer = setTimeout('hideAllBut(0)', 500);
}
function getTree(menuNum, itemNum) {
	itemArray = new Array(menu.length);
	while(1) {
		itemArray[menuNum] = itemNum;
		if (menuNum == 0) return itemArray;
		itemNum = menu[menuNum][0].parentItem;
		menuNum = menu[menuNum][0].parentMenu;
	}
}
function changeCol(changeArray, isOver) {
	for (menuCount = 0; menuCount < changeArray.length; menuCount++) {
		if (changeArray[menuCount]) {
			newCol = isOver ? menu[menuCount][0].overCol : menu[menuCount][0].backCol;
			with (menu[menuCount][changeArray[menuCount]].ref) {
				if (isNS4) bgColor = newCol;
				else backgroundColor = newCol;
			}
		}
	}
}
function hideAllBut(menuNum) {
	var keepMenus = getTree(menuNum, 1);
	for (count = 0; count < menu.length; count++)
		if (!keepMenus[count])
			menu[count][0].ref.visibility = 'hidden';
	changeCol(litNow, false);
}

function Menu(isVert, popInd, x, y, width, overCol, backCol, borderClass, textClass) {
	this.isVert = isVert;
	this.popInd = popInd
	this.x = x;
	this.y = y;
	this.width = width;
	this.overCol = overCol;
	this.backCol = backCol;
	this.borderClass = borderClass;
	this.textClass = textClass;
	this.parentMenu = null;
	this.parentItem = null;
	this.ref = null;
}
function Item(text, href, frame, length, spacing, target) {
	this.text = text;
	this.href = href;
	this.frame = frame;
	this.length = length;
	this.spacing = spacing;
	this.target = target;
	this.ref = null;
}
function go(link,frame) {
	tmp=eval("top."+frame);
	tmp.location=link;
        //top.main_window.location=link;
}
function writeMenus() {
	if (!isDOM && !isIE4 && !isNS4) return;
	for (currMenu = 0; currMenu < menu.length; currMenu++) with (menu[currMenu][0]) {
		var str = '', itemX = 0, itemY = 0;
		for (currItem = 1; currItem < menu[currMenu].length; currItem++) with (menu[currMenu][currItem]) {
			var itemID = 'menu' + currMenu + 'item' + currItem;
			var w = (isVert ? width : length);
			var h = (isVert ? length : width);
			if (isDOM \|\| isIE4) {
				str += '<div id="' + itemID + '" style="position: absolute; left: ' + itemX + '; top: ' + itemY + '; width: ' + w + '; height: ' + h + '; visibility: inherit; ';
				if (backCol) str += 'background: ' + backCol + '; ';
				str += '" ';
			}
			if (isNS4) {
				str += '<layer id="' + itemID + '" left="' + itemX + '" top="' + itemY + '" width="' +  w + '" height="' + h + '" visibility="inherit" ';
				if (backCol) str += 'bgcolor="' + backCol + '" ';
			}
			if (borderClass) str += 'class="' + borderClass + '" "';
			str += 'onMouseOver="popOver(' + currMenu + ',' + currItem + ')" onMouseOut="popOut(' + currMenu + ',' + currItem + ')">';
			str += '<table width="' + (w - 8) + '" border="0" cellspacing="0" cellpadding="' + (!isNS4 && borderClass ? 3 : 0) + '">';
			str +='<tr><td class="' + textClass + '" style="cursor:pointer;" align="left" height="' + (h - 7) + '" onClick=\\'go("' + href + '","' + frame + '")\\'>' + text + '</a></td>';
			if (target > 0) {
				menu[target][0].parentMenu = currMenu;
				menu[target][0].parentItem = currItem;
				if (popInd) str += '<td class="' + textClass + '" align="right">' + popInd + '</td>';
			}
			str += '</tr></table>' + (isNS4 ? '</layer>' : '</div>');
			if (isVert) itemY += length + spacing;
			else itemX += length + spacing;
		}
		if (isDOM) {
			var newDiv = document.createElement('div');
			document.getElementsByTagName('body').item(0).appendChild(newDiv);
			newDiv.innerHTML = str;
			ref = newDiv.style;
			ref.position = 'absolute';
			ref.visibility = 'hidden';
		}
		if (isIE4) {
			document.body.insertAdjacentHTML('beforeEnd', '<div id="menu' + currMenu + 'div" ' + 'style="position: absolute; visibility: hidden">' + str + '</div>');
			ref = getSty('menu' + currMenu + 'div');
		}
		if (isNS4) {
			ref = new Layer(0);
			ref.document.write(str);
			ref.document.close();
		}
		for (currItem = 1; currItem < menu[currMenu].length; currItem++) {
			itemName = 'menu' + currMenu + 'item' + currItem;
			if (isDOM \|\| isIE4) menu[currMenu][currItem].ref = getSty(itemName);
			if (isNS4) menu[currMenu][currItem].ref = ref.document[itemName];
		}
	}
	with(menu[0][0]) {
		ref.left = x;
		ref.top = y;
		ref.visibility = 'visible';
   }
}
var menu = new Array();
var defOver = '#cccccc';
var defBack = '#dddddd';
var defLength = 22;
menu[0] = new Array();
menu[0][0] = new Menu(false, '', 5, 18, 19, '#cccccc', '', '', 'rootItemText');

|;

  &section_menu($menu);

  print qq|
var popOldWidth = window.innerWidth;
nsResizeHandler = new Function('if (popOldWidth != window.innerWidth) location.reload()');
if (isNS4) document.captureEvents(Event.CLICK);
document.onclick = clickHandle;
function clickHandle(evt) {
	if (isNS4) document.routeEvent(evt);
	hideAllBut(0);
	if (KO) document.getElementById("win1").style.visibility = "visible";
}
function moveRoot() {
	with(menu[0][0].ref) left = ((parseInt(left) < 100) ? 100 : 5);
}
//  End -->
</script>

<BODY scrolling="no" topmargin="0" leftmargin="0"  marginwidth="0" marginheight="0" style="margin: 0" onLoad="writeMenus(); clockon();" onResize="if (isNS4) nsResizeHandler()">


<table class="menu" width="100%" border="0" cellpadding="0" cellspacing="0">
<tr><td height="21"><font size="1"> </font></td></tr></table>


|;

  print qq|
  
|;

}

sub section_menu {
  my ($menu, $level) = @_;

  # build tiered menus
  my @menuorder = $menu->access_control(\%myconfig, $level);
  $main = 0;

  #$pm=0;
  $shlp=0;
  while (@menuorder) {
    $item  = shift @menuorder;
    $label = $item;
    $ml    = $item;
    $label =~ s/$level--//g;
    $ml    =~ s/--.*//;
    $label = $locale->text($label);
    $label =~ s/ /&nbsp;/g;
    $menu->{$item}{target} = "main_window" unless $menu->{$item}{target};

    if ($menu->{$item}{submenu}) {
      $menu->{$item}{$item} = !$form->{$item};

      # Untermen
      if ($mlz{"s$ml"} > 1) { 
		$z++; 
		$sm = 1; 
      } else { 
		$z = $sm; 
		$mlz{"s$ml"}++; 
      }
      print
        qq|menu[$mlz{$ml}][$z] = new Item('$label', '#', '', defLength, 0, |
        . ++$pm
        . qq|);\n|;
      $sm = 1;
      print qq|menu[$pm] = new Array();\n|;
      print
        qq|menu[$pm][0] = new Menu(true, '', 85, 0, 180, defOver, defBack, 'itemBorder', 'itemText');\n|;
      map { shift @menuorder } grep /^$item/, @menuorder;
      &section_menu($menu, $item);
      map { shift @menuorder } grep /^$item/, @menuorder;
    } else {
      if ($menu->{$item}{module}) {

        #Untermenüpunkte
        $target = $menu->{$item}{target};
        $uri    = $menu->menuitem_js(\%myconfig, \%$form, $item, $level);

        print
          qq|menu[$pm][$sm] = new Item('$label', '$uri', '$target', defLength, 0, 0);\n|;
        $sm++;
      } else {    # Hauptmenu
        my $ml_ = $form->escape($ml);
        $mm++;
        $pm++;
        %mlz   = ($ml, $pm, "s$ml", 1);
        $shlp = $sm;
        $sm    = 1;
        $breit = 15 + length($label) * 6;
        print
          qq|menu[0][$mm] = new Item('  $label', '#', '', $breit, 10, $pm);	\n|;
        print qq|menu[$pm] = new Array();\n|;
        print
          qq|menu[$pm][0] = new Menu(true, '>', 0, 20, 180, defOver, defBack, 'itemBorder', 'itemText');\n|;

        &section_menu($menu, $item);

        #print qq|<br>\n|;
      }
    }
  }
}
