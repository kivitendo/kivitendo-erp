package SL::Layout::V3;

use strict;
use parent qw(SL::Layout::Base);

use URI;

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

  $str .= qq|$module?action=| . $::form->escape($action) . qq|&level=| . $::form->escape($level);

  map { delete $menuitem->{$_} } qw(module action target href);

  # add other params
  foreach my $key (keys %{ $menuitem }) {
    $str .= "&" . $::form->escape($key, 1) . "=";
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

sub init_sub_layouts {
  [ SL::Layout::None->new ]
}

sub use_stylesheet {
  my $self = shift;
  qw(
   icons16.css frame_header/header.css
  ),
  $self->SUPER::use_stylesheet(@_);
}

sub use_javascript {
  my $self = shift;
  qw(
    js/quicksearch_input.js
  ),
  $self->SUPER::use_javascript(@_);
}

sub pre_content {
  $_[0]->render;
}

sub start_content {
  "<div id='content'>\n";
}

sub end_content {
  "</div>\n";
}

sub render {
  my ($self) = @_;

  my $callback            = $::form->unescape($::form->{callback});
  $callback               = URI->new($callback)->rel($callback) if $callback;
  $callback               = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;

  $self->presenter->render('menu/menuv3',
    force_ul_width => 1,
    date           => $self->clock_line,
    menu           => $self->print_menu,
    callback       => $callback,
  );
}

1;
