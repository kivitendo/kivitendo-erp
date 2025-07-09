package SL::Controller::BackgroundJob;

use strict;

use parent qw(SL::Controller::Base);

use SL::BackgroundJob::Base;
use SL::Controller::Helper::GetModels;
use SL::DB::BackgroundJob;
use SL::Helper::Flash;
use SL::JSON;
use SL::Locale::String;
use SL::System::TaskServer;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(task_server back_to models background_job) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('check_task_server');

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->setup_list_action_bar;
  $self->render('background_job/list',
                title           => $::locale->text('Background jobs'),
                BACKGROUND_JOBS => $self->models->get,
                MODELS          => $self->models);
}

sub action_new {
  my ($self) = @_;

  $self->background_job(SL::DB::BackgroundJob->new(cron_spec => '* * * * *',  package_name => 'Test')) unless $self->background_job;
  $self->setup_form_action_bar;
  $self->render('background_job/form',
                title       => $::locale->text('Create a new background job'),
                JOB_CLASSES => [ SL::BackgroundJob::Base->get_known_job_classes ]);
}

sub action_edit {
  my ($self) = @_;

  $self->setup_form_action_bar;
  $self->render('background_job/form',
                title       => $::locale->text('Edit background job'),
                JOB_CLASSES => [ SL::BackgroundJob::Base->get_known_job_classes ]);
}

sub action_edit_as_new {
  my ($self) = @_;

  delete $::form->{background_job}->{id};
  $self->background_job(SL::DB::BackgroundJob->new(%{ $::form->{background_job} }));
  $self->action_new;
}

sub action_show {
  my ($self) = @_;

  if ($::request->type eq 'json') {
    $self->render(\ SL::JSON::to_json($self->background_job->as_tree), { type => 'json' });
  } else {
    $self->action_edit;
  }
}

sub action_create {
  my ($self) = @_;

  $self->background_job(SL::DB::BackgroundJob->new);
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

sub action_destroy {
  my ($self) = @_;

  if (eval { $self->background_job->delete; 1; }) {
    flash_later('info',  $::locale->text('The background job has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The background job could not be destroyed.'));
  }

  $self->redirect_to($self->back_to);
}

sub action_save_and_execute {
  my ($self) = @_;

  $self->background_job(SL::DB::BackgroundJob->new) if !$self->background_job;
  return unless $self->create_or_update(1);
  $self->action_execute;
}

sub action_execute {
  my ($self) = @_;

  my $history = $self->background_job->run;
  if ($history->status eq 'success') {
    flash_later('info', $::locale->text('The background job was executed successfully.'));
  } else {
    flash_later('error', $::locale->text('There was an error executing the background job.'));
  }

  $self->redirect_to(controller => 'BackgroundJobHistory',
                     action     => 'show',
                     id         => $history->id,
                     back_to    => $self->url_for(action => 'edit', id => $self->background_job->id));
}

sub action_execute_class {
  my ($self) = @_;

  my $result;

  my $ok = eval {
    die "no class name given in parameter 'class'" if !$::form->{class} || ($::form->{class} =~ m{[^a-z0-9]}i);
    die "invalid class"                            if ! -f "SL/BackgroundJob/" . $::form->{class} . ".pm";

    my $package = "SL::BackgroundJob::" . $::form->{class};

    eval "require $package" or die $@;
    my $job = SL::DB::BackgroundJob->new(data => $::form->{data});
    $job->data(decode_json($::form->{json_data})) if $::form->{json_data};
    $result = $package->new->run($job);

    1;
  };

  my $reply = {
    status => $ok ? 'succeeded' : 'failed',
    result => $ok ? $result     : $@,
  };

  $self->render(\to_json($reply), { type => 'json' });
}

#
# filters
#

sub check_auth {
  $::auth->assert('admin');
}

#
# helpers
#

sub create_or_update {
  my $self   = shift;
  my $return = shift;
  my $is_new = !$self->background_job->id;
  my $params = delete($::form->{background_job}) || { };

  $self->background_job->assign_attributes(%{ $params });

  my @errors = $self->background_job->validate;

  if (@errors) {
    flash('error', $_) for @errors;
    $self->setup_form_action_bar;
    $self->render('background_job/form', title => $is_new ? $::locale->text('Create a new background job') : $::locale->text('Edit background job'));
    return;
  }

  $self->background_job->update_next_run_at;
  $self->background_job->save;

  flash_later('info', $is_new ? $::locale->text('The background job has been created.') : $::locale->text('The background job has been saved.'));
  return 1 if $return;

  $self->redirect_to($self->back_to);
}

sub init_background_job {
  return $::form->{id} ? SL::DB::BackgroundJob->new(id => $::form->{id})->load : undef;
}

sub init_task_server {
  return SL::System::TaskServer->new;
}

sub check_task_server {
  my ($self) = @_;
  flash('warning', $::locale->text('The task server does not appear to be running.')) if !$self->task_server->is_running;
}

sub init_back_to {
  my ($self) = @_;
  return $::form->{back_to} || $self->url_for(action => 'list');
}

sub init_models {
  SL::Controller::Helper::GetModels->new(
    controller => $_[0],
    filtered => 0,
    sorted => {
      package_name => t8('Package name'),
      description  => t8('Description'),
      type         => t8('Execution type'),
      active       => t8('Active'),
      cron_spec    => t8('Execution schedule'),
      last_run_at  => t8('Last run at'),
      next_run_at  => t8('Next run at'),
    },
    query => [
      package_name => [ SL::BackgroundJob::Base->get_known_job_classes ],
    ],
  );
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link      => $self->url_for(action => 'new'),
        accesskey => 'enter',
      ],
      link => [
        t8('Server control'),
        link => $self->url_for(controller => 'TaskServer', action => 'show'),
      ],
      link => [
        t8('Job history'),
        link => $self->url_for(controller => 'BackgroundJobHistory', action => 'list'),
      ],
    );
  }
}

sub setup_form_action_bar {
  my ($self) = @_;

  my $is_new = !$self->background_job->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => 'BackgroundJob/' . ($is_new ? 'create' : 'update') } ],
          accesskey => 'enter',
        ],
        action => [
          t8('Save and execute'),
          submit => [ '#form', { action => 'BackgroundJob/save_and_execute' } ],
        ],
        action => [
          t8('Use as new'),
          submit   => [ '#form', { action => 'BackgroundJob/edit_as_new' } ],
          disabled => $is_new ? t8('The object has not been saved yet.') : undef,
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'BackgroundJob/destroy' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => $is_new ? t8('This object has not been saved yet.') : undef,
      ],

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list'),
      ],

      link => [
        t8('Job history'),
        link     => $self->url_for(controller => 'BackgroundJobHistory', action => 'list', 'filter.package_name:substr::ilike' => $self->background_job->package_name),
        disabled => $is_new ? t8('This object has not been saved yet.') : undef,
      ],
    );
  }
}

1;
