package SL::Layout::Javascript;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::None;
use SL::Layout::Top;
use SL::Layout::ActionBar;
use SL::Layout::Content;

use List::Util qw(max);
use List::MoreUtils qw(uniq);
use URI;

sub init_sub_layouts {
  $_[0]->sub_layouts_by_name->{actionbar} = SL::Layout::ActionBar->new;
  [
    SL::Layout::None->new,
    SL::Layout::Top->new,
    SL::Layout::Content->new,
  ]
}

sub javascripts {
  my ($self) = @_;

  return uniq grep { $_ } map { $self->_find_javascript($_)  }
    map({ $_->javascripts } $self->sub_layouts),
    qw(dhtmlsuite/menu-for-applications.js),
    $_[0]->sub_layouts_by_name->{actionbar}->javascripts,
    $self->use_javascript;
}

sub javascripts_inline {
  $_[0]->SUPER::javascripts_inline,
<<'EOJS',
  DHTMLSuite.createStandardObjects();
  DHTMLSuite.configObj.setImagePath('image/dhtmlsuite/');
  var menu_model = new DHTMLSuite.menuModel();
  menu_model.addItemsFromMarkup('main_menu_model');
  menu_model.init();
  var menu_bar = new DHTMLSuite.menuBar();
  menu_bar.addMenuItems(menu_model);
  menu_bar.setTarget('main_menu_div');
  menu_bar.init();
EOJS
  $_[0]->sub_layouts_by_name->{actionbar}->javascripts_inline,
}

sub pre_content {
  $_[0]->SUPER::pre_content .
  $_[0]->presenter->render("menu/menunew",
    force_ul_width  => 1,
    menu            => $_[0]->menu,
    icon_path       => sub { my $simg = "image/icons/svg/$_[0].svg";  my $pimg="image/icons/16x16/$_[0].png"; -f $simg ? $simg : ( -f $pimg ? $pimg : ()) },
    max_width       => sub { 10 * max map { length $::locale->text($_->{name}) } @{ $_[0]{children} || [] } },
  ) .
  $_[0]->sub_layouts_by_name->{actionbar}->pre_content;
}

sub stylesheets {
  my ($self) = @_;
  my $css_path = $self->get_stylesheet_for_user;

  return
    uniq
    grep { $_ }
    map { $self->_find_stylesheet($_, $css_path)  }
    qw(
      dhtmlsuite/menu-item.css
      dhtmlsuite/menu-bar.css
      icons16.css
      menu.css
    ),
    ( map { $_->stylesheets } $_[0]->sub_layouts ),
    $_[0]->sub_layouts_by_name->{actionbar}->stylesheets,
    $_[0]->use_stylesheet;
}

1;
