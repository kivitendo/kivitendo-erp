package SL::TicketSystem::Redmine;

use strict;
use parent qw(SL::TicketSystem::Base);

use SL::OAuth;
use SL::JSON;
use SL::Locale::String;
use SL::MoreCommon qw(uri_encode);
use MIME::Base64 qw(encode_base64);
use REST::Client;


use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(connector) ],
);

sub title {
  'Redmine';
}

sub ticket_columns {
  [
    { name => 'id',          text =>    'ID',           sortable => 1, ext_url => 'ext_url'},
    { name => 'subject',     text => t8('Subject'),     sortable => 1},
    { name => 'description', text => t8('Description'), sortable => 1},
    { name => 'priority',    text => t8('Priority'),    sortable => 1},
    { name => 'status',      text => t8('Status'),      sortable => 1},
    { name => 'author',      text => t8('Author'),      sortable => 1},
    { name => 'assigned_to', text => t8('Assignee'),    sortable => 1},
    { name => 'created_on',  text => t8('Created'),     sortable => 1, is_date => 1},
    { name => 'updated_on',  text => t8('Updated'),     sortable => 1, is_date => 1},
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

  my %redmine_params = (
    status_id => $params->{include_closed} ? '*' : 'open',
    sort      => $params->{sort_by} . ($params->{sort_dir} ? '' : ':desc'),
  );
  my $message = 'Redmine: ' . join ' ', map { $_ . '=' . $redmine_params{$_} } sort keys %redmine_params;

  ($self->tickets(%redmine_params), $message);
}

sub init_connector {
  my ($self) = @_;

  my $config   = $::lx_office_conf{redmine};
  my $host     = $config->{host};
  my $user     = $config->{user};
  my $password = $config->{password};

  my $client = REST::Client->new(host => $host);
  $client->addHeader('Accept',        'application/json');
  $client->addHeader('Authorization', 'Basic ' . encode_base64("$user:$password", ''));

  $client;
}

sub _decode_and_status_code {
  my ($ret) = @_;

  my $code    = $ret->responseCode();
  my $content = $ret->responseContent();
  die "HTTP $code $content" unless $code == 200;

  from_json($content);
}

sub _query {
  my ($params) = @_;
  my $query = join '&', map { uri_encode($_) . '=' . uri_encode($params->{$_}) } keys %$params;
}

sub tickets {
  my ($self, %params) = @_;

  my $url = '/issues.json' . '?' . _query(\%params);
  my $ret = $self->connector->GET($url);
  my $res = _decode_and_status_code($ret);

  my $strp = DateTime::Format::Strptime->new(pattern => '%FT%T%z');

  my $issues = $res->{issues};
  my @tickets = map +{
    id          => '#' . $_->{id},
    ext_url     => 'http://localhost:3000/issues/' . $_->{id},
    subject     => $_->{subject},
    description => $_->{description},
    author      => $_->{author}->{name},
    assigned_to => $_->{assigned_to}->{name},
    priority    => $_->{priority}->{name},
    created_on  => $strp->parse_datetime($_->{created_on}),
    updated_on  => $strp->parse_datetime($_->{updated_on}),
    status      => $_->{status}->{name},
    done_ratio  => $_->{done_ratio},
  }, @$issues;

  \@tickets;
}

1;
