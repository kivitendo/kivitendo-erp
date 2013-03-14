package SL::Layout::MenuLeft;

use strict;
use parent qw(SL::Layout::Base);

use URI;

use List::MoreUtils qw(apply);

sub stylesheets {
  qw(icons16.css icons24.css menu.css)
}

sub javascripts_inline {
  my $self = shift;
  $self->SUPER::javascripts_inline;
  my $sections = [ section_menu($self->menu) ];
  $self->presenter->render('menu/menu',
    sections  => $sections,
  )
}

sub javascripts {
  qw(
    js/jquery.cookie.js
    js/switchmenuframe.js
  );
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

    my @common_args = ($label, $spacer, "$id_prefix\_$id");

    if (!$level) { # toplevel
      push @items, [ @common_args, "icon24 $icon_class", 'm' ];
      #  make_image(size => 24, label => $item),
      push @items, section_menu($menu, $item, "$id_prefix\_$id");
    } elsif ($menuitem->{submenu}) {
      push @items, [ @common_args, "icon16 submenu", 'sm' ];
      #make_image(label => 'submenu'),
      push @items, section_menu($menu, $item, "$id_prefix\_$id");
    } elsif ($menuitem->{module}) {
      push @items, [ @common_args, "icon16 $icon_class", 'i', $menuitem->{href}, $menuitem->{target} ];
      #make_image(size => 16, label => $item),
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

__END__

=encoding utf-8

=head1 NAME

SL::Layout::MenuLeft - ex html meanu, now only left menu

=head1 DOM MODEL

Data will be embedded into the page as a json array of entries.
Each entry is another array with the following fields:

  0: title
  1: indentation classes
  2: unique id
  3: icon classes
  4: role classes
  5: href
  6: target

From each entry the following dom will be generated, with [0] being entry 0 of
the data array:

  <div id="mi[2]" class="mi [4] [1]">
    <a class="ml">
      <span class="mii ms">
        <div class="[3]"></div>
      </span>
      <span class="mic">[0]</span>
    </a>
  </div>

The classes are minified to keep the json somewhat in check, their meaning is as follows:

=over 4

=item Indentation Classes

  s0: No indentation
  s1: One level of indentation
  s2: Two levels of indentation

=item Icon Classes

Each icon consists of two classes, one for the icon, and one for the size.
The icon classes are taken from the file names, for example C<Master-Data> is
the icon for master data, and refers to Master-Icon.png.

  icon16: 16x16 icon
  icon24: 24x24 icon
  icon32: 32x32 icon

=item Role Classes

Role classes may be used to style types of links differently. Currently used:

  ml:  menu link, any <a> tag will have this
  mi:  menu item, the enclosing div for each entry has this
  mii: menu item icon, the enclosing div for the icons has this
  ms:  menu spacer, the first <span> in the link will have this
  m:   menu, only top level entries have this
  i:   item, only leaf entries have this
  sm:  sub menu, eveything that is not top nor leaf has this
  mic: menu item content, the span with the human readable description has this

=back

=head1 BUGS

none yet

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
