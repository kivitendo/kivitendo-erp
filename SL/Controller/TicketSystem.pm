package SL::Controller::TicketSystem;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::OAuthToken;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;
use SL::TicketSystem::Jira;
use SL::Controller::Helper::ReportGenerator;
use SL::Helper::Flash qw(flash_later);

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(config) ],
);

__PACKAGE__->run_before('check_auth');

my %providers = (
  jira => 'SL::TicketSystem::Jira',
);

sub check_auth {
  $::auth->assert('config');
}

sub action_ajax_list {
  my ($self) = @_;

  my $defaults      = SL::DB::Default->get();
  my $providerclass = $providers{$defaults->ticket_system_provider} or die 'unknown provider';
  my $provider      = $providerclass->new();
  my $cv_obj        = $::form->{db} eq 'customer' ? SL::DB::Manager::Customer->find_by(id => $::form->{id})
                                                  : SL::DB::Manager::Vendor->find_by(id => $::form->{id});
  my %params        = (search_string => $cv_obj->name);
  $params{$_} = $::form->{$_} for qw(include_closed sort_by sort_dir);

  my $objects = $provider->get_tickets(%params);

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
      action         => 'ajax_list',
      callback       => $::form->{callback},
      db             => $::form->{db},
      id             => $cv_obj->id,
      include_closed => $::form->{include_closed},
      sort_by        => $col,
      sort_dir       => ($::form->{sort_by} eq $col ? 1 - $::form->{sort_dir} : $::form->{sort_dir}),
    );
  }

  map { $column_defs{$_}{visible} = 1 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_sort_indicator($::form->{sort_by}, $::form->{sort_dir});
  $report->set_options(
    #%{ $params{report_generator_options} || {} },
    output_format        => 'HTML',
    title                => $::locale->text('Ticket system'),
    allow_pdf_export     => 0,
    allow_csv_export     => 0,
    raw_top_info_text    => $self->render('ticket_system/report_top', { output => 0 }, %{$::form}),
    raw_bottom_info_text => $self->render('ticket_system/report_bottom', { output => 0 })
  );


  $self->report_generator_list_objects(report => $report, objects => $objects, layout => 0, header => 0);
}


1;
