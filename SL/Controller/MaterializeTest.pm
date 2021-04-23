package SL::Controller::MaterializeTest;

use strict;
use parent qw(SL::Controller::Base);

sub action_components {
  $_[0]->render("test/components");
}

sub action_modal {
  $_[0]->render("test/modal");
}

1;
