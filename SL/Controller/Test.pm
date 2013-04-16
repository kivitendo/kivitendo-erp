package SL::Controller::Test;

use strict;

use parent qw(SL::Controller::Base);

use Data::Dumper;
use SL::ClientJS;

sub action_dump_form {
  my ($self) = @_;

  my $output = Dumper($::form);
  $self->render(\$output, { type => 'text' });
}

1;
