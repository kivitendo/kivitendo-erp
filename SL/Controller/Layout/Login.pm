package SL::Controller::Layout::Login;

use strict;
use parent qw(SL::Controller::Layout::Base);

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);

  $self->add_sub_layouts([
    SL::Controller::Layout::None->new,
  ]);

  $self;
}

sub start_content {
  "<div id='login' class='login'>\n";
}

sub end_content {
  "</div>\n";
}

1;
