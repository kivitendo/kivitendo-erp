package SL::Controller::BackgroundJobHistory;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::DB::BackgroundJobHistory;
use SL::Helper::Flash;
use SL::System::TaskServer;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(history) ],
  'scalar --get_set_init' => [ qw(task_server) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_stylesheet');
__PACKAGE__->run_before('check_task_server');

__PACKAGE__->make_paginated(ONLY => [ qw(list) ]);

__PACKAGE__->make_sorted(
  ONLY         => [ qw(list) ],

  package_name => 'Package name',
  run_at       => 'Run at',
  status       => 'Execution status',
  result       => 'Result',
  error        => 'Error',
);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('background_job_history/list',
                title   => $::locale->text('Background job history'),
                ENTRIES => $self->get_models);
}

sub action_show {
  my ($self) = @_;

  my $back_to = $::form->{back_to} || $self->url_for(action => 'list');

  $self->history(SL::DB::BackgroundJobHistory->new(id => $::form->{id})->load);
  $self->render('background_job_history/show',
                title   => $::locale->text('View background job execution result'),
                back_to => $back_to);
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

sub check_task_server {
  my ($self) = @_;
  flash('warning', $::locale->text('The task server does not appear to be running.')) if !$self->task_server->is_running;
}

sub add_stylesheet {
  $::form->use_stylesheet('lx-office-erp/background_jobs.css');
}

1;
