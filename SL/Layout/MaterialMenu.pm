package SL::Layout::MaterialMenu;

use strict;
use parent qw(SL::Layout::Base);
use SL::Menu;
use SL::Controller::Base;

sub init_menu {
  SL::Menu->new('mobile');
}

sub pre_content {
  $_[0]->presenter->render('menu/menu', menu => $_[0]->menu, C => SL::Controller::Base->new);
}

1;
