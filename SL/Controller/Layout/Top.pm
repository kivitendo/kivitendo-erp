package SL::Controller::Layout::Top;

use strict;
use parent qw(SL::Controller::Layout::Base);

sub render {
  my ($self) = @_;

  $self->SUPER::render('menu/header', { partial => 1, no_output => 1 },
                now        => DateTime->now_local,
                is_fastcgi => scalar($::dispatcher->interface_type =~ /fastcgi/i),
                is_links   => scalar($ENV{HTTP_USER_AGENT}         =~ /links/i));
}

sub stylesheets {
# 'frame_header/header.css';
}

1;
