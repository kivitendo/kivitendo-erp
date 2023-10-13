package SL::Controller::EmailJournal;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::DB::Employee;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);
use SL::System::TaskServer;
use SL::Presenter::EmailJournal;

use SL::DB::Order;
use SL::DB::Order::TypeData;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData;
use SL::DB::Reclamation;
use SL::DB::Reclamation::TypeData;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;

use SL::DB::Manager::Customer;
use SL::DB::Manager::Vendor;

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(entry) ],
  'scalar --get_set_init' => [ qw(models can_view_all filter_summary) ],
);

__PACKAGE__->run_before('add_stylesheet');
__PACKAGE__->run_before('add_js');

my %RECORD_TYPES_INFO = (
  Order => {
    controller => 'Order',
    model      => 'SL::DB::Order',
    types => SL::DB::Order::TypeData->valid_types(),
  },
  DeliveryOrder => {
    controller => 'DeliveryOrder',
    model      => 'SL::DB::DeliveryOrder',
    types => SL::DB::DeliveryOrder::TypeData->valid_types(),
  },
  Reclamation => {
    controller => 'Reclamation',
    model      => 'SL::DB::Reclamation',
    types => SL::DB::Reclamation::TypeData->valid_types(),
  },
  ArTransaction => {
    controller => 'ar.pl',
    model      => 'SL::DB::Invoice',
    types => [
      'ar_transaction',
    ],
  },
  Invoice => {
    controller => 'is.pl',
    model      => 'SL::DB::Invoice',
    types => [
      'invoice',
      'invoice_for_advance_payment',
      'invoice_for_advance_payment_storno',
      'final_invoice',
      'invoice_storno',
      'credit_note',
      'credit_note_storno',
    ],
  },
  ApTransaction => {
    controller => 'ap.pl',
    model      => 'SL::DB::PurchaseInvoice',
    types => [
      'ap_transaction',
    ],
  },
  PurchaseInvoice => {
    controller => 'ir.pl',
    model      => 'SL::DB::PurchaseInvoice',
    types => [
      'purchase_invoice',
      'purchase_credit_note',
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

  # TODO: what record types can be created, which are only available in workflows?
  my @record_types_with_info = ();
  for my $record_class ('SL::DB::Order', 'SL::DB::DeliveryOrder', 'SL::DB::Reclamation') {
    my $valid_types = "${record_class}::TypeData"->valid_types();
    for my $type (@$valid_types) {

      my $type_data = SL::DB::Helper::TypeDataProxy->new($record_class, $type);
      push @record_types_with_info, {
        record_type    => $type,
        customervendor => $type_data->properties('customervendor'),
        text           => $type_data->text('type'),
      };
    }
  }
  push @record_types_with_info, (
    # invoice
    { record_type => 'ar_transaction'                    ,  customervendor => 'customer',  text => t8('AR Transaction')},
    { record_type => 'invoice'                           ,  customervendor => 'customer',  text => t8('Invoice') },
    { record_type => 'invoice_for_advance_payment'       ,  customervendor => 'customer',  text => t8('Invoice for Advance Payment')},
    { record_type => 'invoice_for_advance_payment_storno',  customervendor => 'customer',  text => t8('Storno Invoice for Advance Payment')},
    { record_type => 'final_invoice'                     ,  customervendor => 'customer',  text => t8('Final Invoice')},
    { record_type => 'invoice_storno'                    ,  customervendor => 'customer',  text => t8('Storno Invoice')},
    { record_type => 'credit_note'                       ,  customervendor => 'customer',  text => t8('Credit Note')},
    { record_type => 'credit_note_storno'                ,  customervendor => 'customer',  text => t8('Storno Credit Note')},
    # purchase invoice
    { record_type => 'ap_transaction'      ,  customervendor => 'vendor',  text => t8('AP Transaction')},
    { record_type => 'purchase_invoice'    ,  customervendor => 'vendor',  text => t8('Purchase Invoice')},
    { record_type => 'purchase_credit_note',  customervendor => 'vendor',  text => t8('Purchase Credit Note')},
  );

  my $customer_vendor = $self->find_customer_vendor_from_email($self->entry);

  $self->setup_show_action_bar;
  $self->render(
    'email_journal/show',
    title    => $::locale->text('View email'),
    CUSTOMER_VENDOR => , $customer_vendor,
    CV_TYPE_FOUND => $customer_vendor && $customer_vendor->is_vendor ? 'vendor' : 'customer',
    RECORD_TYPES_WITH_INFO => \@record_types_with_info,
    back_to  => $back_to
  );
}

sub action_attachment_preview {
  my ($self) = @_;

  eval {
    $::auth->assert('email_journal');

    my $attachment_id = $::form->{attachment_id};
    die "no 'attachment_id' was given" unless $attachment_id;

    my $attachment;
    $attachment = SL::DB::EmailJournalAttachment->new(
      id => $attachment_id,
    )->load;


    if (!$self->can_view_all
        && $attachment->email_journal->sender_id
        && ($attachment->email_journal->sender_id != SL::DB::Manager::Employee->current->id)) {
      $::form->error(t8('You do not have permission to access this entry.'));
    }

    my $output = SL::Presenter::EmailJournal::attachment_preview(
      $attachment,
      style => "height: 1800px"
    );

    $self->render( \$output, { layout => 0, process => 0,});
  } or do {
    $self->render('generic/error', { layout => 0 }, label_error => $@);
  };
}

sub action_show_attachment {
  my ($self) = @_;

  $::auth->assert('email_journal');

  my $attachment_id      = $::form->{attachment_id};
  my $attachment = SL::DB::EmailJournalAttachment->new(id => $attachment_id)->load;

  if (!$self->can_view_all && ($attachment->email_journal->sender_id != SL::DB::Manager::Employee->current->id)) {
    $::form->error(t8('You do not have permission to access this entry.'));
  }

  return $self->send_file(
    \$attachment->content,
    name => $attachment->name,
    type => $attachment->mime_type,
    content_disposition => 'inline',
  );
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
  my $email_journal_id   = $::form->{email_journal_id};
  my $attachment_id      = $::form->{attachment_id};
  my $customer_vendor    = $::form->{customer_vendor_selection};
  my $customer_vendor_id = $::form->{"${customer_vendor}_id"};
  my $action             = $::form->{action_selection};
  my $record_type        = $::form->{"${customer_vendor}_record_type_selection"};
  my $record_id          = $::form->{"${record_type}_id"};

  if ($action eq 'linking') {
    return $self->link_and_add_attachment_to_record({
        email_journal_id    => $email_journal_id,
        attachment_id       => $attachment_id,
        record_type         => $record_type,
        record_id           => $record_id,
      });
  }

  my %additional_params = ();
  if ($action eq 'create_new') {
    $additional_params{action} = 'add_from_email_journal';
    $additional_params{"${customer_vendor}_id"} = $customer_vendor_id;
  } else {
    $additional_params{action} = 'edit_with_email_journal_workflow';
    $additional_params{id} = $record_id;
  }

  $self->redirect_to(
    controller          => $RECORD_TYPE_TO_CONTROLLER{$record_type},
    type                => $record_type,
    email_journal_id    => $email_journal_id,
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
        style => "height:1800px"
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

sub link_and_add_attachment_to_record {
 my ($self, $params) = @_;

  my $email_journal_id   = $params->{email_journal_id};
  my $attachment_id      = $params->{attachment_id};
  my $record_type        = $params->{record_type};
  my $record_id          = $params->{record_id};

  my $record_type_model = $RECORD_TYPE_TO_MODEL{$record_type};
  my $record = $record_type_model->new(id => $record_id)->load;
  my $email_journal = SL::DB::EmailJournal->new(id => $email_journal_id)->load;

  if ($attachment_id) {
    my $attachment = SL::DB::EmailJournalAttachment->new(id => $attachment_id)->load;
    $attachment->add_file_to_record($record);
  }

  $email_journal->link_to_record($record);

  return $self->js->flash('info',  $::locale->text('Linked e-mail and attachment to ') . $record->displayable_name)->render();
}

sub find_customer_vendor_from_email {
  my ($self, $email_journal, $cv_type) = @_;
  my $email_address = $email_journal->from;
  $email_address =~ s/.*<(.*)>/$1/; # address can look like "name surname <email_address>"

  # Separate query otherwise cv without contacts and shipto is not found
  my $customer_vendor;
  foreach my $manager (qw(SL::DB::Manager::Customer SL::DB::Manager::Vendor)) {
    $customer_vendor ||= $manager->get_first(
      where => [
        or => [
          email => $email_address,
          cc    => $email_address,
          bcc   => $email_address,
        ],
      ],
    );
    $customer_vendor ||= $manager->get_first(
      where => [
        or => [
          'contacts.cp_email' => $email_address,
          'contacts.cp_privatemail' => $email_address,
        ],
      ],
      with_objects => [ 'contacts'],
    );
    $customer_vendor ||= $manager->get_first(
      where => [
        or => [
          'shipto.shiptoemail' => $email_address,
        ],
      ],
      with_objects => [ 'shipto' ],
    );
  }

  return $customer_vendor;
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
