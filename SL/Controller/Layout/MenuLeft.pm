package SL::Controller::Layout::MenuLeft;

use strict;
use parent qw(SL::Controller::Layout::Base);

use URI;

use List::MoreUtils qw(apply);

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);

  $self;
}

sub stylesheets {
  qw(css/icons16.css css/icons24.css)
}

sub javascripts_inline {
  my $self = shift;
  my $sections = [ section_menu($self->menu) ];
  $self->render('menu/menu', { no_menu => 1, no_output => 1 },
    sections  => $sections,
  )
}

sub pre_content {
  "<div id='html-menu'></div>\n";
}

sub start_content {
  "<div id='content' class='html-menu'>\n";
}

sub end_content {
  "</div>\n";
}

sub section_menu {
  $::lxdebug->enter_sub(2);
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
        l   => $label,
        s  => $spacer,
        id => "$id_prefix\_$id",
    );

    if (!$level) { # toplevel
      push @items, { %common_args,
        i      => "icon24 $icon_class",   #  make_image(size => 24, label => $item),
        c    => 'm',
      };
      push @items, section_menu($menu, $item, "$id_prefix\_$id");
    } elsif ($menuitem->{submenu}) {
      push @items, { %common_args,
        i      => "icon16 submenu",   #make_image(label => 'submenu'),
        c    => 'sm',
      };
      push @items, section_menu($menu, $item, "$id_prefix\_$id");
    } elsif ($menuitem->{module}) {
      push @items, { %common_args,
        i     => "icon16 $icon_class",  #make_image(size => 16, label => $item),
        h    => $anchor,
        c   => 'i',
      };
    }
  } continue {
    $id++;
  }

  $::lxdebug->leave_sub(2);
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
