package SL::Controller::Layout::Classic;

use strict;
use parent qw(SL::Controller::Layout::Base);

use SL::Controller::Layout::Top;
use SL::Controller::Layout::MenuLeft;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);

  $self->{top}  = SL::Controller::Layout::Top->new;
  $self->{left} = SL::Controller::Layout::MenuLeft->new;

  $self->use_stylesheet(
    $self->{top}->stylesheets,
    $self->{left}->stylesheets,
  );

  $self->use_javascript(
    $self->{top}->javascripts,
    $self->{left}->javascripts,
  );

  $self;
}

sub pre_content {
  $_[0]{top}->render .
  $_[0]{left}->render;
}

sub start_content {
  "<div id='content' class='html-menu'>\n";
}

sub end_content {
  "</div>\n";
}

1;
