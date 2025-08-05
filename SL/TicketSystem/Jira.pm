package SL::TicketSystem::Jira;

use strict;
use parent qw(SL::TicketSystem::Base);

use SL::AtlassianJira;
use SL::DB::OAuthToken;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;
use SL::Helper::Flash qw(flash_later);

sub type {
  'jira';
}

sub title {
  'Atlassian Jira';
}

sub ticket_columns {
  [
    { name => 'key',      text => 'Key',      sortable => 1, ext_url => 'ext_url'},
    { name => 'summary',  text => 'Summary',  sortable => 1},
    { name => 'priority', text => 'Priority', sortable => 1},
    { name => 'status',   text => 'Status',   sortable => 1},
    { name => 'creator',  text => 'Creator',  sortable => 1},
    { name => 'assignee', text => 'Assignee', sortable => 1},
    { name => 'created',  text => 'Created',  sortable => 1},
    { name => 'updated',  text => 'Updated',  sortable => 1},
  ];
}

sub default_sort_by {
  'priority';
}

sub new {
  my ($type, %params) = @_;
  my $self            = bless {}, $type;
#  my ($self) = @_;
#  my $jira = SL::AtlassianJira->new();
#  $self->{jira} = $jira;
  $self;
}

sub get_tickets {
  my ($self, %params) = @_;

  $params{sort_by}        ||= 'priority';
  $params{sort_dir}       //= 0;
  $params{include_closed} //= 1;

  my $q_ord = $params{sort_by};
  my $q_dir = $params{sort_dir} ? 'ASC' : 'DESC';

  my $jql = 'textfields ~ "' . $params{search_string} . '*"';
  $jql .= ' AND status NOT IN (resolved, closed, done, rejected)' unless ($params{include_closed});
  $jql .= " ORDER BY $q_ord $q_dir";
  #$::form->{tickets_jql} = $jql;

  my $jira = SL::AtlassianJira->new();
  my $jira_issues = $jira->tickets($jql);

  $jira_issues;
}


1;
