package SL::Controller::TimeRecording;

use strict;
use parent qw(SL::Controller::Base);

use DateTime;
use English qw(-no_match_vars);
use POSIX qw(strftime);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::TimeRecording;
use SL::Locale::String qw(t8);
use SL::ReportGenerator;

use Rose::Object::MakeMethods::Generic
(
# scalar                  => [ qw() ],
 'scalar --get_set_init' => [ qw(time_recording models all_time_recording_types all_employees) ],
);


# safety
__PACKAGE__->run_before('check_auth');

#
# actions
#

my %sort_columns = (
  start_time   => t8('Start'),
  end_time     => t8('End'),
  customer     => t8('Customer'),
  type         => t8('Type'),
  project      => t8('Project'),
  description  => t8('Description'),
  staff_member => t8('Mitarbeiter'),
  duration     => t8('Duration'),
);

sub action_list {
  my ($self, %params) = @_;

  $self->setup_list_action_bar;
  $self->make_filter_summary;
  $self->prepare_report;

  $self->report_generator_list_objects(report => $self->{report}, objects => $self->models->get);
}

sub action_edit {
  my ($self) = @_;

  $::request->{layout}->use_javascript("${_}.js") for qw(kivi.TimeRecording ckeditor/ckeditor ckeditor/adapters/jquery kivi.Validator);

  if ($self->time_recording->start_time) {
    $self->{start_date} = $self->time_recording->start_time->to_kivitendo;
    $self->{start_time} = $self->time_recording->start_time->to_kivitendo_time;
  }
  if ($self->time_recording->end_time) {
    $self->{end_date}   = $self->time_recording->end_time->to_kivitendo;
    $self->{end_time}   = $self->time_recording->end_time->to_kivitendo_time;
  }

  $self->setup_edit_action_bar;

  $self->render('time_recording/form',
                title  => t8('Time Recording'),
  );
}

sub action_save {
  my ($self) = @_;

  my @errors = $self->time_recording->validate;
  if (@errors) {
    $::form->error(t8('Saving the time recording entry failed: #1', join '<br>', @errors));
    return;
  }

  if ( !eval { $self->time_recording->save; 1; } ) {
    $::form->error(t8('Saving the time recording entry failed: #1', $EVAL_ERROR));
    return;
  }

  $self->redirect_to(safe_callback());
}

sub action_delete {
  my ($self) = @_;

  $self->time_recording->delete;

  $self->redirect_to(safe_callback());
}

sub init_time_recording {
  my $time_recording = ($::form->{id}) ? SL::DB::TimeRecording->new(id => $::form->{id})->load
                                       : SL::DB::TimeRecording->new(start_time => DateTime->now_local);

  my %attributes = %{ $::form->{time_recording} || {} };

  foreach my $type (qw(start end)) {
    if ($::form->{$type . '_date'}) {
      my $date = DateTime->from_kivitendo($::form->{$type . '_date'});
      $attributes{$type . '_time'} = $date->clone;
      if ($::form->{$type . '_time'}) {
        my ($hour, $min) = split ':', $::form->{$type . '_time'};
        $attributes{$type . '_time'}->set_hour($hour)  if $hour;
        $attributes{$type . '_time'}->set_minute($min) if $min;
      }
    }
  }

  $attributes{staff_member_id} = $attributes{employee_id} = SL::DB::Manager::Employee->current->id;

  $time_recording->assign_attributes(%attributes);

  return $time_recording;
}

sub init_models {
  SL::Controller::Helper::GetModels->new(
    controller     => $_[0],
    sorted         => \%sort_columns,
    disable_plugin => 'paginated',
    with_objects   => [ 'customer', 'type', 'project', 'staff_member', 'employee' ],
  );
}

sub init_all_time_recording_types {
  SL::DB::Manager::TimeRecordingType->get_all_sorted(query => [obsolete => 0]);
}

sub init_all_employees {
  SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);
}

sub check_auth {
  $::auth->assert('time_recording');
}

sub prepare_report {
  my ($self) = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns  = qw(start_time end_time customer type project description staff_member duration);

  my %column_defs = (
    start_time   => { text => t8('Start'),        sub => sub { $_[0]->start_time_as_timestamp },
                      obj_link => sub { $self->url_for(action => 'edit', 'id' => $_[0]->id, callback => $self->models->get_callback) }  },
    end_time     => { text => t8('End'),          sub => sub { $_[0]->end_time_as_timestamp },
                      obj_link => sub { $self->url_for(action => 'edit', 'id' => $_[0]->id, callback => $self->models->get_callback) }  },
    customer     => { text => t8('Customer'),     sub => sub { $_[0]->customer->displayable_name } },
    type         => { text => t8('Type'),         sub => sub { $_[0]->type && $_[0]->type->abbreviation } },
    project      => { text => t8('Project'),      sub => sub { $_[0]->project && $_[0]->project->displayable_name } },
    description  => { text => t8('Description'),  sub => sub { $_[0]->description_as_stripped_html },
                      raw_data => sub { $_[0]->description_as_restricted_html }, # raw_data only used for html(?)
                      obj_link => sub { $self->url_for(action => 'edit', 'id' => $_[0]->id, callback => $self->models->get_callback) }  },
    staff_member => { text => t8('Mitarbeiter'),  sub => sub { $_[0]->staff_member->safe_name } },
    duration     => { text => t8('Duration'),     sub => sub { $_[0]->duration_as_duration_string },
                      align => 'right'},
  );

  $report->set_options(
    controller_class      => 'TimeRecording',
    std_column_visibility => 1,
    output_format         => 'HTML',
    title                 => t8('Time Recordings'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;

  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  #$self->models->add_additional_url_params();
  $self->models->finalize;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => [keys %sort_columns]);

  $report->set_options(
    raw_top_info_text    => $self->render('time_recording/report_top',    { output => 0 }),
    raw_bottom_info_text => $self->render('time_recording/report_bottom', { output => 0 }, models => $self->models),
    attachment_basename  => t8('time_recordings') . strftime('_%Y%m%d', localtime time),
  );
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my $staff_member = $filter->{staff_member_id} ? SL::DB::Employee->new(id => $filter->{staff_member_id})->load->safe_name : '';

  my @filters = (
    [ $filter->{"start_time:date::ge"},                        t8('From Start')      ],
    [ $filter->{"start_time:date::le"},                        t8('To Start')        ],
    [ $filter->{"customer"}->{"name:substr::ilike"},           t8('Customer')        ],
    [ $filter->{"customer"}->{"customernumber:substr::ilike"}, t8('Customer Number') ],
    [ $staff_member,                                           t8('Mitarbeiter')     ],
  );

  for (@filters) {
    push @filter_strings, "$_->[1]: $_->[0]" if $_->[0];
  }

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#filter_form', { action => 'TimeRecording/list' } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Add'),
        link => $self->url_for(action => 'edit', callback => $self->models->get_callback),
      ],
    );
  }
}

sub setup_edit_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit => [ '#form', { action => 'TimeRecording/save' } ],
        checks => [ 'kivi.validate_form' ],
      ],
      action => [
        t8('Delete'),
        submit  => [ '#form', { action => 'TimeRecording/delete' } ],
        only_if => $self->time_recording->id,
      ],
      action => [
        t8('Cancel'),
        link  => $self->url_for(safe_callback()),
      ],
    );
  }
}

sub safe_callback {
  $::form->{callback} || (action => 'list')
}

1;
