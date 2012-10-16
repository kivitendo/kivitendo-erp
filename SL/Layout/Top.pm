package SL::Layout::Top;

use strict;
use parent qw(SL::Layout::Base);

sub pre_content {
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
