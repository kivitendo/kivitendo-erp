package SL::Layout::MenuLeft;

use strict;
use parent qw(SL::Layout::Base);

use List::MoreUtils qw(apply);
use SL::JSON qw(to_json);
use URI;

sub stylesheets {
  qw(icons16.css icons24.css menu.css)
}

sub javascripts_inline {
  "\$(function(){kivi.LeftMenu.init(@{[ to_json([ section_menu($_[0]->menu) ]) ]})});"
}

sub javascripts {
  qw(
    js/jquery.cookie.js
    js/kivi.LeftMenu.js
  );
}

sub pre_content {
  "<div id='html-menu'></div>\n";
}

sub section_menu {
  my ($menu) = @_;
  my @items;
  my @id_stack = (-1);

  for my $node ($menu->tree_walk) {
    my $level      = $node->{level};

    # do id stack
    push @id_stack, -1 if    $level > $#id_stack;
    pop @id_stack      while $level < $#id_stack;
    $id_stack[-1]++;

    my $label = $::locale->text($node->{name});
    my $href  = $menu->href_for_node($node);

    my @common_args  = ($label, "s" . $level, join '_', @id_stack);

    if (!$node->{parent}) { # toplevel
      push @items, [ @common_args, "icon24 $node->{icon}", 'm' ];
    } elsif ($node->{children}) {
      push @items, [ @common_args, "icon16 submenu", 'sm' ];
    } else {
      push @items, [ @common_args, "icon16 $node->{icon}", 'i', $href, $node->{target} ];
    }
  }

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
