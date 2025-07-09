package SL::Controller::EmailJournal;

use strict;

use parent qw(SL::Controller::Base);

use SL::ZUGFeRD;
use SL::Controller::ZUGFeRD;
use SL::Controller::Helper::GetModels;
use SL::DB::Employee;
use SL::DB::EmailJournal;
use SL::DB::EmailJournalAttachment;
use SL::Presenter::EmailJournal;
use SL::Presenter::Record qw(grouped_record_list);
use SL::Presenter::Tag qw(html_tag div_tag button_tag);
use SL::Helper::Flash;
use SL::Locale::String qw(t8);

use SL::DB::Order;
use SL::DB::Order::TypeData;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData;
use SL::DB::Reclamation;
use SL::DB::Reclamation::TypeData;
use SL::DB::Invoice;
use SL::DB::Invoice::TypeData;
use SL::DB::PurchaseInvoice;
use SL::DB::PurchaseInvoice::TypeData;

use SL::DB::Manager::Customer;
use SL::DB::Manager::Vendor;

use List::Util qw(first);
use List::MoreUtils qw(any);

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
    class      => 'Order',
    types => SL::DB::Order::TypeData->valid_types(),
  },
  DeliveryOrder => {
    controller => 'DeliveryOrder',
    class      => 'DeliveryOrder',
    types => SL::DB::DeliveryOrder::TypeData->valid_types(),
  },
  Reclamation => {
    controller => 'Reclamation',
    class      => 'Reclamation',
    types => SL::DB::Reclamation::TypeData->valid_types(),
  },
  GlTransaction => {
    controller => 'gl.pl',
    class      => 'GLTransaction',
    types => [
      'gl_transaction',
    ],
  },
  ArTransaction => {
    controller => 'ar.pl',
    class      => 'Invoice',
    types => [
      'ar_transaction',
    ],
  },
  Invoice => {
    controller => 'is.pl',
    class      => 'Invoice',
    types => SL::DB::Invoice::TypeData->valid_types(),
  },
  ApTransaction => {
    controller => 'ap.pl',
    class      => 'PurchaseInvoice',
    types => [
      'ap_transaction',
    ],
  },
  PurchaseInvoice => {
    controller => 'ir.pl',
    class      => 'PurchaseInvoice',
    types => SL::DB::PurchaseInvoice::TypeData->valid_types(),
  },
  GlRecordTemplate => {
    controller => 'gl.pl',
    class      => 'RecordTemplate',
    types => [
      'gl_transaction_template',
    ],
  },
  ArRecordTemplate => {
    controller => 'ar.pl',
    class      => 'RecordTemplate',
    types => [
      'ar_transaction_template',
    ],
  },
  ApRecordTemplate => {
    controller => 'ap.pl',
    class      => 'RecordTemplate',
    types => [
      'ap_transaction_template',
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
    my $class = $RECORD_TYPES_INFO{$_}->{class};
    map { $_ => "SL::DB::$class" } @{ $RECORD_TYPES_INFO{$_}->{types} }
  } keys %RECORD_TYPES_INFO;
my %RECORD_TYPE_TO_MANAGER =
  map {
    my $class = $RECORD_TYPES_INFO{$_}->{class};
    map { $_ => "SL::DB::Manager::$class" } @{ $RECORD_TYPES_INFO{$_}->{types} }
  } keys %RECORD_TYPES_INFO;
my @ALL_RECORD_TYPES =
  map { @{ $RECORD_TYPES_INFO{$_}->{types} } } keys %RECORD_TYPES_INFO;
my %RECORD_TYPE_TO_NR_KEY =
  map {
    my $model = $RECORD_TYPE_TO_MODEL{$_};
    if (any {$model eq $_} qw(SL::DB::Invoice SL::DB::PurchaseInvoice)) {
      $_ => 'invnumber';
    } elsif (any {$model eq $_} qw(SL::DB::RecordTemplate)) {
      $_ => 'template_name';
    } elsif (any {$model eq $_} qw(SL::DB::GLTransaction)) {
      $_ => 'reference';
    } else {
      my $type_data = SL::DB::Helper::TypeDataProxy->new($model, $_);
      $_ => $type_data->properties('nr_key');
    }
  } @ALL_RECORD_TYPES;

# has do be done at runtime for translation to work
sub get_record_types_with_info {
  my @record_types_with_info = ();
  for my $record_class (
      'SL::DB::Order', 'SL::DB::DeliveryOrder', 'SL::DB::Reclamation',
      'SL::DB::Invoice', 'SL::DB::PurchaseInvoice',
    ) {
    my $type_data = "${record_class}::TypeData";
    my $valid_types = $type_data->valid_types();
    for my $type (@$valid_types) {
      push @record_types_with_info, {
        record_type     => $type,
        text            => $type_data->can('get3')->($type, 'text', 'type'),
        customervendor  => $type_data->can('get3')->($type, 'properties', 'customervendor'),
        workflow_needed => $type_data->can('get3')->($type, 'properties', 'worflow_needed'),
        can_workflow    => (
          any {
            $_ ne 'delete' && $type_data->can('get3')->($type, 'show_menu', $_)
          } keys %{$type_data->can('get')->($type, 'show_menu')}
        ),
      };
    }
  }
  push @record_types_with_info, (
    # transactions
    # gl_transaction can be for vendor and customer
    { record_type => 'gl_transaction', customervendor => 'customer', workflow_needed => 0, can_workflow => 1, text => t8('GL Transaction')},
    { record_type => 'gl_transaction', customervendor => 'vendor',   workflow_needed => 0, can_workflow => 1, text => t8('GL Transaction')},
    { record_type => 'ar_transaction', customervendor => 'customer', workflow_needed => 0, can_workflow => 1, text => t8('AR Transaction')},
    { record_type => 'ap_transaction', customervendor => 'vendor',   workflow_needed => 0, can_workflow => 1, text => t8('AP Transaction')},
    # templates
    { record_type => 'gl_transaction_template', is_template => 1, customervendor => 'customer', workflow_needed => 0, can_workflow => 0, text => t8('GL Transaction')},
    { record_type => 'gl_transaction_template', is_template => 1, customervendor => 'vendor',   workflow_needed => 0, can_workflow => 0, text => t8('GL Transaction')},
    { record_type => 'ar_transaction_template', is_template => 1, customervendor => 'customer', workflow_needed => 0, can_workflow => 0, text => t8('AR Transaction')},
    { record_type => 'ap_transaction_template', is_template => 1, customervendor => 'vendor',   workflow_needed => 0, can_workflow => 0, text => t8('AP Transaction')},
  );
  return @record_types_with_info;
}

# has do be done at runtime for translation to work
sub get_record_types_to_text {
  my @record_types_with_info = get_record_types_with_info();

  my %record_types_to_text = ();
  $record_types_to_text{$_->{record_type}} = $_->{text} for @record_types_with_info;
  $record_types_to_text{'catch_all'} = t8("Catch-all");

  return %record_types_to_text;
}

sub record_types_for_customer_vendor_type_and_action {
  my ($self, $customer_vendor_type, $action) = @_;
  return [
    map { $_->{record_type} }
    grep {
      # No gl_transaction in standard workflows
      # They can't be filtered by customer/vendor or open/closed and polute the list
      ($_->{record_type} ne 'gl_transaction')
    }
    grep {
      ($_->{customervendor} eq $customer_vendor_type)
      && ($action eq 'workflow_record' ? $_->{can_workflow} : 1)
      && ($action eq 'create_new'      ? $_->{workflow_needed} : 1)
      && ($action eq 'linking_record'  ? !$_->{is_template} : 1)
      && ($action eq 'template_record' ? $_->{is_template} : 1)
    }
    $self->get_record_types_with_info()
  ];
}

#
# actions
#

sub action_list {
  my ($self) = @_;

  $::auth->assert('email_journal');
  # default filter
  $::form->{filter} ||= {"obsolete:eq_ignore_empty" => 0};

  if ( $::instance_conf->get_email_journal == 0 ) {
    flash('info',  $::locale->text('Storing the emails in the journal is currently disabled in the client configuration.'));
  }
  $self->setup_list_action_bar;
  my @record_types_with_info = $self->get_record_types_with_info();
  my %record_types_to_text   = $self->get_record_types_to_text();
  $self->render('email_journal/list',
                title   => $::locale->text('Email journal'),
                ENTRIES => $self->models->get,
                MODELS  => $self->models,
                RECORD_TYPES_WITH_INFO => \@record_types_with_info,
                RECORD_TYPES_TO_TEXT   => \%record_types_to_text,
              );
}

sub action_show {
  my ($self) = @_;

  $::auth->assert('email_journal');

  my $back_to = $::form->{back_to} || $self->url_for(action => 'list');

  $self->entry(SL::DB::EmailJournal->new(id => $::form->{id})->load);

  if (!$self->can_view_all && ($self->entry->sender_id != SL::DB::Manager::Employee->current->id)) {
    $::form->error(t8('You do not have permission to access this entry.'));
  }

  my @record_types_with_info = $self->get_record_types_with_info();
  my %record_types_to_text   = $self->get_record_types_to_text();

  my $customer = $self->find_customer_vendor_from_email('customer', $self->entry);
  my $vendor   = $self->find_customer_vendor_from_email('vendor'  , $self->entry);

  my $record_type_info =
    first {$_->{record_type} eq $self->entry->record_type}
    @record_types_with_info;
  my $cv_type_found = $record_type_info ? $record_type_info->{customervendor}
                    : defined $vendor   ? 'vendor'
                    : 'customer';

  my $record_types = $self->record_types_for_customer_vendor_type_and_action(
    $cv_type_found, 'workflow_record'
  );

  $self->setup_show_action_bar;
  $self->render(
    'email_journal/show',
    title                  => $::locale->text('View email'),
    CUSTOMER               => $customer,
    VENDOR                 => $vendor,
    CV_TYPE_FOUND          => $cv_type_found,
    RECORD_TYPES_WITH_INFO => \@record_types_with_info,
    RECORD_TYPES_TO_TEXT   => \%record_types_to_text,
    back_to  => $back_to,
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
  # hot hot fix don't offer some random version of this file if we have a real saved state in the email journal
  if (!$ref && $attachment->file_id > 0 ) {
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
  my $record_id          = $::form->{"record_id"};
  my $record_type        = $::form->{"record_type"};
     $record_type      ||= $::form->{"${customer_vendor}_${action}_type_selection"};

  die t8("No record is selected.")               unless $record_id || $action eq 'new_record';
  die t8("No record type is selected.")          unless $record_type;
  die "no 'email_journal_id' was given"          unless $email_journal_id;
  die "no 'customer_vendor_selection' was given" unless $customer_vendor;
  die "no 'action_selection' was given"          unless $action;

  if ($action eq 'linking_record') {
    return $self->link_and_add_attachment_to_record({
        email_journal_id => $email_journal_id,
        attachment_id    => $attachment_id,
        record_type      => $record_type,
        record_id        => $record_id,
      });
  }

  my %additional_params = ();
  if ($action eq 'new_record') {
    $additional_params{action} = 'add_from_email_journal';
    $additional_params{"${customer_vendor}_id"} = $customer_vendor_id;
  } elsif ($action eq 'template_record') {
    $additional_params{action} = 'load_record_template_from_email_journal';
    $additional_params{id} = $record_id;
    $additional_params{form_defaults} = {
      email_journal_id    => $email_journal_id,
      email_attachment_id => $attachment_id,
      callback            => $::form->{back_to},
    };
  } else { # workflow_record
    $additional_params{action} = 'edit_with_email_journal_workflow';
    $additional_params{id} = $record_id;
  }

  $self->redirect_to(
    controller          => $RECORD_TYPE_TO_CONTROLLER{$record_type},
    type                => $record_type,
    email_journal_id    => $email_journal_id,
    email_attachment_id => $attachment_id,
    callback            => $::form->{back_to},
    %additional_params,
  );
}

sub action_ap_transaction_template_with_zugferd_import {
  my ($self) = @_;
  my $email_journal_id = $::form->{email_journal_id};
  die "no 'email_journal_id' was given" unless $email_journal_id;

  my $record_id   = $::form->{"record_id"};
  my $record_type = $::form->{"record_type"};
  die "ZUGFeRD-Import only implemented for ap transaction templates" unless $record_type == 'ap_transaction';

  my $attachment_id = $::form->{attachment_id};

  my $form_defaults;
  if ($attachment_id) {
    my $attachment = SL::DB::EmailJournalAttachment->new(id => $attachment_id)->load();
    my $content = $attachment->content; # scalar ref

    if ($content =~ m/^%PDF|<\?xml/) {

      my %res;
      if ( $content =~ m/^%PDF/ ) {
        %res = %{SL::ZUGFeRD->extract_from_pdf($content)};
      } else {
        %res = %{SL::ZUGFeRD->extract_from_xml($content)};
      }

      if ($res{'result'} == SL::ZUGFeRD::RES_OK()) {
        my $ap_template = SL::DB::RecordTemplate->new(id => $record_id)->load();
        my $vendor = $ap_template->vendor;

        $form_defaults = SL::Controller::ZUGFeRD->build_ap_transaction_form_defaults(\%res, vendor => $vendor);
        flash_later('info',
          t8("The ZUGFeRD/Factur-X invoice '#1' has been loaded.", $attachment->name));
      }
    }
  }

  $form_defaults->{email_journal_id}    = $email_journal_id;
  $form_defaults->{email_attachment_id} = $attachment_id;
  $form_defaults->{callback}            = $::form->{back_to};

  $self->redirect_to(
    controller         => 'ap.pl',
    action             => 'load_zugferd',
    record_template_id => $record_id,
    form_defaults      => $form_defaults,
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

sub action_update_record_list {
  my ($self) = @_;
  $::auth->assert('email_journal');
  my $customer_vendor_type = $::form->{customer_vendor_selection};
  my $customer_vendor_id   = $::form->{"${customer_vendor_type}_id"};
  my $action               = $::form->{action_selection};
  my $record_type          = $::form->{"${customer_vendor_type}_${action}_type_selection"};
  my $record_number        = $::form->{record_number};
  my $with_closed          = $::form->{with_closed};

  $record_type ||= $self->record_types_for_customer_vendor_type_and_action($customer_vendor_type, $action);

  my @records = $self->get_records_for_types(
    $record_type,
    customer_vendor_type => $customer_vendor_type,
    customer_vendor_id   => $customer_vendor_id,
    record_number        => $record_number,
    with_closed          => $with_closed,
  );

  my $new_div = $self->get_records_div(\@records);

  $self->js->replaceWith('#record_list', $new_div);
  $self->js->hide('#record_toggle_closed') if scalar @records < 20;
  $self->js->show('#record_toggle_open')   if scalar @records < 20;
  $self->js->render();
}

sub action_toggle_obsolete {
  my ($self) = @_;

  $::auth->assert('email_journal');

  $self->entry(SL::DB::EmailJournal->new(id => $::form->{id})->load);

  if (!$self->can_view_all && ($self->entry->sender_id != SL::DB::Manager::Employee->current->id)) {
    $::form->error(t8('You do not have permission to access this entry.'));
  }

  $self->entry->obsolete(!$self->entry->obsolete);
  $self->entry->save;

  $self->js
  ->val('#obsolete', $self->entry->obsolete_as_bool_yn)
  ->flash('info',
    $self->entry->obsolete ?
      $::locale->text('Email marked as obsolete.')
    : $::locale->text('Email marked as not obsolete.')
  )->render();

  return;
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

sub get_records_for_types {
  my ($self, $record_types, %params) = @_;
  $record_types = [ $record_types ] unless ref $record_types eq 'ARRAY';

  my $cv_type       = $params{customer_vendor_type};
  my $cv_id         = $params{customer_vendor_id};
  my $record_number = $params{record_number};
  my $with_closed   = $params{with_closed};

  my @records = ();
  foreach my $record_type (@$record_types) {
    my $manager = $RECORD_TYPE_TO_MANAGER{$record_type};
    my $model = $RECORD_TYPE_TO_MODEL{$record_type};
    my %additional_where = ();
    if ($cv_type && $cv_id && $record_type !~ /^gl_transaction/) {
      $additional_where{"${cv_type}_id"} = $cv_id;
    }
    if ($record_number) {
      my $nr_key = $RECORD_TYPE_TO_NR_KEY{$record_type};
      $additional_where{$nr_key} = { ilike => "%$record_number%" };
    }
    unless ($with_closed) {
      if (any {$_ eq 'closed'} $model->meta->columns) {
        $additional_where{closed} = 0;
      } elsif (any {$_ eq 'paid'} $model->meta->columns) {
        $additional_where{amount} = { gt => \'paid' };
      }
    }
    my $records_of_type = $manager->get_all(
      where => [
        $manager->type_filter($record_type),
        %additional_where,
      ],
    );
    push @records, @$records_of_type;
  }

  return @records;
}

sub get_records_div {
  my ($self, $records) = @_;
  my $div = div_tag(
    grouped_record_list(
      $records,
      with_columns => [ qw(email_journal_action) ],
    ),
    id => 'record_list',
  );
  return $div;
}

sub link_and_add_attachment_to_record {
 my ($self, $params) = @_;

  my $email_journal_id = $params->{email_journal_id};
  my $attachment_id    = $params->{attachment_id};
  my $record_type      = $params->{record_type};
  my $record_id        = $params->{record_id};

  my $record_type_model = $RECORD_TYPE_TO_MODEL{$record_type};
  my $record = $record_type_model->new(id => $record_id)->load;
  my $email_journal = SL::DB::EmailJournal->new(id => $email_journal_id)->load;

  if ($attachment_id) {
    my $attachment = SL::DB::EmailJournalAttachment->new(id => $attachment_id)->load;
    $attachment->add_file_to_record($record);
  }

  $email_journal->link_to_record($record);

  $self->js->flash('info',
    $::locale->text('Linked email and attachment to ') . $record->displayable_name
  )->render();
}

sub find_customer_vendor_from_email {
  my ($self, $cv_type, $email_journal) = @_;

  my $manager = $cv_type eq 'customer' ? 'SL::DB::Manager::Customer'
              : $cv_type eq 'vendor'   ? 'SL::DB::Manager::Vendor'
              : die "No valid customer vendor option: $cv_type";

  my $email_address = $email_journal->from;
  $email_address =~ s/.*<(.*)>/$1/; # address can look like "name surname <email_address>"

  # Separate query otherwise cv without contacts and shipto is not found
  my $customer_vendor;
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
  if ($manager eq 'SL::DB::Manager::Customer') {
    $customer_vendor ||= $manager->get_first(
      where => [
        or => [
          'additional_billing_addresses.email' => $email_address,
        ],
      ],
      with_objects => [ 'additional_billing_addresses' ],
    );
  }

  # if no exact match is found search for domain and match only on one hit
  unless ($customer_vendor) {
    my $email_domain = $email_address;
    $email_domain =~ s/.*@(.*)/$1/;
    my @domain_hits_cusotmer_vendor = ();
    my @domain_hits = ();
    push @domain_hits, @{$manager->get_all(
      where => [
        or => [
          email => {ilike => "%$email_domain"},
          cc    => {ilike => "%$email_domain"},
          bcc   => {ilike => "%$email_domain"},
        ],
      ],
    )};
    push @domain_hits, @{$manager->get_all(
      where => [
        or => [
          'contacts.cp_email'       => {ilike => "%$email_domain"},
          'contacts.cp_privatemail' => {ilike => "%$email_domain"},
        ],
      ],
      with_objects => [ 'contacts'],
    )};
    push @domain_hits, @{$manager->get_all(
      where => [
        or => [
          'shipto.shiptoemail' => {ilike => "%$email_domain"},
        ],
      ],
      with_objects => [ 'shipto' ],
    )};
    push @domain_hits, @{$manager->get_all(
      where => [
        or => [
          'shipto.shiptoemail' => {ilike => "%$email_domain"},
        ],
      ],
      with_objects => [ 'shipto' ],
    )};
    if ($manager eq 'SL::DB::Manager::Customer') {
      push @domain_hits, @{$manager->get_all(
        where => [
          or => [
            'additional_billing_addresses.email' => {ilike => "%$email_domain"},
          ],
        ],
        with_objects => [ 'additional_billing_addresses' ],
      )};
    }
    # update on only one unique customer_vendor
    if (scalar @domain_hits) {
      my $first_customer_vendor = $domain_hits[0];
      unless (any {$_->id != $first_customer_vendor->id} @domain_hits) {
        $customer_vendor = $first_customer_vendor;
      }
    }
  }

  return $customer_vendor;
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
      record_type     => t8('Record Type'),
      obsolete        => t8('Obsolete'),
      linked_to       => t8('Linked to'),
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
    send_failed     => $::locale->text('send failed'),
    sent            => $::locale->text('sent'),
    imported        => $::locale->text('imported'),
  );
  push @filter_strings, $status{ $filter->{'status:eq_ignore_empty'} } if $filter->{'status:eq_ignore_empty'};


  my %record_type_to_text = $self->get_record_types_to_text();
  push @filter_strings, $record_type_to_text{ $filter->{'record_type:eq_ignore_empty'} } if $filter->{'record_type:eq_ignore_empty'};

  push @filter_strings, $::locale->text('Obsolete')     if $filter->{'obsolete:eq_ignore_empty'} eq '1';
  push @filter_strings, $::locale->text('Not obsolete') if $filter->{'obsolete:eq_ignore_empty'} eq '0';

  push @filter_strings, $::locale->text('Linked')       if $filter->{'linked_to:eq_ignore_empty'} eq '1';
  push @filter_strings, $::locale->text('Not linked')   if $filter->{'linked_to:eq_ignore_empty'} eq '0';

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
