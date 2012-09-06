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
use URI;

use List::MoreUtils qw(apply);

# end of main

sub display {
  $::lxdebug->enter_sub;

  my $callback  = $::form->unescape($::form->{callback});
  $callback     = URI->new($callback)->rel($callback) if $callback;
  $callback     = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;
  my $framesize = _calc_framesize();

  $::form->header(doctype => 'frameset');

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

  $::form->{stylesheet} = [ qw(css/icons16.css css/icons24.css ) ];

  my $framesize    = _calc_framesize() - 2;
  my $menu         = Menu->new("menu.ini");
  $::form->{title} = $::locale->text('kivitendo');
  $::form->header;

  my $sections = [ section_menu($menu) ];

  print $::form->parse_html_template('menu/menu', {
    framesize => $framesize,
    sections  => $sections,
  });

  $::lxdebug->leave_sub;
}

sub section_menu {
  $::lxdebug->enter_sub;
  my ($menu, $level, $id_prefix) = @_;
  my @menuorder = $menu->access_control(\%::myconfig, $level);
  my @items;

  my $id = 0;

  for my $item (@menuorder) {
    my $menuitem   = $menu->{$item};
    my $olabel     = apply { s/.*--// } $item;
    my $ml         = apply { s/--.*// } $item;
    my $icon_class = apply { y/ /-/   } $item;
    my $spacer     = "s" . (0 + $item =~ s/--/--/g);

    next if $level && $item ne "$level--$olabel";

    my $label         = $::locale->text($olabel);

    $menuitem->{module} ||= $::form->{script};
    $menuitem->{action} ||= "section_menu";
    $menuitem->{target} ||= "main_window";
    $menuitem->{href}   ||= "$menuitem->{module}?action=$menuitem->{action}";

    # add other params
    foreach my $key (keys %$menuitem) {
      next if $key =~ /target|module|action|href/;
      $menuitem->{href} .= "&" . $::form->escape($key, 1) . "=";
      my ($value, $conf) = split(/=/, $menuitem->{$key}, 2);
      $value = $::myconfig{$value} . "/$conf" if ($conf);
      $menuitem->{href} .= $::form->escape($value, 1);
    }

    my $anchor = $menuitem->{href};

    my %common_args = (
        label   => $label,
        spacer  => $spacer,
        target  => $menuitem->{target},
        item_id => "$id_prefix\_$id",
        height  => 16,
    );

    if (!$level) { # toplevel
      push @items, { %common_args,
        img      => "icon24 $icon_class",   #  make_image(size => 24, label => $item),
        height   => 24,
        class    => 'm',
      };
      push @items, section_menu($menu, $item, "$id_prefix\_$id");
    } elsif ($menuitem->{submenu}) {
      push @items, { %common_args,
        img      => "icon16 submenu",   #make_image(label => 'submenu'),
        class    => 'sm',
      };
      push @items, section_menu($menu, $item, "$id_prefix\_$id");
    } elsif ($menuitem->{module}) {
      push @items, { %common_args,
        img     => "icon16 $icon_class",  #make_image(size => 16, label => $item),
        href    => $anchor,
        class   => 'i',
      };
    }
  } continue {
    $id++;
  }

  $::lxdebug->leave_sub;
  return @items;
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

1;

__END__
