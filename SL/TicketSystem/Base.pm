package SL::TicketSystem::Base;

use strict;
use SL::Locale::String;

sub type {
  die "needs to be implemented";
}

sub title {
  die "needs to be implemented";
}

sub columns {
  die "needs to be implemented";
}

sub get_tickets {
  die "needs to be implemented";
}

1;

# base class for oauth providers
