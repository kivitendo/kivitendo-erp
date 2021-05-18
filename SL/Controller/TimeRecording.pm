package SL::Controller::TimeRecording;

use strict;
use parent qw(SL::Controller::Base);

use DateTime;
use English qw(-no_match_vars);
use List::Util qw(sum0);
use POSIX qw(strftime);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::Controller::Helper::ReportGenerator::ControlRow qw(make_control_row);
use SL::DB::Customer;
use SL::DB::Employee;
use SL::DB::Order;
use SL::DB::Part;
use SL::DB::Project;
use SL::DB::TimeRecording;
use SL::DB::TimeRecordingArticle;
use SL::Helper::Flash qw(flash);
use SL::Helper::Number qw(_round_number _parse_number _round_total);
use SL::Helper::UserPreferences::TimeRecording;
use SL::Locale::String qw(t8);
use SL::Presenter::Tag qw(checkbox_tag);
use SL::ReportGenerator;

use Rose::Object::MakeMethods::Generic
(
# scalar                  => [ qw() ],
 'scalar --get_set_init' => [ qw(time_recording models all_employees all_time_recording_articles all_orders can_view_all can_edit_all use_duration) ],
);


# safety
__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('check_auth_edit',     only => [ qw(edit save delete) ]);
__PACKAGE__->run_before('check_auth_edit_all', only => [ qw(mark_as_booked) ]);


my %sort_columns = (
  date         => t8('Date'),
  start_time   => t8('Start'),
  end_time     => t8('End'),
  order        => t8('Sales Order'),
  customer     => t8('Customer'),
  part         => t8('Article'),
  project      => t8('Project'),
  description  => t8('Description'),
  staff_member => t8('Mitarbeiter'),
  duration     => t8('Duration'),
  booked       => t8('Booked'),
);

#
# actions
#

sub action_list {
  my ($self, %params) = @_;

  $::form->{filter} //=  {
    staff_member_id => SL::DB::Manager::Employee->current->id,
    "date:date::ge" => DateTime->today_local->add(weeks => -2)->to_kivitendo,
  };

  $self->setup_list_action_bar;
  $self->make_filter_summary;
  $self->prepare_report;

  my $objects = $self->models->get;

  my $total   = sum0 map { _round_total($_->duration_in_hours) } @$objects;
  my $total_h = int($total);
  my $total_m = int($total * 60.0 + 0.5) % 60;
  my $total_s = sprintf('%d:%02d', $total_h, $total_m);

  push @$objects, make_control_row("separator");
  push @$objects, make_control_row("data",
                                   row => {
                                     map( { $_ => {class => 'listtotal'} } keys %{$self->{report}->{columns}} ),
                                     description => {data => t8('Total'), class => 'listtotal'},
                                     duration    => {data => $total_s,    class => 'listtotal'}
                                   });

  $self->report_generator_list_objects(report => $self->{report}, objects => $objects);
}

sub action_mark_as_booked {
  my ($self) = @_;

  if (scalar @{ $::form->{ids} }) {
    my $trs = SL::DB::Manager::TimeRecording->get_all(query => [id => $::form->{ids}]);
    $_->update_attributes(booked => 1) for @$trs;
  }

  $self->redirect_to(safe_callback());
}

sub action_edit {
  my ($self) = @_;

  $::request->{layout}->use_javascript("${_}.js") for qw(kivi.TimeRecording ckeditor/ckeditor ckeditor/adapters/jquery kivi.Validator);

  if ($self->use_duration) {
    flash('warning', t8('This entry is using start and end time. This information will be overwritten on saving.')) if !$self->time_recording->is_duration_used;
  } else {
    flash('warning', t8('This entry is using date and duration. This information will be overwritten on saving.'))  if $self->time_recording->is_duration_used;
  }

  if ($self->time_recording->start_time) {
    $self->{start_date} = $self->time_recording->start_time->to_kivitendo;
    $self->{start_time} = $self->time_recording->start_time->to_kivitendo_time;
  }
  if ($self->time_recording->end_time) {
    $self->{end_date}   = $self->time_recording->end_time->to_kivitendo;
    $self->{end_time}   = $self->time_recording->end_time->to_kivitendo_time;
  }

  my $inputs_to_disable = $self->get_inputs_to_disable;

  $self->setup_edit_action_bar;

  $self->render('time_recording/form',
                title             => t8('Time Recording'),
                inputs_to_disable => $inputs_to_disable,
  );
}

