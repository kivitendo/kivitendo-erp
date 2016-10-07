package SL::Layout::ActionBar::ScriptButton;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

sub render {
  $_[0]->p->html_tag('div', $_[0]->text,
    id    => $_[0]->id,
    class => 'layout-actionbar-action layout-actionbar-scriptbutton',
  );
}

1;
