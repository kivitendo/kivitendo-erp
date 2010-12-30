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
# the frame layout with refractured menu
#
# CHANGE LOG:
#   DS. 2002-03-25  Created
#  2004-12-14 - New Optik - Marco Welter <mawe@linux-studio.de>
#  2010-08-19 - Icons for sub entries and single click behavior, unlike XUL-Menu
#               JS switchable HTML-menu - Sven Donath <lxo@dexo.de>
#######################################################################

use strict;

use SL::Menu;
use Data::Dumper;
use URI;

use List::MoreUtils qw(apply);

my $menufile = "menu.ini";
my $nbsp     = '&nbsp;';
my $mainlevel;

# end of main

sub display {
  $::lxdebug->enter_sub;

  my $callback  = $::form->unescape($::form->{callback});
  $callback     = URI->new($callback)->rel($callback) if $callback;
  $callback     = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;
  my $framesize = _calc_framesize();

  $::form->header;

  print qq|
<frameset rows="28px,*" cols="*" framespacing="0" frameborder="0">
  <frame  src="kopf.pl" name="kopf"  scrolling="NO">
  <frameset cols="$framesize,*" framespacing="0" frameborder="0" border="0" id="menuframe" name="menuframe">
    <frame src="$::form->{script}?action=acc_menu" name="acc_menu"  scrolling="auto" noresize marginwidth="0">
    <frame src="$callback" name="main_window" scrolling="auto">
  </frameset>
  <noframes>
  You need a browser that can read frames to see this page.
  </noframes>
</frameset>
</HTML>
|;

  $::lxdebug->leave_sub;
}

sub acc_menu {
  $::lxdebug->enter_sub;

  my $framesize    = _calc_framesize() - 2;
  my $menu         = Menu->new($::menufile);
  $mainlevel       = $::form->{level};
  $::form->{title} = $::locale->text('Lx-Office');
  $::form->header;

  print qq|
<body class="menu">

<div align="left">\n<table width="$framesize" border="0">\n|;

  section_menu($menu);

  print qq|</table></div>
</body>
</html>
|;

  $::lxdebug->leave_sub;
}

sub section_menu {
  $::lxdebug->enter_sub;
  my ($menu, $level) = @_;

  # build tiered menus
  my @menuorder = $menu->access_control(\%::myconfig, $level);
  for my $item (@menuorder) {
    my $menuitem   = $menu->{$item};
    my $label      = apply { s/.*--// } $item;
    my $ml         = apply { s/--.*// } $item;
    my $show       = $ml eq $mainlevel;
    my $spacer     = $nbsp x (($item =~ s/--/--/g) * 2);
    my $label_icon = $level . "--" . $label . ".png";

    $label         = $::locale->text($label);

    $menuitem->{target} ||= "main_window";

    my $anchor     = $menu->menuitem(\%::myconfig, $::form, $item, $level);

    next if $menuitem->{HIDDEN};

    # multi line hack, sschoeling jul06
    # if a label is too long, try to split it at whitespaces, then join it to chunks of less
    # than 20 chars and store it in an array.
    # use this array later instead of the &nbsp;-ed label
    my @chunks;
    my $l = 20;
    for (split / /, $label) {
      $l += length $_;
      if ($l < 20) {
        $chunks[-1] .= " $_";
      } else {
        $l = length $_;
        push @chunks, $_;
      }
    }
    # end multi line

    if ($menuitem->{submenu}) {
      if ($::form->{level} && $item =~ /^\Q$::form->{level}\E/) {
        my $image = make_image(submenu => 1);
        print "<tr><td style='vertical-align:bottom'><b>$spacer$image$label</b></td></tr>\n" if $show;

        # remove same level items
        $menu->{$_}{HIDDEN} = 1 for grep /^$item/, @menuorder;
        section_menu($menu, $item);
      } else {
        print "<tr><td>$anchor$label&nbsp;...</a></td></tr>\n" if $show;

        # remove same level items
        $menu->{$_}{HIDDEN} = 1 for grep /^$item/, @menuorder;
      }
    } elsif ($menuitem->{module}) {
      if ($::form->{$item} && $::form->{level} eq $item) {
        my $image = make_image();
        print qq|<tr><td valign=bottom>$spacer$image$anchor$label</a></td></tr>\n| if $show;

        # remove same level items
        $menu->{$_}{HIDDEN} = 1 for grep /^$item/, @menuorder;
        section_menu($menu, $item);
      } elsif ($show) {
        my $image1 = make_image(label => $label, icon => $label_icon);
        my $image2 = make_image(hidden => 1);
        print "<tr><td class='hover' height='16'>$spacer$anchor$image1$chunks[0]</a></td></tr>\n";
        print "<tr style='vertical-align:top'><td class='hover'>$spacer$image2$anchor$chunks[$_]</a></td></tr>\n"
          for 1..$#chunks;
      }
    } else {
      my $ml_    = $::form->escape($ml);
      my $image  = make_image(icon => $item . '.png', size => 24, label => $label, valign => 'middle');
      my $anchor = "<a href='menu.pl?action=acc_menu&level=$ml_' class='nohover' title='$label'>";
      print qq|<tr><td class="bg" height="24" align="left" valign="middle">$anchor$image$label</a></td></tr>\n|;

      &section_menu($menu, $item);
    }
  }
  $::lxdebug->leave_sub;
}

sub _calc_framesize {
  my $is_lynx_browser   = $ENV{HTTP_USER_AGENT} =~ /links/i;
  my $is_mobile_browser = $ENV{HTTP_USER_AGENT} =~ /mobile/i;
  my $is_mobile_style   = $::form->{stylesheet} =~ /mobile/i;

  return  $is_mobile_browser && $is_mobile_style ?  130
        : $is_lynx_browser                       ?  240
        :                                           200;
}

sub _show_images {
  # don't show images in links
  _calc_framesize() != 240;
}

sub make_image {
  my (%params) = @_;

  my $label  = $params{label};
  my $icon   = $params{icon};
  my $hidden = $params{hidden};
  my $size   = $params{size}   || 16;
  my $valign = $params{valign} || 'text-top';

  return unless _show_images();

  my $icon_found = $icon && -f _icon_path($icon, $size);

  my $image_url = $icon_found ? _icon_path($icon, $size) : "image/unterpunkt.png";
  my $style     = $hidden     ? "visibility:hidden"      : "vertical-align:$valign";
  my $width     = $hidden     ? "width='$size'"          : '';

  my $padding   = $size == 16 && $icon_found || $hidden ? $nbsp x 2
                : $size == 24                           ? $nbsp
                :                                         '';

  return "<img src='$image_url' border='0' style='$style' title='$label' $width>$padding";
}

sub _icon_path {
  my ($label, $size) = @_;

  $size ||= 16;

  return "image/icons/${size}x${size}/$label";
}

1;

__END__
