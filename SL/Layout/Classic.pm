package SL::Layout::Classic;

use strict;
use parent qw(SL::Layout::Base);

use SL::Layout::Top;
use SL::Layout::MenuLeft;

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);

  $self->add_sub_layouts([
    SL::Layout::Top->new,
    SL::Layout::MenuLeft->new,
    SL::Layout::None->new,
  ]);

  $self;
}

1;
