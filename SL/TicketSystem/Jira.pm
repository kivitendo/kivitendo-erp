package SL::TicketSystem::Jira;

use strict;
use parent qw(SL::TicketSystem::Base);

use SL::AtlassianJira;
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

sub default_sort_by {
  'priority';
}

sub new {
  my ($type, %params) = @_;
  my $self            = bless {}, $type;
  $self;
}

sub get_tickets {
  my ($self, $params, $message_ref) = @_;

  $params->{sort_by}        ||= 'priority';
  $params->{sort_dir}       //= 0;
  $params->{include_closed} //= 1;

  my $q_ord = $params->{sort_by};
  my $q_dir = $params->{sort_dir} ? 'ASC' : 'DESC';
  my $q_ser = $params->{search_string};

  # Security: sanitize JQL contents
  $q_ord    =~ s/[^a-z0-9]//g;
  $q_ser    =~ s/"/\\"/g;

  my $jql = 'textfields ~ "' . $q_ser . '*"';
  $jql   .= ' AND status NOT IN (resolved, closed, done, rejected)' unless ($params->{include_closed});
  $jql   .= " ORDER BY $q_ord $q_dir";

  ${$message_ref} = 'Atlassian JQL: ' . $jql;

  my $jira = SL::AtlassianJira->new();
  $jira->tickets($jql);
}


1;
