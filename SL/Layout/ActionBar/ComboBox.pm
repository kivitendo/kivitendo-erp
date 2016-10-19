package SL::Layout::ActionBar::ComboBox;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

use JSON;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(actions) ],
);

sub parsed_actions {
  $_[0]{parsed_actions} ||=
    [ map { SL::Layout::ActionBar::Action->simple($_) } @{ $_[0]->actions || [] } ];
}

sub add_actions {
  push @{$_[0]{actions} //= $_[0]->init_actions}, @_[1..$#_]
}

sub render {
  my ($first, @rest) = @{ $_[0]->parsed_actions };
  $_[0]->p->html_tag('div',
    $_[0]->p->html_tag('div', $first->render . $_[0]->p->html_tag('span'), class => 'layout-actionbar-combobox-head') .
    $_[0]->p->html_tag('div', join('', map { $_->render } @rest), class => 'layout-actionbar-combobox-list'),
    id    => $_[0]->id,
    class => 'layout-actionbar-combobox',
  );
}

sub script {
  map { $_->script } @{ $_[0]->parsed_actions }
}

sub init_actions { [] }

1;
