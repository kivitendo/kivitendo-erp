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
  <frame  src="controller.pl?action=FrameHeader/header" scrolling="NO">
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
  my $menu         = Menu->new("menu.ini");
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
  my @menuorder = $menu->access_control(\%::myconfig, $level);

  for my $item (@menuorder) {
    my $menuitem   = $menu->{$item};
    my $label      = apply { s/.*--// } $item;
    my $ml         = apply { s/--.*// } $item;
    my $show       = $ml eq $mainlevel;
    my $spacer     = $nbsp x (($item =~ s/--/--/g) * 2);
    my $label_icon = $level . "--" . $label . ".png";

    next if $level && $item ne "$level--$label";

    $label         = $::locale->text($label);

    $menuitem->{target} ||= "main_window";

    my $anchor     = $menu->menuitem(\%::myconfig, $::form, $item, $level);

    if (!$level) { # toplevel
      my $ml_    = $::form->escape($ml);
      my $image  = make_image(icon => $item . '.png', size => 24, label => $label, valign => 'middle');
      my $anchor = "<a href='menu.pl?action=acc_menu&level=$ml_' class='nohover' title='$label'>";

      print make_item(a => $anchor, img => $image, label => $label, height => 24);
      section_menu($menu, $item);

    } elsif ($menuitem->{submenu}) {
      my $image = make_image(submenu => 1);
      if ($mainlevel && $item =~ /^\Q$mainlevel\E/) {
        print make_item(spacer => $spacer, bold => 1, img => $image, label => $label) if $show;
        section_menu($menu, $item);
      } else {
        print make_item(spacer => $spacer, a => $anchor, img => $image, label => $label . '&nbsp;...') if $show;
      }
    } elsif ($menuitem->{module}) {
      my $image = make_image(label => $label, icon => $label_icon);
      print make_item(img => $image, a => $anchor, spacer => $spacer, label => $label) if $show;
      section_menu($menu, $item) if $show && $::form->{$item} && $::form->{level} eq $item;
    }
  }
  $::lxdebug->leave_sub;
}

sub make_item {
  my %params = @_;
  my $anchor = $params{a} || '';
  my @chunks = multiline($params{label});
  my $spacer = $params{spacer} || '';
  my $image  = $params{img};
  my $height = $params{height} || 16;
  my $a_end  = $anchor       ? '</a>' : '';
  my $bold   = $params{bold} ?  '<b>' : '';
  my $b_end  = $bold         ? '</b>' : '';
  my $hidden_image = make_image(hidden => 1);
  return join "\n",
        "<tr><td class='hover' height='$height'>$bold$spacer$anchor$image$chunks[0]$a_end$b_end</td></tr>\n",
    map "<tr style='vertical-align:top'><td class='hover'>$bold$spacer$hidden_image$anchor$chunks[$_]$a_end$b_end</td></tr>\n",
      1..$#chunks;
}

# multi line hack, sschoeling jul06
# if a label is too long, try to split it at whitespaces, then join it to chunks of less
# than 20 chars and store it in an array.
# use this array later instead of the &nbsp;-ed label
sub multiline {
  my ($label) = @_;
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
  return @chunks;
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

sub _icon_path {
  my ($label, $size) = @_;

  $size ||= 16;

  return "image/icons/${size}x${size}/$label";
}

1;

__END__
