package SL::Layout::ActionBar::Action;

use strict;
use parent qw(Rose::Object);

use SL::Presenter;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(id params text) ],
);

# subclassing interface

sub render {
  die 'needs to be implemented';
}

sub script {
  sprintf q|$('#%s').data('action', %s);|, $_[0]->id, JSON->new->allow_blessed->convert_blessed->encode($_[0]->params);
}

# this is mostly so that outside consumer don't need to load subclasses themselves
sub from_params {
  my ($class, $data) = @_;

  require SL::Layout::ActionBar::Submit;

  my ($text, %params) = @$data;
  return if exists($params{only_if}) && !$params{only_if};
  return if exists($params{not_if})  &&  $params{not_if};
  return SL::Layout::ActionBar::Submit->new(text => $text, params => \%params);
}

sub callable { 0 }

# shortcut for presenter

sub p {
  SL::Presenter->get
}

sub init_params {
  +{}
}

# unique id to tie div and javascript together
sub init_id {
  $_[0]->params->{id} //
  $_[0]->p->name_to_id('action[]')
}


1;

__END__

=head 1

planned options for clickables:

- checks => [ ... ] (done)

a list of functions that need to return true before submitting

- submit => [ form-selector, { params } ] (done)

on click submit the form specified by form-selector with the additional params

- function => function-name (done)

on click call the specified function (is this a special case of checks?)

- disabled => true/false/tooltip explaning why disabled (done)

TODO:

- runtime disable/enable
