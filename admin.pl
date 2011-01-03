#!/usr/bin/perl

use strict;

use SL::Dispatcher;

my $dispatcher = SL::Dispatcher->new('CGI');
$dispatcher->pre_startup;
$dispatcher->handle_request;

1;
