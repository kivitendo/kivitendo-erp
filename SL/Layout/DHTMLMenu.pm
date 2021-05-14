package SL::Layout::DHTMLMenu;

use strict;
use parent qw(SL::Layout::Base);

use SL::Presenter::JavascriptMenu qw(render_menu);

sub static_javascripts {
  qw(dhtmlsuite/menu-for-applications.js),
}

sub javascripts_inline {
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
}

sub pre_content {
  render_menu($_[0]->menu),
}

sub static_stylesheets {
  qw(
    dhtmlsuite/menu-item.css
    dhtmlsuite/menu-bar.css
    icons16.css
    menu.css
  );
}

1;
