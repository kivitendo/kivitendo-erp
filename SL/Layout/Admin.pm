package SL::Layout::Admin;

use strict;
use parent qw(SL::Layout::Base);

sub new {
  my ($class, @slurp) = @_;

  my $self = $class->SUPER::new(@slurp);

  $self->add_sub_layouts([
    SL::Layout::None->new,
  ]);

  $self;
}

sub start_content {
  "<div id='admin' class='admin'>\n";
}

sub end_content {
  "</div>\n";
}

1;
