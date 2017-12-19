package SL::Layout::ActionBar::Link;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

use SL::Presenter::Tag qw(html_tag);

sub from_params {
  my ($class, $data) = @_;

  my ($text, %params) = @$data;

  return if exists($params{only_if}) && !$params{only_if};
  return if exists($params{not_if})  &&  $params{not_if};
  return SL::Layout::ActionBar::Link->new(text => $text, params => \%params);
}

sub render {
  my ($self) = @_;

  html_tag(
    'div', $self->text,
    id    => $self->id,
    class => 'layout-actionbar-action layout-actionbar-link',
  );
}

sub callable { 1 }

1;
