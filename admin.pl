#!/usr/bin/perl

use strict;

use SL::Dispatcher;

SL::Dispatcher::pre_startup();
SL::Dispatcher::handle_request('CGI');

1;
