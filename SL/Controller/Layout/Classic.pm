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

sub stylesheets {
  $_[0]{top}->stylesheets,
  $_[0]{left}->stylesheets;
}

sub javascripts {
  $_[0]{top}->javascripts,
  $_[0]{left}->javascripts;
}

1;
