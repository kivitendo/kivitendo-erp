package SL::Controller::BackgroundJobHistory;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::Filtered;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::DB::BackgroundJobHistory;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::System::TaskServer;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(history db_args flat_filter filter_summary) ],
  'scalar --get_set_init' => [ qw(task_server) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_stylesheet');
__PACKAGE__->run_before('check_task_server');

__PACKAGE__->make_filtered(
  MODEL             => 'BackgroundJobHistory',
  LAUNDER_TO        => 'filter'
);
__PACKAGE__->make_paginated(ONLY => [ qw(list) ]);

__PACKAGE__->make_sorted(
  ONLY         => [ qw(list) ],

  package_name => t8('Package name'),
  run_at       => t8('Run at'),
  status       => t8('Execution status'),
  result       => t8('Result'),
  error        => t8('Error'),
);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->make_filter_summary;

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
  $::request->{layout}->use_stylesheet('lx-office-erp/background_jobs.css');
}

sub make_filter_summary {
  my ($self)  = @_;

  my $filter  = $::form->{filter} || {};
  my @filters = (
    [ "package_name:substr::ilike", $::locale->text('Package name')                                ],
    [ "result:substr::ilike",       $::locale->text('Result')                                      ],
    [ "error:substr::ilike",        $::locale->text('Error')                                       ],
    [ "run_at:date::ge",            $::locale->text('Run at') . " " . $::locale->text('From Date') ],
    [ "run_at:date::le",            $::locale->text('Run at') . " " . $::locale->text('To Date')   ],
  );

  my @filter_strings = grep { $_ }
                       map  { $filter->{ $_->[0] } ? $_->[1] . ' ' . $filter->{ $_->[0] } : undef }
                       @filters;

  my %status = (
    failed   => $::locale->text('failed'),
    success  => $::locale->text('succeeded'),
  );
  push @filter_strings, $status{ $filter->{'status:eq_ignore_empty'} } if $filter->{'status:eq_ignore_empty'};

  $self->filter_summary(join(', ', @filter_strings));
}

1;
