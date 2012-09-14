package SL::Controller::Layout::Classic;

use strict;
use parent qw(SL::Controller::Layout::Base);

use SL::Controller::Layout::Top;
use SL::Controller::Layout::MenuLeft;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);

  $self->add_sub_layouts([
    SL::Controller::Layout::Top->new,
    SL::Controller::Layout::MenuLeft->new,
  ]);

  $self;
}

1;
