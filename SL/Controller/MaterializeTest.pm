package SL::Controller::MaterializeTest;

use strict;
use parent qw(SL::Controller::Base);

sub action_test {
  $_[0]->render("test/components");
}

1;
