package SL::Layout::Javascript;

use strict;
use parent qw(SL::Layout::Base);

use List::Util qw(max);
use URI;

sub init_sub_layouts {
  [ SL::Layout::None->new ]
}

sub use_javascript {
  my $self = shift;
  qw(
    js/quicksearch_input.js
  ),
  $self->SUPER::use_javascript(@_);
}

sub pre_content {
  &display
}

sub start_content {
  "<div id='content'>\n";
}

sub end_content {
  "</div>\n";
}

sub stylesheets {
  $_[0]->add_stylesheets(qw(
    dhtmlsuite/menu-item.css
    dhtmlsuite/menu-bar.css
    icons16.css
    frame_header/header.css
    menu.css
  ));
  $_[0]->SUPER::stylesheets;
}

sub display {
  my ($self) = @_;
  my $form     = $main::form;

  my $callback            = $form->unescape($form->{callback});
  $callback               = URI->new($callback)->rel($callback) if $callback;
  $callback               = "login.pl?action=company_logo"      if $callback =~ /^(\.\/)?$/;

  $self->presenter->render("menu/menunew",
    force_ul_width  => 1,
    date            => $self->clock_line,
    menu_items      => $self->acc_menu,
    callback        => $callback,
  );
}

sub clock_line {
  my $form     = $main::form;

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

sub acc_menu {
  my ($self) = @_;

  my $menu      = $self->menu;

  my $all_items = [];
  $self->create_menu($menu, $all_items);

  my $item = { 'subitems' => $all_items };
  calculate_width($item);

  return $all_items;
}

sub calculate_width {
  my $item           = shift;

  $item->{max_width} = max map { length $_->{title} } @{ $item->{subitems} };

  foreach my $subitem (@{ $item->{subitems} }) {
    calculate_width($subitem) if ($subitem->{subitems});
  }
}

sub create_menu {
  my ($self, $menu, $all_items, $parent, $depth) = @_;
  my $html;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $depth ||= 0;

  die if ($depth * 1 > 5);

  my @menuorder  = $menu->access_control(\%myconfig, $parent);
  $parent       .= "--" if ($parent);
  $parent      ||= '';

  foreach my $name (@menuorder) {
    substr($name, 0, length($parent), "");
    next if (($name eq "") || ($name =~ /--/));

    my $menu_item = $menu->{"${parent}${name}"};
    my $item      = { 'title' => $::locale->text($name) };
    push @{ $all_items }, $item;

    if ($menu_item->{submenu} || (!defined($menu_item->{module}) && !defined($menu_item->{href}))) {
      $item->{subitems} = [];
      $item->{image} = _icon_path("$name.png");
      $self->create_menu($menu, $item->{subitems}, "${parent}${name}", $depth * 1 + 1);

    } else {
      $item->{image} = _icon_path("${parent}${name}.png");
      $menu->menuitem_new("${parent}${name}", $item);
    }
  }
}

sub _icon_path {
  my ($label, $size) = @_;

  $size ||= 16;

  my $img = "image/icons/${size}x${size}/$label";

  return unless -f $img;
  return $img;
}

1;
