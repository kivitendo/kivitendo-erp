package SL::Layout::Dispatcher;

use strict;

use SL::Layout::Admin;
use SL::Layout::Login;
use SL::Layout::Classic;
use SL::Layout::V3;
use SL::Layout::V4;
use SL::Layout::Javascript;

sub new {
  my ($class, %params) = @_;

  return SL::Layout::Classic->new    if $params{style} eq 'old';
  return SL::Layout::V3->new         if $params{style} eq 'v3';
  return SL::Layout::V4->new         if $params{style} eq 'v4';
  return SL::Layout::Javascript->new if $params{style} eq 'neu';
  return SL::Layout::Admin->new      if $params{style} eq 'admin';
  return SL::Layout::Login->new      if $params{style} eq 'login';
  return SL::Layout::None->new;
}

1;
