package SL::Layout::ActionBar::Action;

use strict;
use parent qw(Rose::Object);

use SL::Presenter;
    require SL::Layout::ActionBar::Submit;

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

# static constructors

sub from_descriptor {
  my ($class, $descriptor) = @_;
  require SL::Layout::ActionBar::Separator;
  require SL::Layout::ActionBar::ComboBox;

  return {
     separator => SL::Layout::ActionBar::Separator->new,
     combobox  => SL::Layout::ActionBar::ComboBox->new,
  }->{$descriptor} || do { die 'unknown descriptor' };
}

# this is mostly so that outside consumer don't need to load subclasses themselves
sub simple {
  my ($class, $data) = @_;

  my ($text, %params) = @$data;
  return SL::Layout::ActionBar::Submit->new(text => $text, params => \%params);
}

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

