package SL::TicketSystem::Jira;

use strict;
use parent qw(SL::TicketSystem::Base);

use SL::OAuth;
use SL::JSON;
use SL::Locale::String;
use SL::MoreCommon qw(uri_encode);
use REST::Client;


use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(connector) ],
);

my $api_host = 'https://api.atlassian.com';


sub title {
  'Atlassian Jira';
}

sub ticket_columns {
  [
    { name => 'key',      text => t8('Key'),      sortable => 1, ext_url => 'ext_url'},
    { name => 'summary',  text => t8('Summary'),  sortable => 1},
    { name => 'priority', text => t8('Priority'), sortable => 1},
    { name => 'status',   text => t8('Status'),   sortable => 1},
    { name => 'creator',  text => t8('Creator'),  sortable => 1},
    { name => 'assignee', text => t8('Assignee'), sortable => 1},
    { name => 'created',  text => t8('Created'),  sortable => 1, is_date => 1},
    { name => 'updated',  text => t8('Updated'),  sortable => 1, is_date => 1},
  ];
}

sub options_with_defaults {
  my %opts = (
    sort_by        => 'priority',
    sort_dir       => 0,
    include_closed => 1,
  );

  %opts;
}

sub new {
  my ($type, %params) = @_;
  my $self            = bless {}, $type;
  $self->connector($self->init_connector());
  $self;
}

sub get_tickets {
  my ($self, $params) = @_;

  my $q_order  = $params->{sort_by};
  my $q_dir    = $params->{sort_dir} ? 'ASC' : 'DESC';
  my $q_search = $params->{search_string};

  # Security: sanitize JQL contents
  $q_order  =~ s/[^a-z0-9]//g;
  $q_search =~ s/"/\\"/g;

  my $jql = 'textfields ~ "' . $q_search . '*"';
  $jql   .= ' AND statusCategory != Done' unless ($params->{include_closed});
  $jql   .= " ORDER BY $q_order $q_dir";

  my $message = 'Atlassian JQL: ' . $jql;

  ($self->tickets($jql), $message);
}

sub init_connector {
  my ($self) = @_;

  my $acctok = SL::OAuth::access_token_for('atlassian_jira') or die 'no access token';

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

  from_json($content);
}

sub accessible_resources {
  my ($self) = @_;

  my $ret = $self->connector->GET('/oauth/token/accessible-resources');
  my $res = _decode_and_status_code($ret);
  my @clouds = map +{ id => $_->{id}, url => $_->{url} }, @$res;
  \@clouds;
}

sub _query {
  my ($params) = @_;
  my $query = join '&', map { uri_encode($_) . '=' . uri_encode($params->{$_}) } keys %$params;
}

sub tickets {
  my ($self, $jql) = @_;

  # Performance: When cloud_id or cloud_url is not configured, an additional HTTP request is made to retrieve both.
  my $config    = $::lx_office_conf{atlassian_jira};
  my $cloud_id  = $config->{cloud_id};
  my $cloud_url = $config->{cloud_url};

  unless ($cloud_id && $cloud_url) {
    my $clouds = $self->accessible_resources();
    die 'no accessible resources for token' unless @$clouds;

    $cloud_id  = $clouds->[0]{id};
    $cloud_url = $clouds->[0]{url};
  }

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

  my $strp = DateTime::Format::Strptime->new(pattern => '%FT%T.%3N%z');

  my @tickets = map +{
    key        => $_->{key},
    ext_url    => $cloud_url . '/browse/' . $_->{key},
    summary    => $_->{fields}->{summary},
    creator    => $_->{fields}->{creator}->{displayName},
    assignee   => $_->{fields}->{assignee}->{displayName},
    priority   => $_->{fields}->{priority}->{name},
    created    => $strp->parse_datetime($_->{fields}->{created}),
    updated    => $strp->parse_datetime($_->{fields}->{updated}),
    status     => $_->{fields}->{status}->{name},
    resolution => $_->{fields}->{resolution}->{name},
  }, @$res->{issues};

  \@tickets;
}

1;
