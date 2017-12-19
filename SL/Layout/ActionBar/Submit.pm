package SL::Layout::ActionBar::Submit;

use strict;
use parent qw(SL::Layout::ActionBar::Action);

use SL::Presenter::Tag qw(html_tag);

sub render {
  html_tag('div', $_[0]->text,
    id    => $_[0]->id,
    class => 'layout-actionbar-action layout-actionbar-submit',
  );
}

sub callable {
  my ($self) = @_;
  return $self->params->{submit} || $self->params->{call} || $self->params->{link};
}

1;
