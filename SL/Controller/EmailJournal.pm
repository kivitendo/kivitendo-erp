package SL::Controller::EmailJournal;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::DB::Employee;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::DB::Order;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::System::TaskServer;
use SL::Presenter::EmailJournal;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(entry) ],
  'scalar --get_set_init' => [ qw(models can_view_all filter_summary) ],
);

__PACKAGE__->run_before('add_stylesheet');
__PACKAGE__->run_before('add_js');

my %RECORD_TYPES_INFO = (
  # Order
  Order => {
    controller => 'Order',
    model      => 'SL::DB::Order',
    types => [
      'purchase_order',
      'purchase_quotation_intake',
      'request_quotation',
      'sales_order',
      'sales_order_intake',
      'sales_quotation',
    ],
  },
);
my %RECORD_TYPE_TO_CONTROLLER =
  map {
    my $controller = $RECORD_TYPES_INFO{$_}->{controller};
    map { $_ => $controller } @{ $RECORD_TYPES_INFO{$_}->{types} }
  } keys %RECORD_TYPES_INFO;
my %RECORD_TYPE_TO_MODEL =
  map {
    my $model = $RECORD_TYPES_INFO{$_}->{model};
    map { $_ => $model } @{ $RECORD_TYPES_INFO{$_}->{types} }
  } keys %RECORD_TYPES_INFO;

#
# actions
#

sub action_list {
  my ($self) = @_;

  $::auth->assert('email_journal');

  if ( $::instance_conf->get_email_journal == 0 ) {
    flash('info',  $::locale->text('Storing the emails in the journal is currently disabled in the client configuration.'));
  }
  $self->setup_list_action_bar;
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

  $self->setup_show_action_bar;
  $self->render('email_journal/show',
                title   => $::locale->text('View email'),
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

sub action_apply_record_action {
  my ($self) = @_;
  my $email_journal_id = $::form->{email_journal_id};
  my $attachment_id = $::form->{attachment_id};
  my $record_action = $::form->{record_action};
  my $vendor_id = $::form->{vendor_id};
  my $customer_id = $::form->{customer_id};

  if ( $record_action =~ s/^link_// ) { # remove prefix

    # Load record
    my $record_type = $record_action;
    my $record_id = $::form->{$record_type . "_id"};
    my $record_type_model = $RECORD_TYPE_TO_MODEL{$record_type};
    my $record = $record_type_model->new(id => $record_id)->load;
    my $email_journal = SL::DB::EmailJournal->new(id => $email_journal_id)->load;

    if ($attachment_id) {
      my $attachment = SL::DB::EmailJournalAttachment->new(id => $attachment_id)->load;
      $attachment->add_file_to_record($record);
    }

    $email_journal->link_to_record($record);

    return $self->js->flash('info',  $::locale->text('Linked to e-mail ') . $record->displayable_name)->render();
  }

  my %additional_params = ();
  if ( $record_action =~ s/^customer_// ) {  # remove prefix
    $additional_params{customer_id} = $customer_id;
  } elsif ( $record_action =~ s/^vendor_// ) { # remove prefix
    $additional_params{vendor_id} = $vendor_id;
  }
  $additional_params{type} = $record_action;
  $additional_params{controller} = $RECORD_TYPE_TO_CONTROLLER{$record_action};

  $self->redirect_to(
    action              => 'add_from_email_journal',
    from_id             => $email_journal_id,
    from_type           => 'email_journal',
    email_attachment_id => $attachment_id,
    %additional_params,
  );
}

sub action_update_attachment_preview {
  my ($self) = @_;
  $::auth->assert('email_journal');
  my $attachment_id = $::form->{attachment_id};

  my $attachment;
  $attachment = SL::DB::EmailJournalAttachment->new(
    id => $attachment_id,
  )->load if $attachment_id;

  $self->js
    ->replaceWith('#attachment_preview',
      SL::Presenter::EmailJournal::attachment_preview(
        $attachment,
        style => "width:655px;border:1px solid black;margin:9px"
      )
    )
    ->render();
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

sub find_cv_from_email {
  my ($self, $cv_type, $email_journal) = @_;
  my $email_address = $email_journal->from;

  # search for customer or vendor or both
  my $customer;
  my $vendor;
  if ($cv_type ne 'vendor') {
    $customer = SL::DB::Manager::Customer->get_first(
      where => [
        or => [
          email => $email_address,
          cc    => $email_address,
          bcc   => $email_address,
          'contacts.cp_email' => $email_address,
          'contacts.cp_privatemail' => $email_address,
          'shipto.shiptoemail' => $email_address,
        ],
      ],
      with_objects => [ 'contacts', 'shipto' ],
    );
  } elsif ($cv_type ne 'customer') {
    $vendor = SL::DB::Manager::Vendor->get_first(
      where => [
        or => [
          email => $email_address,
          cc    => $email_address,
          bcc   => $email_address,
          'contacts.cp_email' => $email_address,
          'contacts.cp_privatemail' => $email_address,
          'shipto.shiptoemail' => $email_address,
        ],
      ],
      with_objects => [ 'contacts', 'shipto' ],
    );
  }

  return $customer || $vendor;
}

sub find_customer_from_email {
  my ($self, $email_journal) = @_;
  my $email_address = $email_journal->from;

  my $customer = SL::DB::Manager::Customer->get_first(
    where => [
      or => [
        email => $email_address,
        cc    => $email_address,
        bcc   => $email_address,
        'contacts.cp_email' => $email_address,
        'contacts.cp_privatemail' => $email_address,
        'shipto.shiptoemail' => $email_address,
      ],
    ],
    with_objects => [ 'contacts', 'shipto' ],
  );

  return $customer;
}

sub add_js {
  $::request->{layout}->use_javascript("${_}.js") for qw(
    kivi.EmailJournal
    );
}

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
    send_failed => $::locale->text('send failed'),
    sent        => $::locale->text('sent'),
    imported    => $::locale->text('imported'),
  );
  push @filter_strings, $status{ $filter->{'status:eq_ignore_empty'} } if $filter->{'status:eq_ignore_empty'};

  return join ', ', @filter_strings;
}

sub setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Filter'),
        submit    => [ '#filter_form', { action => 'EmailJournal/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_show_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

1;
