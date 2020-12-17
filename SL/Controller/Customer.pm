package SL::Controller::Customer;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Customer;
use SL::JSON;

sub action_get_hourly_rate {
  my ($self, %params) = @_;

  my $customer;
  $customer = SL::DB::Customer->new(id => $::form->{id})->load if $::form->{id};
  my $data  = {};

  if ($customer) {
    $data = {
      hourly_rate           => $customer->hourly_rate * 1,
      hourly_rate_formatted => $::form->format_amount(\%::myconfig, $customer->hourly_rate, 2),
    };
  }

  $self->render(\to_json($data), { type => 'json' });
}

1;
