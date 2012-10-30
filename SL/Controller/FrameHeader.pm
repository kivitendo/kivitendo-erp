package SL::Controller::FrameHeader;

use strict;
use parent qw(SL::Controller::Base);

sub action_header {
  my ($self) = @_;

  $::form->use_stylesheet('frame_header/header.css');
  $self->render('menu/header', { partial => 1, no_output => 1 },
                now        => DateTime->now_local,
                is_fastcgi => scalar($::dispatcher->interface_type =~ /fastcgi/i),
                is_links   => scalar($ENV{HTTP_USER_AGENT}         =~ /links/i));
}

1;
