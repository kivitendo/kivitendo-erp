package SL::Controller::Jira;

use strict;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::Controller::OAuth;
use SL::Controller::Helper::ReportGenerator;
use SL::JSON;
use SL::MoreCommon qw(uri_encode);
use REST::Client;

use parent qw(SL::Controller::Base);
__PACKAGE__->run_before('check_auth');

sub check_auth {
  $::auth->assert('config');
}

sub action_ajax_list_jira {
  my ($self, %params) = @_;

  my $cus =  SL::DB::Manager::Customer->find_by(id => $::form->{id});
  my $jql = 'textfields ~ "' . $cus->name . '*"';

  my $report   = SL::ReportGenerator->new(\%::myconfig, $::form);
  my @columns  = qw(key summary priority status creator assignee created updated);
  my @visible  = qw(key summary priority status creator assignee created updated);
  my @sortable = qw(key summary priority status creator assignee created updated);

  my $instance_base_url = '';

  my %column_defs = (
    key         => { text => $::locale->text('Key'),              sub => sub { $_[0]->{key} }, obj_link => sub { $instance_base_url . '/browse/' . $_[0]->{key} } },
    summary     => { text => $::locale->text('Summary'),          sub => sub { $_[0]->{summary} } },
    priority    => { text => $::locale->text('Priority'),         sub => sub { $_[0]->{priority} } },
    status      => { text => $::locale->text('Status'),           sub => sub { $_[0]->{status} } },
    creator     => { text => $::locale->text('Creator'),          sub => sub { $_[0]->{creator} } },
    assignee    => { text => $::locale->text('Assignee'),         sub => sub { $_[0]->{assignee} } },
    created     => { text => $::locale->text('Created'),          sub => sub { $_[0]->{created}  } },
    updated     => { text => $::locale->text('Updated'),          sub => sub { $_[0]->{updated} } },
  );

  $::form->{sort_by}  ||= 'partnumber';
  $::form->{sort_dir} //= 1;

  for my $col (@sortable) {
    $column_defs{$col}{link} = $self->url_for(
      action   => 'ajax_list_jira',
      callback => $::form->{callback},
      db       => $::form->{db},
      id       => $cus->id,
      sort_by  => $col,
      sort_dir => ($::form->{sort_by} eq $col ? 1 - $::form->{sort_dir} : $::form->{sort_dir})
    );
  }

  map { $column_defs{$_}{visible} = 1 } @visible;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 0, allow_csv_export => 0);
  $report->set_sort_indicator($::form->{sort_by}, $::form->{sort_dir});
  $report->set_export_options(@{ $params{report_generator_export_options} || [] });
  $report->set_options(
    %{ $params{report_generator_options} || {} },
    output_format        => 'HTML',
    top_info_text        => $::locale->text('Issues') . ': ' . 'Atlassian JQL: ' . $jql,
    title                => $::locale->text('Jira'),
  );

  my $sort_param = $::form->{sort_by} eq 'price'       ? 'price'             :
                   $::form->{sort_by} eq 'description' ? 'parts.description' :
                   'parts.partnumber';
  $sort_param .= ' ' . ($::form->{sort_dir} ? 'ASC' : 'DESC');

  my $jira_issues = $self->atlassian_jira_cloudid($jql);

  $self->report_generator_list_objects(report => $report, objects => $jira_issues, layout => 0, header => 0);
}



### private

sub atlassian_jira_cloudid {
  my ($self, $jql) = @_;

  my $acctok = SL::Controller::OAuth::access_token_for('atlassian_jira');
  my $client = REST::Client->new();
  $client->addHeader('Authorization', 'Bearer ' . $acctok);
  $client->addHeader('Accept', 'application/json');
  my $ret = $client->GET('https://api.atlassian.com/oauth/token/accessible-resources');
  my $response_code = $ret->responseCode();
  die "HTTP $response_code" unless $response_code eq '200';

  my $accessible_resources = from_json($ret->responseContent);
  my $cloudid = $accessible_resources->[0]{id};

  #return $cloudid;

  my $url;
  #$url = "https://api.atlassian.com/ex/jira/$cloudid/rest/api/3/project/search";
  #$ret = $client->GET($url);
  #$response_code = $ret->responseCode();
  #die "HTTP $response_code" unless $response_code eq '200';
  #return from_json($ret->responseContent);

  my $maxResults = 100;
  my $fields = "summary";
  #my $jql = 'textfields ~ "Test case*"';
  $url = "https://api.atlassian.com/ex/jira/$cloudid/rest/api/3/search/jql?jql=" . uri_encode($jql) . "&maxResults=100&fields=id%2Cassignee%2Cauthor%2Ccreator%2Csummary%2Cresolution%2Cstatus%2Cpriority%2Ccreated%2Cupdated&expand=&reconcileIssues=";
  $ret = $client->GET($url);
  $response_code = $ret->responseCode();
  die "HTTP $response_code" unless $response_code eq '200';
  my $c = from_json($ret->responseContent);

  my @a = map({{
    key        => $_->{key},
    summary    => $_->{fields}->{summary},
    creator    => $_->{fields}->{creator}->{displayName},
    assignee   => $_->{fields}->{assignee}->{displayName},
    priority   => $_->{fields}->{priority}->{name},
    created    => $_->{fields}->{created},
    updated    => $_->{fields}->{updated},
    status     => $_->{fields}->{status}->{name},
    resolution => $_->{fields}->{resolution}->{name},
  }} @{$c->{issues}});
  return \@a;
}

1;
