package SL::Controller::Unit;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Unit;

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_reorder {
  my ($self) = @_;

  SL::DB::Unit->reorder_list(@{ $::form->{unit_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

1;
