package SL::Layout::ActionBar::Action;

use strict;
use parent qw(Rose::Object);

use SL::Presenter;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(id) ],
);

# subclassing interface

sub render {
  die 'needs to be implemented';
}

sub script {
  die 'needs to be implemented';
}


# static constructors

sub from_descriptor {
  my ($class, $descriptor) = @_;a

  {
     separator => SL::Layout::ActionBar::Separator->new,
  } or die 'unknown descriptor';
}

# TODO: this necessary?
sub simple {
  my ($class, $data) = @_;

  my ($text, %params) = @$data;

  if ($params{submit}) {
    require SL::Layout::ActionBar::Submit;
    return SL::Layout::ActionBar::Submit->new(text => $text, %params);
  }

  if ($params{function}) {
    require SL::Layout::ActionBar::ScriptButton;
    return SL::Layout::ActionBar::ScriptButton->new(text => $text, %params);
  }

  if ($params{combobox}) {

  }
}

# shortcut for presenter

sub p {
  SL::Presenter->get
}

# unique id to tie div and javascript together
sub init_id {
  $_[0]->p->name_to_id('action[]')
}


1;

__END__
