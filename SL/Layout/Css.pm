package SL::Layout::Css;

use strict;

use List::Util qw(max);
use Exporter qw(import);

our @EXPORT = qw(clock_line print_menu menuitem_v3);

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

  my $level = $::form->escape($item);

  my $str = qq|<a href="$module?action=| . $::form->escape($action) . qq|&level=| . $::form->escape($level);

  my @vars = qw(module action target href);

  if ($menuitem->{href}) {
    $str  = qq|<a href="$menuitem->{href}|;
    @vars = qw(module target href);
  }

  map { delete $menuitem->{$_} } @vars;

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

1;
