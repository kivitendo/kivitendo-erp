package SL::AtlassianJira;

use strict;
use SL::Controller::OAuth;
use SL::JSON;
use SL::Request qw(flatten);
use SL::MoreCommon qw(uri_encode);
use REST::Client;


use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(connector) ],
);

my $api_host = 'https://api.atlassian.com';

sub init_connector {
  my ($self) = @_;

  my $acctok = SL::Controller::OAuth::access_token_for('atlassian_jira') or die "no access token";

  my $client = REST::Client->new(host => $api_host);
  $client->addHeader('Accept',        'application/json');
  $client->addHeader('Authorization', 'Bearer ' . $acctok);

  $client;
}

sub _decode_and_status_code {
  my ($ret) = @_;

  my $code    = $ret->responseCode();
  my $content = $ret->responseContent();
  die "HTTP $code $content" unless $code == 200;

  try {
    return from_json($content);
  } catch {
    t8('Invalid JSON format');
  }
}

sub accessible_resources {
  my ($self) = @_;

  my $ret = $self->connector->GET('/oauth/token/accessible-resources');
  my $res = _decode_and_status_code($ret);
  my @clouds = map { { id => $_->{id}, url => $_->{url} } } @{$res};
  \@clouds;
}

sub _query {
  my ($params) = @_;
  my $query = join '&', map { uri_encode($_->[0]) . '=' . uri_encode($_->[1]) } @{ flatten($params) };
}

sub tickets {
  my ($self, $jql) = @_;
  
  $jql //= 'textfields ~ "Test case*"';

  my $config = $::lx_office_conf{atlassian_jira};
  my $cloud_id = $config->{cloud_id} or die;

  my %params = (
    jql        => $jql,
    maxResults => 100,
    fields     => 'id,assignee,author,creator,summary,resolution,status,priority,created,updated',
    expand     => '',
    reconcileIssues => '',
  );
  my $url = "/ex/jira/$cloud_id/rest/api/3/search/jql" . '?' . _query(\%params);
  my $ret = $self->connector->GET($url);
  my $res = _decode_and_status_code($ret);

  my $dt = DateTime::Format::Strptime->new(pattern => '%FT%T.%3N%z');

  my @tickets = map({{
    key        => $_->{key},
    summary    => $_->{fields}->{summary},
    creator    => $_->{fields}->{creator}->{displayName},
    assignee   => $_->{fields}->{assignee}->{displayName},
    priority   => $_->{fields}->{priority}->{name},
    created    => $dt->parse_datetime($_->{fields}->{created}),
    updated    => $dt->parse_datetime($_->{fields}->{updated}),
    status     => $_->{fields}->{status}->{name},
    resolution => $_->{fields}->{resolution}->{name},
  }} @{$res->{issues}});
  \@tickets;
}
