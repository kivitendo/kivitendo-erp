package SL::Controller::TaskServer;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String qw(t8);
use SL::System::TaskServer;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(task_server) ],
);

__PACKAGE__->run_before('check_auth');

#
# actions
#

sub action_show {
  my ($self) = @_;

  $::request->{layout}->use_stylesheet('background_jobs.css');

  flash('warning', $::locale->text('The task server does not appear to be running.')) if !$self->task_server->is_running;

  $self->setup_show_action_bar;
  $self->render('task_server/show',
                title               => $::locale->text('Task server status'),
                last_command_output => $::auth->get_session_value('TaskServer::last_command_output'));
}

sub action_start {
  my ($self) = @_;

  if ($self->task_server->is_running) {
    flash_later('error', $::locale->text('The task server is already running.'));

  } else {
    if ($self->task_server->start) {
      flash_later('info', $::locale->text('The task server was started successfully.'));
    } else {
      flash_later('error', $::locale->text('Starting the task server failed.'));
    }

    $::auth->set_session_value('TaskServer::last_command_output' => $self->task_server->last_command_output);
  }

  $self->redirect_to(action => 'show');
}

sub action_stop {
  my ($self) = @_;

  if (!$self->task_server->is_running) {
    flash_later('error', $::locale->text('The task server is not running.'));

  } else {
    if ($self->task_server->stop) {
      flash_later('info', $::locale->text('The task server was stopped successfully.'));
    } else {
      flash_later('error', $::locale->text('Stopping the task server failed. Output:'));
    }

    $::auth->set_session_value('TaskServer::last_command_output' => $self->task_server->last_command_output);
  }

  $self->redirect_to(action => 'show');
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

sub init_task_server {
  return SL::System::TaskServer->new;
}

sub setup_show_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $self->task_server->is_running ? t8('Stop (verb)') : t8('Start (verb)'),
        submit    => [ '#form' ],
        accesskey => 'enter',
      ],
      link => [
        t8('List of jobs'),
        link => $self->url_for(controller => 'BackgroundJob', action => 'list'),
      ],
      link => [
        t8('Job history'),
        link => $self->url_for(controller => 'BackgroundJobHistory', action => 'list'),
      ],
    );
  }
}

1;
