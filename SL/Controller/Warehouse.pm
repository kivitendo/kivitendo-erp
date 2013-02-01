package SL::Controller::Warehouse;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Warehouse;

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_reorder {
  my ($self) = @_;

  SL::DB::Warehouse->reorder_list(@{ $::form->{warehouse_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

1;
