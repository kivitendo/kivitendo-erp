package SL::Controller::DebugMenu;

use strict;
use parent qw(SL::Controller::Base);

# safety
__PACKAGE__->run_before(sub { die 'not allowed in config' unless $::lx_office_conf{debug}{show_debug_menu}; });

sub action_reload {
  my ($self, %params) = @_;

  print $::cgi->redirect('kopf.pl');
  exit;
}

sub action_toggle {
  my ($self, %params) = @_;

  $::lxdebug->level_by_name($::form->{level}, !$::lxdebug->level_by_name($::form->{level}));
  print $::cgi->redirect('kopf.pl');
  return;
}

1;
