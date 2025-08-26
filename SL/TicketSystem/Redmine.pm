package SL::TicketSystem::Redmine;

use strict;
use parent qw(SL::TicketSystem::Base);

use SL::JSON;
use SL::Locale::String;
use SL::MoreCommon qw(uri_encode);
use MIME::Base64 qw(encode_base64);
use REST::Client;
use File::Slurp;


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
    { name => 'done_ratio',  text => t8('Done'),        sortable => 1},
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

  # To fetch issues for which custom field 4 contains the substring "foo" :
  # GET /issues.xml?cf_4=~foo

  my %redmine_params = (
    # cf_4      => '~' . $params->{search_string},
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

  my $client = REST::Client->new(host => $host, timeout => 10);
  $client->addHeader('Accept',        'application/json');
  $client->addHeader('Authorization', 'Basic ' . encode_base64("$user:$password", ''));

  $client;
}

sub _decode_and_status_code {
  my ($ret, $expected_http_code) = @_;

  my $code    = $ret->responseCode();
  my $content = $ret->responseContent();
  die "HTTP $code $content" unless $code == $expected_http_code;

  $content && from_json($content);
}

sub _query {
  my ($params) = @_;
  my $query = join '&', map { uri_encode($_) . '=' . uri_encode($params->{$_}) } keys %$params;
}

sub tickets {
  my ($self, %params) = @_;

  my $url = '/issues.json' . '?' . _query(\%params);
  my $ret = $self->connector->GET($url);
  my $res = _decode_and_status_code($ret, 200);

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

sub _upload_file {
  my ($self, $filename, $data) = @_;

  my $ret = $self->connector->POST('/uploads.json?filename=' . uri_encode($filename) , $data, {'Content-Type' => 'application/octet-stream'});

  my $res = _decode_and_status_code($ret, 201);

  $res->{upload}->{token};
}

sub update_create_ticket {
  my ($self, $create, %params) = @_;

#my $filedata = File::Slurp::read_file('/home/niklas/kivitendo-erp/image/kivitendo.png');
#my $token = $self->_upload_file('image.png', $filedata);

  my %data = (
    project_id  => 1,
    tracker_id  => 1,
    status_id   => 1,
    #priority_id => 1,
    subject     => 'ABC',
    description => 'GPS Tracker mit Richtantenne mit +6dB',
    #category_id
    #fixed_version_id - ID of the Target Versions (previously called 'Fixed Version' and still referred to as such in the API)
    #assigned_to_id => 1, #- ID of the user to assign the issue to (currently no mechanism to assign by name)
    #parent_issue_id - ID of the parent issue
    #custom_fields - See Custom fields
    #watcher_user_ids - Array of user ids to add as watchers (since 2.3.0)
    #is_private => 0, #- Use true or false to indicate whether the issue is private or not
    #estimated_hours => undef, #- Number of hours estimated for issue
#    uploads => [{ token => $token }],
  );

  my $body_content = encode_json({issue => \%data});

  my $issue_id = 20;

  my $ret = $create
          ? $self->connector->POST('/issues.json', $body_content, {'Content-Type' => 'application/json'})
          : $self->connector->PUT("/issues/$issue_id.json", $body_content, {'Content-Type' => 'application/json'});

  _decode_and_status_code($ret, $create ? 201 : 204);
}

1;


# use SL::TicketSystem::Redmine; my $rm = SL::TicketSystem::Redmine->new(); $rm->update_create_ticket(1);

