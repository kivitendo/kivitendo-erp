package SL::Controller::AsyncEvent;

use strict;
use parent qw(SL::Controller::Base);

use SL::DBUtils;
use SL::DB::AsyncEvent;
use SL::DB::Employee;
use DateTime;

__PACKAGE__->run_before(sub { $::auth->assert('developer') },
                        only => [ qw(test_page) ]);

sub action_delete_msg {
  my ($self) = @_;

  my $msg_id          = conv_i($::form->{msg_id});
  my $original_event  = SL::DB::Manager::AsyncEvent->get_first(where => [ id => $msg_id ]);
  my $redaction_event = SL::DB::AsyncEvent->new(redact_msg_id => $original_event->id, user_id => $original_event->user_id, body => '');

  $redaction_event->save;
  $original_event->delete;

  $self->js->render;
}

sub action_test_page {
  my ($self) = @_;

  my $to   = $::form->{msg}{receiver_employee_id};
  my $text = $::form->{msg}{text};
  if ($to && $text) {
    my $e = SL::DB::Employee->new(id => $to)->load;
    SL::DB::AsyncEvent->new(
      user_id => $e->auth_user->id,
      body    => $text,
      subject => 'Async Events Developer Test Page',
    )->save;
  }

  $self->render('async_event/test_page',
    title            => 'Async Events Test Page',
    all_employees    => SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]),
    default_employee => SL::DB::Manager::Employee->current,
  );
}


1;
