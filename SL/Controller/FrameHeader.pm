package SL::Controller::FrameHeader;

use strict;
use parent qw(SL::Controller::Base);

sub action_header {
  my ($self) = @_;

  delete $::form->{stylesheet};
  $::form->use_stylesheet('frame_header/header.css');
  $self->render('menu/header',
                now        => DateTime->now_local,
                is_fastcgi => scalar($::dispatcher->interface_type =~ /fastcgi/i),
                is_links   => scalar($ENV{HTTP_USER_AGENT}         =~ /links/i));
}

1;
