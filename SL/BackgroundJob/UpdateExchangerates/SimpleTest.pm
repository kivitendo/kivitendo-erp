package SL::BackgroundJob::UpdateExchangerates::SimpleTest;

use strict;
use utf8;

use parent qw(SL::BackgroundJob::UpdateExchangerates::Base);


sub update_rates {
  my ($self, $rates) = @_;

  foreach my $rate (@$rates) {
    my $from = $self->translate_currency_name($rate->{from}->name);
    my $to   = $self->translate_currency_name($rate->{to}->name);
    if ( $from eq 'EUR' && $to eq 'USD') {
      $rate->{rate} = 0.9205 if $rate->{dir} eq 'buy';
      $rate->{rate} = 0.9202 if $rate->{dir} eq 'sell';
    }
  }
}

1;
