package SL::Layout::ActionBar::ComboBox;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

use JSON;
use List::MoreUtils qw(none);
use SL::Presenter::Tag qw(html_tag);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(actions) ],
);

sub from_params {
  my ($class, $actions) = @_;

  my $combobox = $class->new;
  push @{ $combobox->actions }, SL::Layout::ActionBar->parse_actions(@{ $actions });

  return $combobox;
}

sub render {
  my ($first, @rest) = @{ $_[0]->actions };

  return                if none { $_->callable } @{ $_[0]->actions };
  return $first->render if !@rest;

  html_tag('div',
    html_tag('div', $first->render . html_tag('span'), class => 'layout-actionbar-combobox-head') .
    html_tag('div', join('', map { $_->render } @rest), class => 'layout-actionbar-combobox-list'),
    id    => $_[0]->id,
    class => 'layout-actionbar-combobox',
  );
}

sub script {
  map { $_->script } @{ $_[0]->actions }
}

sub init_actions { [] }

1;
