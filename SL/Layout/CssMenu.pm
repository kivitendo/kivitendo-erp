package SL::Layout::CssMenu;

use strict;
use parent qw(SL::Layout::Base);

use URI;

sub print_menu {
  my ($self, $parent, $depth) = @_;

  my $html;

  die if ($depth * 1 > 5);

  my @menuorder;
  my $menu = $self->menu;

  @menuorder = $menu->access_control(\%::myconfig, $parent);

  $parent .= "--" if ($parent);

  foreach my $item (@menuorder) {
    substr($item, 0, length($parent)) = "";
    next if (($item eq "") || ($item =~ /--/));

    my $menu_item = $menu->{"${parent}${item}"};
    my $menu_title = $::locale->text($item);
    my $menu_text = $menu_title;

    if ($menu_item->{"submenu"} || !defined($menu_item->{"module"}) && !defined($menu_item->{href})) {

      my $h = $self->print_menu("${parent}${item}", $depth * 1 + 1)."\n";
      if (!$parent) {
        $html .= qq|<ul><li><h2>${menu_text}</h2><ul>${h}</ul></li></ul>\n|;
      } else {
        $html .= qq|<li><div class="x">${menu_text}</div><ul>${h}</ul></li>\n|;
      }
    } else {
      if ($self->{sub_class} && $depth > 1) {
        $html .= qq|<li class='sub'>|;
      } else {
        $html .= qq|<li>|;
      }
      $html .= $self->menuitem_v3("${parent}$item", { "title" => $menu_title });
      $html .= qq|${menu_text}</a></li>\n|;
    }
  }

  return $html;
}

sub menuitem_v3 {
  $main::lxdebug->enter_sub();

  my ($self, $item, $other) = @_;
  my $menuitem = $self->menu->{$item};

  my $action = "section_menu";
  my $module;

  if ($menuitem->{module}) {
    $module = $menuitem->{module};
  }
  if ($menuitem->{action}) {
    $action = $menuitem->{action};
  }

  my $level  = $::form->escape($item);

  my @vars;
  my $target = $menuitem->{target} ? qq| target="| . $::form->escape($menuitem->{target}) . '"' : '';
  my $str    = qq|<a${target} href="|;

  if ($menuitem->{href}) {
    $main::lxdebug->leave_sub();
    return $str . $menuitem->{href} . '">';
  }

  $str .= qq|$module?action=| . $::form->escape($action);

  map { delete $menuitem->{$_} } qw(module action target href);

  # add other params
  foreach my $key (keys %{ $menuitem }) {
    $str .= "&amp;" . $::form->escape($key, 1) . "=";
    my ($value, $conf) = split(/=/, $menuitem->{$key}, 2);
    $value = $::myconfig{$value} . "/$conf" if ($conf);
    $str .= $::form->escape($value, 1);
  }

  $str .= '"';

  if ($other) {
    foreach my $key (keys(%{$other})) {
      $str .= qq| ${key}="| . $::form->quote($other->{$key}) . qq|"|;
    }
  }

  $str .= ">";

  $main::lxdebug->leave_sub();

  return $str;
}

sub use_stylesheet {
  qw(icons16.css frame_header/header.css),
}

sub pre_content {
  $_[0]->presenter->render('menu/menuv3',
    menu           => $_[0]->print_menu,
  );
}

1;
