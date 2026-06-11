package SL::Controller::AsyncEvent;

use strict;
use parent qw(SL::Controller::Base);

use SL::DBUtils;
use SL::DB::AsyncEvent;
use SL::DB::Employee;
use DateTime;


sub action_poll_events {
  my ($self) = @_;

  my $seqno_min          = conv_i($::form->{seqno});
  my $max_poll_seconds   = 20;
  my $poll_interval_ms   = 100;
  my $user_id            = SL::DB::Manager::Employee->current->auth_user->id;

  my $query  = qq|SELECT *, extract(epoch from itime) as timestamp FROM get_async_event_poll(?, ?, ?, ?);|;
  my $events = selectall_hashref_query($::form, SL::DB->client->dbh, $query, $seqno_min, $user_id, $max_poll_seconds, $poll_interval_ms);

  foreach my $e (@$events) {
    $e->{ts_fmt} = DateTime->from_epoch(epoch => $e->{timestamp})
                           ->to_kivitendo(precision => 'minute') if $e->{timestamp};
  }

  my %ret = (
    next_seqno         => @$events ? ($events->[-1]{id} + 1) : $seqno_min,
    events             => [ grep { !defined $_->{redact_msg_id} } @$events ],
    redacted_event_ids => [ map { $_->{redact_msg_id} } grep { $_->{redact_msg_id} } @$events ],
  );

  $self->render(\ SL::JSON::to_json(\%ret), { layout => 0, type => 'json', process => 0 });
}

sub action_delete_msg {
  my ($self) = @_;

  my $msg_id          = conv_i($::form->{msg_id});
  my $original_event  = SL::DB::Manager::AsyncEvent->get_first(where => [ id => $msg_id ]);
  my $redaction_event = SL::DB::AsyncEvent->new(redact_msg_id => $original_event->id, user_id => $original_event->user_id, body => '');

  $redaction_event->save;
  $original_event->delete;

  $self->js->render;
}


1;
