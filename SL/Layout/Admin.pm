package SL::Layout::Admin;

use strict;
use parent qw(SL::Layout::V3);

use SL::Menu;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(no_menu) ],
);


sub init_menu {
  Menu->new('menus/admin.ini');
}

sub start_content {
  "<div id='admin' class='admin'>\n";
}

sub render {
  my ($self) = @_;

  $self->presenter->render(
    'menu/menuv3',
    force_ul_width    => 1,
    skip_frame_header => 1,
    menu              => $self->no_menu ? '' : $self->print_menu,
  );
}

1;
