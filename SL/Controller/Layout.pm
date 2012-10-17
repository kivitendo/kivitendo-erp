package SL::Controller::Layout;

use strict;
use parent qw(SL::Controller::Base);

use SL::Menu;
use SL::Controller::Layout::Classic;
use SL::Controller::Layout::V3;
use SL::Controller::Layout::V4;
use SL::Controller::Layout::Javascript;

my %menu_cache;

sub new {
  my ($class, %params) = @_;

  return SL::Controller::Layout::Classic->new    if $params{style} eq 'old';
  return SL::Controller::Layout::V3->new         if $params{style} eq 'v3';
  return SL::Controller::Layout::V4->new         if $params{style} eq 'v4';
  return SL::Controller::Layout::Javascript->new if $params{style} eq 'neu';
  return SL::Controller::Layout::None->new;
}

1;
