#!/usr/bin/perl

use strict;

use SL::Dispatcher;

our $dispatcher = SL::Dispatcher->new('CGI');
$dispatcher->pre_startup;
$dispatcher->handle_request;

1;
