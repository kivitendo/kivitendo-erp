package SL::Controller::Test;

use strict;

use parent qw(SL::Controller::Base);

use Data::Dumper;
use SL::ClientJS;

use SL::Controller::OAuth;
use REST::Client;

sub action_dump_form {
  my ($self) = @_;

  my $output = Dumper($::form);
  $self->render(\$output, { type => 'text' });
}

sub action_ckeditor_test_page {
  my ($self) = @_;

  $self->render("test/ckeditor");
}


sub action_get_google_cal_list {
  my ($self) = @_;

  my $api_host = 'https://www.googleapis.com';

  my $acctok = SL::Controller::OAuth::access_token_for('google_cal') or die "no access token";

  my $client = REST::Client->new(host => $api_host);
  $client->addHeader('Accept',        'application/json');
  $client->addHeader('Authorization', 'Bearer ' . $acctok);

  my $ret = $client->GET('/calendar/v3/users/me/calendarList');

  my $output = Dumper($ret);
  $::lxdebug->message(LXDebug->DEBUG2(), "Test: get_google_cal_list:\n" . $output);
  $self->render(\$output, { type => 'text' });
}


1;
