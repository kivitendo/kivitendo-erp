package SL::Layout::ActionBar::Separator;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

sub from_params { $_[0]->new }

sub render {
  $_[0]->p->html_tag('div', '', class => 'layout-actionbar-separator');
}

sub script {
  ()
}

1;
