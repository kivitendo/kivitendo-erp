package SL::Layout::AsyncMsg;

use strict;
use parent qw(SL::Layout::Base);

use SL::Helper::UserPreferences::DisplayPreferences;


sub static_javascripts {
  return 'kivi.AsyncMsg.js' if SL::Helper::UserPreferences::DisplayPreferences->new()->get_async_messages();
}


1;
