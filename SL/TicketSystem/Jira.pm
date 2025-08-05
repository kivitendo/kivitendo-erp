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
  "jira";
}

sub title {
  "Atlassian Jira";
}

sub ticket_columns {
  qw(key summary priority status creator assignee created updated);
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