sub action_save {
  my ($self) = @_;

  if ($self->use_duration) {
    $self->time_recording->start_time(undef);
    $self->time_recording->end_time(undef);
  }

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

sub action_ajaj_get_order_info {

  my $order = SL::DB::Order->new(id => $::form->{id})->load;
  my $data  = { customer => { id    => $order->customer_id,
                              value => $order->customer->displayable_name,
                              type  => 'customer'
                },
                project => { id     =>  $order->globalproject_id,
                             value  => ($order->globalproject_id ? $order->globalproject->displayable_name : undef),
                },
  };

  $_[0]->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

sub action_ajaj_get_project_info {

  my $project = SL::DB::Project->new(id => $::form->{id})->load;

  my $data;
  if ($project->customer_id) {
    $data = { customer => { id    => $project->customer_id,
                            value => $project->customer->displayable_name,
                            type  => 'customer'
                          },
    };
  }

  $_[0]->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

sub init_time_recording {
  my ($self) = @_;

  my $is_new         = !$::form->{id};
  my $time_recording = !$is_new            ? SL::DB::TimeRecording->new(id => $::form->{id})->load
                     : $self->use_duration ? SL::DB::TimeRecording->new(date => DateTime->today_local)
                     :                       SL::DB::TimeRecording->new(start_time => DateTime->now_local);

  my %attributes = %{ $::form->{time_recording} || {} };

  if ($self->use_duration) {
    if (exists $::form->{duration_h} || exists $::form->{duration_m}) {
      $attributes{duration} = _round_number(_parse_number($::form->{duration_h}) * 60 + _parse_number($::form->{duration_m}), 0);
    }

  } else {
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
  }

  # do not overwrite staff member if you do not have the right
  delete $attributes{staff_member_id}                                     if !$_[0]->can_edit_all;
  $attributes{staff_member_id} ||= SL::DB::Manager::Employee->current->id if $is_new;

  $attributes{employee_id}       = SL::DB::Manager::Employee->current->id;

  $time_recording->assign_attributes(%attributes);

  return $time_recording;
}

sub init_can_view_all {
  $::auth->assert('time_recording_show_all', 1) || $::auth->assert('time_recording_edit_all', 1)
}

sub init_can_edit_all {
  $::auth->assert('time_recording_edit_all', 1)
}

sub init_models {
  my ($self) = @_;

  my @where;
  push @where, (staff_member_id => SL::DB::Manager::Employee->current->id) if !$self->can_view_all;

  SL::Controller::Helper::GetModels->new(
    controller     => $_[0],
    sorted         => \%sort_columns,
    disable_plugin => 'paginated',
    query          => \@where,
    with_objects   => [ 'customer', 'part', 'project', 'staff_member', 'employee', 'order' ],
  );
}

sub init_all_employees {
  SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]);
}

sub init_all_time_recording_articles {
  my $selectable_parts = SL::DB::Manager::TimeRecordingArticle->get_all_sorted(
    query        => [or => [ 'part.obsolete' => 0, 'part.obsolete' => undef ]],
    with_objects => ['part']);

  my $res              = [ map { {id => $_->part_id, description => $_->part->displayable_name} } @$selectable_parts];
  my $curr_id          = $_[0]->time_recording->part_id;

  if ($curr_id && !grep { $curr_id == $_->{id} } @$res) {
    unshift @$res, {id => $curr_id, description => $_[0]->time_recording->part->displayable_name};
  }

  return $res;
}

sub init_all_orders {
  my $orders = SL::DB::Manager::Order->get_all(query => [or             => [ closed    => 0, closed    => undef, id => $_[0]->time_recording->order_id ],
                                                         or             => [ quotation => 0, quotation => undef ],
                                                         '!customer_id' => undef]);
  return [ map { [$_->id, sprintf("%s %s", $_->number, $_->customervendor->name) ] } sort { $a->number <=> $b->number } @{$orders||[]} ];
}

sub init_use_duration {
  return SL::Helper::UserPreferences::TimeRecording->new()->get_use_duration();
}

sub check_auth {
  $::auth->assert('time_recording');
}

sub check_auth_edit {
  my ($self) = @_;

  if (!$self->can_edit_all && ($self->time_recording->staff_member_id != SL::DB::Manager::Employee->current->id)) {
    $::form->error(t8('You do not have permission to access this entry.'));
  }
}

sub check_auth_edit_all {
  my ($self) = @_;

  $::auth->assert('time_recording_edit_all');
}

sub prepare_report {
  my ($self) = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns  = qw(ids date start_time end_time order customer project part description staff_member duration booked);

  my %column_defs = (
    ids          => { raw_header_data => checkbox_tag("", id => "check_all", checkall  => "[data-checkall=1]"),
                      align           => 'center',
                      raw_data        => sub { $_[0]->booked ? '' : checkbox_tag("ids[]", value => $_[0]->id, "data-checkall" => 1) }   },
    date         => { text => t8('Date'),         sub => sub { $_[0]->date_as_date },
                      obj_link => sub { $self->url_for(action => 'edit', 'id' => $_[0]->id, callback => $self->models->get_callback) }  },
    start_time   => { text => t8('Start'),        sub => sub { $_[0]->start_time_as_timestamp },
                      obj_link => sub { $self->url_for(action => 'edit', 'id' => $_[0]->id, callback => $self->models->get_callback) }  },
    end_time     => { text => t8('End'),          sub => sub { $_[0]->end_time_as_timestamp },
                      obj_link => sub { $self->url_for(action => 'edit', 'id' => $_[0]->id, callback => $self->models->get_callback) }  },
    order        => { text => t8('Sales Order'),  sub => sub { $_[0]->order && $_[0]->order->number } },
    customer     => { text => t8('Customer'),     sub => sub { $_[0]->customer->displayable_name } },
    part         => { text => t8('Article'),      sub => sub { $_[0]->part && $_[0]->part->displayable_name } },
    project      => { text => t8('Project'),      sub => sub { $_[0]->project && $_[0]->project->full_description(sytle => 'both') } },
    description  => { text => t8('Description'),  sub => sub { $_[0]->description_as_stripped_html },
                      raw_data => sub { $_[0]->description_as_restricted_html }, # raw_data only used for html(?)
                      obj_link => sub { $self->url_for(action => 'edit', 'id' => $_[0]->id, callback => $self->models->get_callback) }  },
    staff_member => { text => t8('Mitarbeiter'),  sub => sub { $_[0]->staff_member->safe_name } },
    duration     => { text => t8('Duration'),     sub => sub { $_[0]->duration_as_duration_string },
                      align => 'right'},
    booked       => { text => t8('Booked'),       sub => sub { $_[0]->booked ? t8('Yes') : t8('No') } },
  );

  if (!$self->can_edit_all) {
    @columns = grep {'ids' ne $_} @columns;
    delete $column_defs{ids};
  }

  my $title        = t8('Time Recordings');
  $report->{title} = $title;    # for browser titlebar (title-tag)

  $report->set_options(
    controller_class      => 'TimeRecording',
    std_column_visibility => 1,
    output_format         => 'HTML',
    title                 => $title, # for heading
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;

  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->add_additional_url_params(filter => $::form->{filter});
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

  my $staff_member = $filter->{staff_member_id} ? SL::DB::Employee->new(id => $filter->{staff_member_id})->load->safe_name                         : '';
  my $project      = $filter->{project_id}      ? SL::DB::Project->new (id => $filter->{project_id})     ->load->full_description(sytle => 'both') : '';

  my @filters = (
    [ $filter->{"date:date::ge"},                              t8('From Date')       ],
    [ $filter->{"date:date::le"},                              t8('To Date')         ],
    [ $filter->{"customer"}->{"name:substr::ilike"},           t8('Customer')        ],
    [ $filter->{"customer"}->{"customernumber:substr::ilike"}, t8('Customer Number') ],
    [ $filter->{"order"}->{"ordnumber:substr::ilike"},         t8('Order Number')    ],
    [ $project,                                                t8('Project')         ],
    [ $filter->{"description:substr::ilike"},                  t8('Description')     ],
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
      combobox => [
        action => [
          t8('Actions'),
          only_if => $self->can_edit_all,
        ],
        action => [
          t8('Mark as booked'),
          submit  => [ '#form', { action => 'TimeRecording/mark_as_booked', callback => $self->models->get_callback } ],
          checks  => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
          confirm => $::locale->text('Do you really want to mark the selected entries as booked?'),
          only_if => $self->can_edit_all,
        ],
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

sub get_inputs_to_disable {
  my ($self) = @_;

  return [qw(customer project)]  if $self->time_recording->order_id;
  return [qw(customer)]          if $self->time_recording->project_id && $self->time_recording->project->customer_id;
}


1;
