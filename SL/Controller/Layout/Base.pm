package SL::Controller::Layout::Base;

use strict;
use parent qw(SL::Controller::Base);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => qw(menu),
);

use SL::Menu;

my %menu_cache;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);
}

sub init_menu {
  Menu->new('menu.ini');
}

sub pre_content {
}

sub start_content {
}

sub end_content {
}

sub post_content {
}

sub stylesheets {
}

sub stylesheets_inline {
}

sub javascript_inline {
}

1;
