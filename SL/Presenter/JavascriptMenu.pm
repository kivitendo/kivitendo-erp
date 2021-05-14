package SL::Presenter::JavascriptMenu;

use strict;
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw( html_tag link_tag);
use SL::Locale::String qw(t8);
use SL::System::ResourceCache;

use List::Util qw(max);

use Exporter qw(import);
our @EXPORT_OK = qw(render_menu);

sub render_menu {
  my ($menu) = @_;

  html_tag('div', '', id => 'main_menu_div') .
  html_tag('ul', render_children($menu, 100, $menu->{tree}),
    id    => "main_menu_model",
    style => 'display:none',
  );
}

sub render_node {
  my ($menu, $node, $id) = @_;
  return '' if !$node->{visible};

  my $icon = get_icon($node->{icon});
  my $link = $menu->href_for_node($node) || '#';
  my $name = $menu->name_for_node($node);

  html_tag('li',
      link_tag($link, $name, target => $node->{target})
    . html_tag('ul', render_children($menu, $id * 100, $node->{children} // []),
        width => max_width($node)
      ),
    id        => $id,
    (itemIcon => $icon)x!!$icon,
  )
}

sub render_children {
  my ($menu, $id, $children) = @_;
  my $sub_id = 1;

  join '', map {
    render_node($menu, $_, 100 * $id + $sub_id++)
  } @$children
}

sub max_width {
  11 * ( max( map { length $::locale->text($_->{name}) } @{ $_[0]{children} || [] } ) // 1 )
}

sub get_icon {
  my $name = $_[0];

  return undef if !defined $name;

  my $simg = "image/icons/svg/$name.svg";
  my $pimg = "image/icons/16x16/$name.png";

    SL::System::ResourceCache->get($simg) ? $simg
  : SL::System::ResourceCache->get($pimg) ? $pimg
  :                                         ();
}

1;


