package SL::Controller::PriceFactor;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::PriceFactor;

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_reorder {
  my ($self) = @_;

  SL::DB::PriceFactor->reorder_list(@{ $::form->{price_factor_id} || [] });

  $self->render(\'', { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('config');
}

1;
