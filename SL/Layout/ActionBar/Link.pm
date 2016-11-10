package SL::Layout::ActionBar::Link;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

sub from_params {
  my ($class, $data) = @_;

  my ($text, %params) = @$data;
  return SL::Layout::ActionBar::Link->new(text => $text, params => \%params);
}

sub render {
  my ($self) = @_;

  return $self->p->html_tag(
    'a', $self->text,
    %{ $self->params // {} },
    id    => $self->id,
    class => 'layout-actionbar-link',
  );
}

1;
