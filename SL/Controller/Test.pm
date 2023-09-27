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

sub action_ckeditor_test_page {
  my ($self) = @_;

  $self->render("test/ckeditor");
}

1;
