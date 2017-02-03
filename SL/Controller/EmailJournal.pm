package SL::Controller::EmailJournal;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::DB::Employee;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::System::TaskServer;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(entry) ],
  'scalar --get_set_init' => [ qw(models can_view_all filter_summary) ],
);

__PACKAGE__->run_before('add_stylesheet');

#
# actions
#

sub action_list {
  my ($self) = @_;

  $::auth->assert('email_journal');

  if ( $::instance_conf->get_email_journal == 0 ) {
    flash('info',  $::locale->text('Storing the emails in the journal is currently disabled in the client configuration.'));
  }
  $self->render('email_journal/list',
                title   => $::locale->text('Email journal'),
                ENTRIES => $self->models->get,
                MODELS  => $self->models);
}

sub action_show {
  my ($self) = @_;

  $::auth->assert('email_journal');

  my $back_to = $::form->{back_to} || $self->url_for(action => 'list');

  $self->entry(SL::DB::EmailJournal->new(id => $::form->{id})->load);

  if (!$self->can_view_all && ($self->entry->sender_id != SL::DB::Manager::Employee->current->id)) {
    $::form->error(t8('You do not have permission to access this entry.'));
  }

  $self->render('email_journal/show',
                title   => $::locale->text('View sent email'),
                back_to => $back_to);
}

sub action_download_attachment {
  my ($self) = @_;

  $::auth->assert('email_journal');

  my $attachment = SL::DB::EmailJournalAttachment->new(id => $::form->{id})->load;

  if (!$self->can_view_all && ($attachment->email_journal->sender_id != SL::DB::Manager::Employee->current->id)) {
    $::form->error(t8('You do not have permission to access this entry.'));
  }
  my $ref = \$attachment->content;
  if ( $attachment->file_id > 0 ) {
    my $file = SL::File->get(id => $attachment->file_id );
    $ref = $file->get_content if $file;
  }
  $self->send_file($ref, name => $attachment->name, type => $attachment->mime_type);
}

#
# filters
#

sub add_stylesheet {
  $::request->{layout}->use_stylesheet('email_journal.css');
}

#
# helpers
#

sub init_can_view_all { $::auth->assert('email_employee_readall', 1) }

sub init_models {
  my ($self) = @_;

  my @where;
  push @where, (sender_id => SL::DB::Manager::Employee->current->id) if !$self->can_view_all;

  SL::Controller::Helper::GetModels->new(
    controller        => $self,
    query             => \@where,
    with_objects      => [ 'sender' ],
    sorted            => {
      sender          => t8('Sender'),
      from            => t8('From'),
      recipients      => t8('Recipients'),
      subject         => t8('Subject'),
      sent_on         => t8('Sent on'),
      status          => t8('Status'),
      extended_status => t8('Extended status'),
    },
  );
}

sub init_filter_summary {
  my ($self)  = @_;

  my $filter  = $::form->{filter} || {};
  my @filters = (
    [ "from:substr::ilike",       $::locale->text('From')                                         ],
    [ "recipients:substr::ilike", $::locale->text('Recipients')                                   ],
    [ "sent_on:date::ge",         $::locale->text('Sent on') . " " . $::locale->text('From Date') ],
    [ "sent_on:date::le",         $::locale->text('Sent on') . " " . $::locale->text('To Date')   ],
  );

  my @filter_strings = grep { $_ }
                       map  { $filter->{ $_->[0] } ? $_->[1] . ' ' . $filter->{ $_->[0] } : undef }
                       @filters;

  my %status = (
    failed  => $::locale->text('failed'),
    ok      => $::locale->text('succeeded'),
  );
  push @filter_strings, $status{ $filter->{'status:eq_ignore_empty'} } if $filter->{'status:eq_ignore_empty'};

  return join ', ', @filter_strings;
}

1;
