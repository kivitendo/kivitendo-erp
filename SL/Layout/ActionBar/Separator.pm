package SL::Layout::ActionBar::Separator;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

use SL::Presenter::Tag qw(html_tag);

sub from_params { $_[0]->new }

sub render {
  html_tag('div', '', class => 'layout-actionbar-separator');
}

sub script {
  ()
}

1;
