package SL::Controller::Jira;

use strict;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::Controller::Helper::ReportGenerator;
use SL::AtlassianJira;

use parent qw(SL::Controller::Base);
__PACKAGE__->run_before('check_auth');

sub check_auth {
  $::auth->assert('config');
}

sub action_ajax_list_jira {
  my ($self, %params) = @_;

  $::form->{sort_by}  ||= 'priority';
  $::form->{sort_dir} //= 0;
  $::form->{include_closed} //= 1;

  my $cus =  SL::DB::Manager::Customer->find_by(id => $::form->{id});

  my $q_ord = $::form->{sort_by};
  my $q_dir = $::form->{sort_dir} ? 'ASC' : 'DESC';

  my $jql = 'textfields ~ "' . $cus->name . '*"';
  $jql .= ' AND status NOT IN (resolved, closed, done, rejected)' if (!$::form->{include_closed});
  $jql .= " ORDER BY $q_ord $q_dir";
  $::form->{tickets_jql} = $jql;

  my $report   = SL::ReportGenerator->new(\%::myconfig, $::form);
  my @columns  = qw(key summary priority status creator assignee created updated);

  my %column_defs = (
    key      => { text => $::locale->text('Key'),      sub => sub { $_[0]->{key} }, obj_link => sub { $_[0]->{ext_url} } },
    summary  => { text => $::locale->text('Summary'),  sub => sub { $_[0]->{summary} } },
    priority => { text => $::locale->text('Priority'), sub => sub { $_[0]->{priority} } },
    status   => { text => $::locale->text('Status'),   sub => sub { $_[0]->{status} } },
    creator  => { text => $::locale->text('Creator'),  sub => sub { $_[0]->{creator} } },
    assignee => { text => $::locale->text('Assignee'), sub => sub { $_[0]->{assignee} } },
    created  => { text => $::locale->text('Created'),  sub => sub { $_[0]->{created}->to_kivitendo } },
    updated  => { text => $::locale->text('Updated'),  sub => sub { $_[0]->{updated}->to_kivitendo } },
  );


  for my $col (@columns) {
    $column_defs{$col}{link} = $self->url_for(
      action   => 'ajax_list_jira',
      callback => $::form->{callback},
      db       => $::form->{db},
      id       => $cus->id,
      sort_by  => $col,
      sort_dir => ($::form->{sort_by} eq $col ? 1 - $::form->{sort_dir} : $::form->{sort_dir}),
      include_closed => $::form->{include_closed}
    );
  }

  map { $column_defs{$_}{visible} = 1 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(allow_pdf_export => 0, allow_csv_export => 0);
  $report->set_sort_indicator($::form->{sort_by}, $::form->{sort_dir});
  $report->set_options(
    %{ $params{report_generator_options} || {} },
    output_format        => 'HTML',
    title                => $::locale->text('Jira'),
    raw_top_info_text    => $self->render('ticket_system/report_top', { output => 0 }, %{$::form}),
    raw_bottom_info_text => $self->render('ticket_system/report_bottom', { output => 0 })
  );

  my $jira = SL::AtlassianJira->new();
  my $jira_issues = $jira->tickets($jql);

  $self->report_generator_list_objects(report => $report, objects => $jira_issues, layout => 0, header => 0);
}


1;
