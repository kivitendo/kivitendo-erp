package SL::BackgroundJob::UpdateExchangerates::FromOpenexchangerates;

use strict;
use utf8;

use parent qw(SL::BackgroundJob::UpdateExchangerates::Base);

use LWP::Simple;
use SL::JSON;


sub update_rates {
  my ($self, $rates) = @_;

  return if !$self->options->{api_id};

  # 'https://openexchangerates.org/api/latest.json?app_id=xxx&base=EUR';
  # setting base does not work for me, so get for default base USD and calculate ...
  my $url;
  $url .= 'https://openexchangerates.org/api/latest.json?app_id=';
  $url .= $self->options->{api_id};

  my $result = get($url);
  return if !$result;
  my $result_h = decode_json($result);

  foreach my $rate (@$rates) {
    my $base_rate = $result_h->{rates}->{ $self->translate_currency_name($rate->{from}->name) };
    next if !$base_rate;

    my $target_rate = $result_h->{rates}->{ $self->translate_currency_name($rate->{to}->name) };
    next if !$target_rate;

    my $exrate = $base_rate/$target_rate;

    # buy and sell are the same, so do not differenciate
    $rate->{rate} = $exrate;
  }
}


1;


#module: FromOpenexchangerates
#options:
#  api_id: ce3e48c3f3a54c4d968530a08bb87734
