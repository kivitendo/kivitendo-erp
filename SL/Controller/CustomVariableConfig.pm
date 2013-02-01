package SL::Controller::CustomVariableConfig;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::CustomVariableConfig;

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_reorder {
  my ($self) = @_;

  SL::DB::CustomVariableConfig->reorder_list(@{ $::form->{cvarcfg_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

1;
