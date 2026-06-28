package SL::CTI;

use strict;

use String::ShellQuote;
use REST::Client;
use SL::JSON;

use SL::MoreCommon qw(uri_encode);

sub call {
  my ($class, %params) = @_;

  my $config           = $::lx_office_conf{async_events} || {};
  #my $command          = $config->{dial_command} || die $::locale->text('Dial command missing in kivitendo configuration\'s [cti] section');
  my $external_prefix  = $params{internal} ? '' : ($config->{external_prefix} // '');

  my %command_args     = (
    #phone_extension    => $::myconfig{phone_extension} || die($::locale->text('Phone extension missing in user configuration')),
    #phone_password     => $::myconfig{phone_password}  || die($::locale->text('Phone password missing in user configuration')),
    ami_channel            => $::myconfig{ami_channel}
                           || die($::locale->text('Asterisk AMI channel missing in user configuration')),
    ami_outbound_caller_id => $::myconfig{ami_outbound_caller_id}
                           || die($::locale->text('Asterisk AMI outbound caller ID missing in user configuration')),
    number             => $external_prefix . $class->sanitize_number(%params),
  );

  my $client   = REST::Client->new(host => $config->{fcgi_backend_api_location});
  $client->addHeader('Content-Type',  'application/json');
  $client->addHeader('charset',       'UTF-8'           );
  $client->addHeader('Accept',        'application/json');
  $client->addHeader('Authorization', 'Bearer ' . $config->{api_bearer_token});
  my %req      = (
    %command_args,
  );
  my $resp     = $client->POST('call', encode_json(\%req));
  die $resp->responseContent() unless (200 == $resp->responseCode());

  #foreach my $key (keys %command_args) {
  #  my $value = shell_quote($command_args{$key});
  #  $command  =~ s{<\% ${key} \%>}{$value}gx;
  #}

  #return `$command`;
}

sub call_link {
  my ($class, %params) = @_;

  my $config           = $::lx_office_conf{cti} || {};

  if ($config->{dial_command}) {
    return "controller.pl?action=CTI/call&number=" . uri_encode($class->sanitize_number(number => $params{number})) . ($params{internal} ? '&internal=1' : '');
  } else {
    return 'callto://' . uri_encode($class->sanitize_number(number => $params{number}));
  }
}

sub sanitize_number {
  my ($class, %params) = @_;

  my $config           = $::lx_office_conf{cti} || {};
  my $idp              = $config->{international_dialing_prefix} // '00';

  my $number           = $params{number} // '';
  $number              =~ s/[^0-9+]//g;                                        # delete unsupported characters
  my $countrycode      = $number =~ s/^(?: $idp | \+ ) ( \d{2} )//x ? $1 : ''; # TODO: countrycodes can have more or less than 2 digits
  $number              =~ s/^0//x if $countrycode;                             # kill non standard optional zero after global identifier
  $number              =~ s{[^0-9]+}{}g;

  return '' unless $number;

  return ($countrycode ? $idp . $countrycode : '') . $number;
}

1;
