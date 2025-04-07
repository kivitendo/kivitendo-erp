package SL::Controller::Order;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash flash_later);
use SL::HTML::Util;
use SL::Presenter::Tag qw(select_tag hidden_tag div_tag);
use SL::Locale::String qw(t8);
use SL::SessionFile::Random;
use SL::IMAPClient;
use SL::PriceSource;
use SL::Webdav;
use SL::File;
use SL::MIME;
use SL::Util qw(trim);
use SL::YAML;
use SL::DB::AdditionalBillingAddress;
use SL::DB::AuthUser;
use SL::DB::History;
use SL::DB::Order;
use SL::DB::OrderItem;
use SL::DB::Default;
use SL::DB::Unit;
use SL::DB::Part;
use SL::DB::PartClassification;
use SL::DB::PartsGroup;
use SL::DB::Printer;
use SL::DB::Note;
use SL::DB::Language;
use SL::DB::Reclamation;
use SL::DB::RecordLink;
use SL::DB::Shipto;
use SL::DB::Translation;
use SL::DB::EmailJournal;
use SL::DB::ValidityToken;
use SL::DB::Helper::RecordLink qw(set_record_link_conversions RECORD_ID RECORD_TYPE_REF RECORD_ITEM_ID RECORD_ITEM_TYPE_REF);
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Helper::Record qw(get_object_name_from_type get_class_from_type);
use SL::Model::Record;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Reclamation::TypeData qw(:types);

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;
use SL::Helper::ShippedQty;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Helper::UserPreferences::PositionsScrollbar;
use SL::Helper::UserPreferences::UpdatePositions;
use SL::Helper::UserPreferences::ItemInputPosition;

use SL::Controller::Helper::GetModels;

use List::Util qw(first sum0);
use List::UtilsBy qw(sort_by uniq_by);
use List::MoreUtils qw(uniq any none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;
use Cwd;
use Sort::Naturally;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(item_ids_to_delete is_custom_shipto_to_delete) ],
 'scalar --get_set_init' => [ qw(order valid_types type cv p all_price_factors
                              search_cvpartnumber show_update_button
                              part_picker_classification_ids
                              is_final_version type_data) ],
);


# safety
__PACKAGE__->run_before('check_auth',
                        except => [ qw(close_quotations) ]);

__PACKAGE__->run_before('check_auth_for_edit',
                        except => [ qw(edit price_popup load_second_rows close_quotations) ]);
__PACKAGE__->run_before('get_basket_info_from_from',
                        except => [ qw(close_quotations) ]);

#
# actions
#

# add a new order
sub action_add {
  my ($self) = @_;

  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE())->token;
  }

  $self->render(
    'order/form',
    title => $self->type_data->text('add'),
    %{$self->{template_args}}
  );
}

sub action_add_from_record {
  my ($self) = @_;
  my $from_type = $::form->{from_type};
  my $from_id   = $::form->{from_id};

  die "No 'from_type' was given." unless ($from_type);
  die "No 'from_id' was given."   unless ($from_id);

  my %flags = ();
  if (defined($::form->{from_item_ids})) {
    my %use_item = map { $_ => 1 } @{$::form->{from_item_ids}};
    $flags{item_filter} = sub {
      my ($item) = @_;
      return %use_item{$item->{RECORD_ITEM_ID()}};
    }
  }

  my $record = SL::Model::Record->get_record($from_type, $from_id);
  my $order = SL::Model::Record->new_from_workflow($record, $self->type, %flags);
  $self->order($order);

  $self->reinit_after_new_order();

  $self->action_add();
}

sub action_add_from_purchase_basket {
  my ($self) = @_;

  my $basket_item_ids = $::form->{basket_item_ids} || [];
  my $vendor_item_ids = $::form->{vendor_item_ids} || [];
  my $vendor_id       = $::form->{vendor_id};


  unless (scalar @{ $basket_item_ids} || scalar @{ $vendor_item_ids}) {
    $self->js->flash('error', t8('There are no items selected'));
    return $self->js->render();
  }

  my $order = SL::DB::Order->create_from_purchase_basket(
    $basket_item_ids, $vendor_item_ids, $vendor_id
  );

  $self->order($order);

  $self->reinit_after_new_order();

  $self->action_add();
}

sub action_add_from_email_journal {
  my ($self) = @_;
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});

  $self->action_add();
}

sub action_edit_with_email_journal_workflow {
  my ($self) = @_;
  die "No 'email_journal_id' was given." unless ($::form->{email_journal_id});
  $::form->{workflow_email_journal_id}    = delete $::form->{email_journal_id};
  $::form->{workflow_email_attachment_id} = delete $::form->{email_attachment_id};
  $::form->{workflow_email_callback}      = delete $::form->{callback};

  $self->action_edit();
}

# edit an existing order
sub action_edit {
  my ($self) = @_;
  die "No 'id' was given." unless $::form->{id};

  $self->load_order;

  if ($self->order->is_sales && $::lx_office_conf{imap_client}->{enabled}) {
    my $imap_client = SL::IMAPClient->new(%{$::lx_office_conf{imap_client}});
    if ($imap_client) {
      $imap_client->update_email_files_for_record(record => $self->order);
    }
  }

  $self->pre_render();
  $self->render(
    'order/form',
    title => $self->type_data->text('edit'),
    %{$self->{template_args}}
  );
}

# edit a collective order (consisting of one or more existing orders)
sub action_edit_collective {
  my ($self) = @_;

  # collect order ids
  my @multi_ids = map {
    $_ =~ m{^multi_id_(\d+)$} && $::form->{'multi_id_' . $1} && $::form->{'trans_id_' . $1} && $::form->{'trans_id_' . $1}
  } grep { $_ =~ m{^multi_id_\d+$} } keys %$::form;

  # fall back to add if no ids are given
  if (scalar @multi_ids == 0) {
    $self->action_add();
    return;
  }

  # fall back to save as new if only one id is given
  if (scalar @multi_ids == 1) {
    $self->order(SL::DB::Order->new(id => $multi_ids[0])->load);
    $self->action_save_as_new();
    return;
  }

  # make new order from given orders
  my @multi_orders = map { SL::DB::Order->new(id => $_)->load } @multi_ids;
  my $target_type = SALES_ORDER_TYPE();
  my $order = SL::Model::Record->new_from_workflow_multi(\@multi_orders, $target_type, sort_sources_by => 'transdate');
  $self->order($order);
  $self->reinit_after_new_order();

  $self->action_add();
}

# delete the order
sub action_delete {
  my ($self) = @_;

  SL::Model::Record->delete($self->order);
  my $text = $self->type eq SALES_ORDER_INTAKE_TYPE()        ? $::locale->text('The order intake has been deleted')
           : $self->type eq SALES_ORDER_TYPE()               ? $::locale->text('The order confirmation has been deleted')
           : $self->type eq PURCHASE_ORDER_TYPE()            ? $::locale->text('The order has been deleted')
           : $self->type eq PURCHASE_ORDER_CONFIRMATION_TYPE() ? $::locale->text('The order confirmation has been deleted')
           : $self->type eq SALES_QUOTATION_TYPE()           ? $::locale->text('The quotation has been deleted')
           : $self->type eq REQUEST_QUOTATION_TYPE()         ? $::locale->text('The rfq has been deleted')
           : $self->type eq PURCHASE_QUOTATION_INTAKE_TYPE() ? $::locale->text('The quotation intake has been deleted')
           : '';
  flash_later('info', $text);

  my @redirect_params = (
    action => 'add',
    type   => $self->type,
  );

  $self->redirect_to(@redirect_params);
}

# save the order
sub action_save {
  my ($self) = @_;

  $self->save();

  flash_later('info', $self->type_data->text('saved'));

  my @redirect_params;
  if ($::form->{back_to_caller}) {
    @redirect_params = $::form->{callback} ? ($::form->{callback})
                                           : (controller => 'LoginScreen', action => 'user_login');

  } else {
    @redirect_params = (
      action   => 'edit',
      type     => $self->type,
      id       => $self->order->id,
      callback => $::form->{callback},
    );
  }

  $self->redirect_to(@redirect_params);
}

# create new version and set version number
sub action_add_subversion {
  my ($self) = @_;

  SL::DB->client->with_transaction(
    sub {
      SL::Model::Record->increment_subversion($self->order);
      $self->save();
      1;
    }
  );

  $self->redirect_to(action => 'edit',
                     type   => $self->type,
                     id     => $self->order->id,
  );
}

# save the order as new document and open it for edit
sub action_save_as_new {
  my ($self) = @_;

  my $order = $self->order;

  if (!$order->id) {
    $self->js->flash('error', t8('This object has not been saved yet.'));
    return $self->js->render();
  }

  my $saved_order = SL::DB::Order->new(id => $order->id)->load;

  # Create new record from current one
  my $new_order = SL::Model::Record->clone_for_save_as_new($saved_order, $order);
  $self->order($new_order);

  # Warn on obsolete items
  my @obsolete_positions = map { $_->position } grep { $_->part->obsolete } @{ $self->order->items_sorted };
  flash_later('warning', t8('This record contains obsolete items at position #1', join ', ', @obsolete_positions)) if @obsolete_positions;

  # Warn on order locked items if they are not wanted for this record type
  if ($self->type_data->no_order_locked_parts) {
    my @order_locked_positions = map { $_->position } grep { $_->part->order_locked } @{ $self->order->items_sorted };
    flash_later('warning', t8('This record contains not orderable items at position #1', join ', ', @order_locked_positions)) if @order_locked_positions;
  }

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE())->token;
  }

  # save
  $self->action_save();
}

# print the order
#
# This is called if "print" is pressed in the print dialog.
# If PDF creation was requested and succeeded, the pdf is offered for download
# via send_file (which uses ajax in this case).
sub action_print {
  my ($self) = @_;

  $self->save();

  $self->js_reset_order_and_item_ids_after_save;

  my $redirect_url = $self->url_for(
    action => 'edit',
    type   => $self->type,
    id     => $self->order->id,
  );

  my $format      = $::form->{print_options}->{format};
  my $media       = $::form->{print_options}->{media};
  my $formname    = $::form->{print_options}->{formname};
  my $copies      = $::form->{print_options}->{copies};
  my $groupitems  = $::form->{print_options}->{groupitems};
  my $printer_id  = $::form->{print_options}->{printer_id};

  # only PDF, OpenDocument & HTML for now
  if (none { $format eq $_ } qw(pdf opendocument opendocument_pdf html)) {
    flash_later('error', t8('Format \'#1\' is not supported yet/anymore.', $format));
    return $self->js->redirect_to($redirect_url)->render;
  }

  # only screen or printer by now
  if (none { $media eq $_ } qw(screen printer)) {
    flash_later('error', t8('Media \'#1\' is not supported yet/anymore.', $media));
    return $self->js->redirect_to($redirect_url)->render;
  }

  # create a form for generate_attachment_filename
  my $form   = Form->new;
  $form->{$self->nr_key()}  = $self->order->number;
  $form->{type}             = $self->type;
  $form->{format}           = $format;
  $form->{formname}         = $formname;
  $form->{language}         = '_' . $self->order->language->template_code if $self->order->language;
  my $doc_filename          = $form->generate_attachment_filename();

  my $doc;
  my @errors = $self->generate_doc(\$doc, { media      => $media,
                                            format     => $format,
                                            formname   => $formname,
                                            language   => $self->order->language,
                                            printer_id => $printer_id,
                                            groupitems => $groupitems });
  if (scalar @errors) {
    flash_later('error', t8('Generating the document failed: #1', $errors[0]));
    return $self->js->redirect_to($redirect_url)->render;
  }

  if ($media eq 'screen') {
    # screen/download
    flash_later('info', t8('The document has been created.'));
    $self->send_file(
      \$doc,
      type         => SL::MIME->mime_type_from_ext($doc_filename),
      name         => $doc_filename,
      js_no_render => 1,
    );

  } elsif ($media eq 'printer') {
    # printer
    my $printer_id = $::form->{print_options}->{printer_id};
    SL::DB::Printer->new(id => $printer_id)->load->print_document(
      copies  => $copies,
      content => $doc,
    );

    flash_later('info', t8('The document has been printed.'));
  }

  my @warnings = $self->store_doc_to_webdav_and_filemanagement($doc, $doc_filename, $formname);
  if (scalar @warnings) {
    flash_later('warning', $_) for @warnings;
  }

  $self->save_history('PRINTED');

  $self->js->redirect_to($redirect_url)->render;
}

sub action_preview_pdf {
  my ($self) = @_;

  $self->save();

  $self->js_reset_order_and_item_ids_after_save;

  my $redirect_url = $self->url_for(
    action => 'edit',
    type   => $self->type,
    id     => $self->order->id,
  );

  my $format      = 'pdf';
  my $media       = 'screen';
  my $formname    = $self->type;

  # only pdf
  # create a form for generate_attachment_filename
  my $form   = Form->new;
  $form->{$self->nr_key()}  = $self->order->number;
  $form->{type}             = $self->type;
  $form->{format}           = $format;
  $form->{formname}         = $formname;
  $form->{language}         = '_' . $self->order->language->template_code if $self->order->language;
  my $pdf_filename          = $form->generate_attachment_filename();

  my $pdf;
  my @errors = $self->generate_doc(\$pdf, { media      => $media,
                                            format     => $format,
                                            formname   => $formname,
                                            language   => $self->order->language,
                                          });
  if (scalar @errors) {
    flash_later('error', t8('Conversion to PDF failed: #1', $errors[0]));
    return $self->js->redirect_to($redirect_url)->render;
  }

  $self->save_history('PREVIEWED');

  flash_later('info', t8('The PDF has been previewed'));

  # screen/download
  $self->send_file(
    \$pdf,
    type         => SL::MIME->mime_type_from_ext($pdf_filename),
    name         => $pdf_filename,
    js_no_render => 1,
  );

  $self->js->redirect_to($redirect_url)->render;
}

# open the email dialog
sub action_save_and_show_email_dialog {
  my ($self) = @_;

  if (!$self->is_final_version) {
    $self->save();
    $self->js_reset_order_and_item_ids_after_save;
  }

  my $cv = $self->order->customervendor
    or return $self->js->flash('error',
      $self->type_data->properties('is_customer') ?
          t8('Cannot send E-mail without customer given')
        : t8('Cannot send E-mail without vendor given')
    )->render($self);

  my $form = Form->new;
  $form->{$self->nr_key()}         = $self->order->number;
  $form->{cusordnumber}            = $self->order->cusordnumber;
  $form->{formname}                = $self->type;
  $form->{type}                    = $self->type;
  $form->{language}                = '_' . $self->order->language->template_code if $self->order->language;
  $form->{language_id}             = $self->order->language->id                  if $self->order->language;
  $form->{format}                  = 'pdf';
  $form->{cp_id}                   = $self->order->contact->cp_id if $self->order->contact;
  $form->{transaction_description} = $self->order->transaction_description;

  my $email_form;
  $email_form->{to} =
       ($self->order->contact ? $self->order->contact->cp_email : undef)
    ||  $cv->email;
  $email_form->{cc}  = $cv->cc;
  $email_form->{bcc} = join ', ', grep $_, $cv->bcc;
  # Todo: get addresses from shipto, if any
  $email_form->{subject}             = $form->generate_email_subject();
  $email_form->{attachment_filename} = $form->generate_attachment_filename();
  $email_form->{message}             = $form->generate_email_body();
  $email_form->{js_send_function}    = 'kivi.Order.send_email()';

  my %files = $self->get_files_for_email_dialog();

  my @employees_with_email = grep {
    my $user = SL::DB::Manager::AuthUser->find_by(login => $_->login);
    $user && !!trim($user->get_config_value('email'));
  } @{ SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]) };

  my $dialog_html = $self->render(
    'common/_send_email_dialog', { output => 0 },
    email_form    => $email_form,
    show_bcc      => $::auth->assert('email_bcc', 'may fail'),
    FILES         => \%files,
    is_customer   => $self->type_data->properties('is_customer'),
    ALL_EMPLOYEES => \@employees_with_email,
    ALL_PARTNER_EMAIL_ADDRESSES => $cv->get_all_email_addresses(),
    is_final_version => $self->is_final_version,
  );

  $self->js
    ->run('kivi.Order.show_email_dialog', $dialog_html)
    ->reinit_widgets
    ->render($self);
}

# send email
sub action_send_email {
  my ($self) = @_;

  if (!$self->is_final_version) {
    eval {
      $self->save();
      1;
    } or do {
      $self->js->run('kivi.Order.close_email_dialog');
      die $EVAL_ERROR;
    };
  }

  my @redirect_params = (
    action => 'edit',
    type   => $self->type,
    id     => $self->order->id,
  );

  # Set the error handler to reload the document and display errors later,
  # because the document is already saved and saving can have some side effects
  # such as generating a document number, project number or record links,
  # which will be up to date when the document is reloaded.
  # Hint: Do not use "die" here and try to catch exceptions in subroutine
  # calls. You should use "$::form->error" which respects the error handler.
  local $::form->{__ERROR_HANDLER} = sub {
      flash_later('error', $_[0]);
      $self->redirect_to(@redirect_params);
      $::dispatcher->end_request;
  };

  # move $::form->{email_form} to $::form
  my $email_form  = delete $::form->{email_form};

  if ($email_form->{additional_to}) {
    $email_form->{to} = join ', ', grep { $_ } $email_form->{to}, @{$email_form->{additional_to}};
    delete $email_form->{additional_to};
  }

  my %field_names = (to => 'email');
  $::form->{ $field_names{$_} // $_ } = $email_form->{$_} for keys %{ $email_form };

  # for Form::cleanup which may be called in Form::send_email
  $::form->{cwd}    = getcwd();
  $::form->{tmpdir} = $::lx_office_conf{paths}->{userspath};

  $::form->{$_}     = $::form->{print_options}->{$_} for keys %{ $::form->{print_options} };
  $::form->{media}  = 'email';

  $::form->{attachment_policy} //= '';

  # Is an old file version available?
  my $attfile;
  if ($::form->{attachment_policy} eq 'old_file') {
    $attfile = SL::File->get_all(
      object_id     => $self->order->id,
      object_type   => $self->type,
      print_variant => $::form->{formname},
    );
  }

  if ($self->is_final_version && $::form->{attachment_policy} eq 'old_file' && !$attfile) {
    $::form->error(t8('Re-sending a final version was requested, but the latest version of the document could not be found'));
  }

  if ( !$self->is_final_version
    &&   $::form->{attachment_policy} ne 'no_file'
    && !($::form->{attachment_policy} eq 'old_file' && $attfile)
  ) {
    my $doc;
    my @errors = $self->generate_doc(\$doc, {
        media      => $::form->{media},
        format     => $::form->{print_options}->{format},
        formname   => $::form->{print_options}->{formname},
        language   => $self->order->language,
        printer_id => $::form->{print_options}->{printer_id},
        groupitems => $::form->{print_options}->{groupitems},
      });
    if (scalar @errors) {
      $::form->error(t8('Generating the document failed: #1', $errors[0]));
    }

    my @warnings = $self->store_doc_to_webdav_and_filemanagement(
      $doc, $::form->{attachment_filename}, $::form->{formname}
    );
    if (scalar @warnings) {
      flash_later('warning', $_) for @warnings;
    }

    my $sfile = SL::SessionFile::Random->new(mode => "w");
    $sfile->fh->print($doc);
    $sfile->fh->close;

    $::form->{tmpfile} = $sfile->file_name;
    $::form->{tmpdir}  = $sfile->get_path; # for Form::cleanup which may be
                                           # called in Form::send_email
  }

  $::form->{id} = $self->order->id; # this is used in SL::Mailer to create a
                                    # linked record to the mail
  $::form->send_email(\%::myconfig, $::form->{print_options}->{format});

  flash_later('info', t8('The email has been sent.'));
  $self->save_history('MAILED');

  # internal notes unless no email journal
  unless ($::instance_conf->get_email_journal) {
    my $intnotes = $self->order->intnotes;
    $intnotes   .= "\n\n" if $self->order->intnotes;
    $intnotes   .= t8('[email]')                                       . "\n";
    $intnotes   .= t8('Date')       . ": " . $::locale->format_date_object(
                                               DateTime->now_local,
                                               precision => 'seconds') . "\n";
    $intnotes   .= t8('To (email)') . ": " . $::form->{email}          . "\n";
    $intnotes   .= t8('Cc')         . ": " . $::form->{cc}             . "\n"    if $::form->{cc};
    $intnotes   .= t8('Bcc')        . ": " . $::form->{bcc}            . "\n"    if $::form->{bcc};
    $intnotes   .= t8('Subject')    . ": " . $::form->{subject}        . "\n\n";
    $intnotes   .= t8('Message')    . ": " . SL::HTML::Util->strip($::form->{message});

    $self->order->update_attributes(intnotes => $intnotes);
  }

  if ($::instance_conf->get_lock_oe_subversions && !$self->is_final_version) {
    my $file_id;
    if ($::instance_conf->get_doc_storage && $::form->{attachment_policy} ne 'no_file') {
      # self is generated on the fly. form is a file from the dms
      # TODO: for the case Filesystem and Webdav we want the real file from the filesystem
      #       for the nyi case DMS/CMIS we need a gloid or whatever the system offers (elo_id for ELO)
      #       DMS kivi version should have a record_link to email_journal
      #       the record link has to refer to the correct version -> helper table file <-> file_version
      $file_id = $self->{file_id} || $::form->{file_id};
      $::form->error("No file id") unless $file_id;
    }

    # email is sent -> set this version to final and link to journal and file
    my $current_version = SL::DB::Manager::OrderVersion->get_all(where => [oe_id => $self->order->id, final_version => 0]);
    $::form->error("Invalid version state") unless scalar @{ $current_version } == 1;
    $current_version->[0]->update_attributes(file_id          => $file_id,
                                             email_journal_id => $::form->{email_journal_id},
                                             final_version    => 1);
  }

  $self->redirect_to(@redirect_params);
}

# open the periodic invoices config dialog
#
# If there are values in the form (i.e. dialog was opened before),
# then use this values. Create new ones, else.
sub action_show_periodic_invoices_config_dialog {
  my ($self) = @_;

  my $config = make_periodic_invoices_config_from_yaml(delete $::form->{config});
  $config  ||= SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $::form->{id}) if $::form->{id};
  $config  ||= SL::DB::PeriodicInvoicesConfig->new(periodicity             => 'm',
                                                   order_value_periodicity => 'p', # = same as periodicity
                                                   start_date_as_date      => $::form->{transdate_as_date} || $::form->current_date,
                                                   extend_automatically_by => 12,
                                                   active                  => 1,
                                                   email_subject           => GenericTranslations->get(
                                                                                language_id      => $::form->{language_id},
                                                                                translation_type =>"preset_text_periodic_invoices_email_subject"),
                                                   email_body              => GenericTranslations->get(
                                                                                language_id      => $::form->{language_id},
                                                                                translation_type => "salutation_general")
                                                                            . GenericTranslations->get(
                                                                                language_id      => $::form->{language_id},
                                                                                translation_type => "salutation_punctuation_mark") . "\n\n"
                                                                            . GenericTranslations->get(
                                                                                language_id      => $::form->{language_id},
                                                                                translation_type =>"preset_text_periodic_invoices_email_body"),
  );
  # for older configs, replace email preset text if not yet set.
  $config->email_subject(GenericTranslations->get(
                                              language_id      => $::form->{language_id},
                                              translation_type =>"preset_text_periodic_invoices_email_subject")
                        ) unless $config->email_subject;

  $config->email_body(GenericTranslations->get(
                                              language_id      => $::form->{language_id},
                                              translation_type => "salutation_general")
                    . GenericTranslations->get(
                                              language_id      => $::form->{language_id},
                                              translation_type => "salutation_punctuation_mark") . "\n\n"
                    . GenericTranslations->get(
                                              language_id      => $::form->{language_id},
                                              translation_type =>"preset_text_periodic_invoices_email_body")
                     ) unless $config->email_body;

  $config->periodicity('m')             if none { $_ eq $config->periodicity             }       @SL::DB::PeriodicInvoicesConfig::PERIODICITIES;
  $config->order_value_periodicity('p') if none { $_ eq $config->order_value_periodicity } ('p', @SL::DB::PeriodicInvoicesConfig::ORDER_VALUE_PERIODICITIES);

  $::form->get_lists(printers => "ALL_PRINTERS",
                     charts   => { key       => 'ALL_CHARTS',
                                   transdate => 'current_date' });

  $::form->{AR} = [ grep { $_->{link} =~ m/(?:^|:)AR(?::|$)/ } @{ $::form->{ALL_CHARTS} } ];

  if ($::form->{customer_id}) {
    $::form->{ALL_CONTACTS} = SL::DB::Manager::Contact->get_all_sorted(where => [ cp_cv_id => $::form->{customer_id} ]);
    my $customer_object = SL::DB::Manager::Customer->find_by(id => $::form->{customer_id});
    $::form->{postal_invoice}                  = $customer_object->postal_invoice;
    $::form->{email_recipient_invoice_address} = $::form->{postal_invoice} ? '' : $customer_object->invoice_mail;
    $config->send_email(0) if $::form->{postal_invoice};
  }

  $self->render('oe/edit_periodic_invoices_config', { layout => 0 },
                popup_dialog             => 1,
                popup_js_close_function  => 'kivi.Order.close_periodic_invoices_config_dialog()',
                popup_js_assign_function => 'kivi.Order.assign_periodic_invoices_config()',
                config                   => $config,
                %$::form);
}

# assign the values of the periodic invoices config dialog
# as yaml in the hidden tag and set the status.
sub action_assign_periodic_invoices_config {
  my ($self) = @_;

  $::form->isblank('start_date_as_date', $::locale->text('The start date is missing.'));

  my $config = { active                     => $::form->{active}       ? 1 : 0,
                 terminated                 => $::form->{terminated}   ? 1 : 0,
                 direct_debit               => $::form->{direct_debit} ? 1 : 0,
                 periodicity                => (any { $_ eq $::form->{periodicity}             }       @SL::DB::PeriodicInvoicesConfig::PERIODICITIES)              ? $::form->{periodicity}             : 'm',
                 order_value_periodicity    => (any { $_ eq $::form->{order_value_periodicity} } ('p', @SL::DB::PeriodicInvoicesConfig::ORDER_VALUE_PERIODICITIES)) ? $::form->{order_value_periodicity} : 'p',
                 start_date_as_date         => $::form->{start_date_as_date},
                 end_date_as_date           => $::form->{end_date_as_date},
                 first_billing_date_as_date => $::form->{first_billing_date_as_date},
                 print                      => $::form->{print}      ? 1                         : 0,
                 printer_id                 => $::form->{print}      ? $::form->{printer_id} * 1 : undef,
                 copies                     => $::form->{copies} * 1 ? $::form->{copies}         : 1,
                 extend_automatically_by    => $::form->{extend_automatically_by}    * 1 || undef,
                 ar_chart_id                => $::form->{ar_chart_id} * 1,
                 send_email                 => $::form->{send_email} ? 1 : 0,
                 email_recipient_contact_id => $::form->{email_recipient_contact_id} * 1 || undef,
                 email_recipient_address    => $::form->{email_recipient_address},
                 email_sender               => $::form->{email_sender},
                 email_subject              => $::form->{email_subject},
                 email_body                 => $::form->{email_body},
               };

  my $periodic_invoices_config = SL::YAML::Dump($config);

  my $status = $self->get_periodic_invoices_status($config);

  $self->js
    ->remove('#order_periodic_invoices_config')
    ->insertAfter(hidden_tag('order.periodic_invoices_config', $periodic_invoices_config), '#periodic_invoices_status')
    ->run('kivi.Order.close_periodic_invoices_config_dialog')
    ->html('#periodic_invoices_status', $status)
    ->flash('info', t8('The periodic invoices config has been assigned.'))
    ->render($self);
}

sub action_get_has_active_periodic_invoices {
  my ($self) = @_;

  my $config = make_periodic_invoices_config_from_yaml(delete $::form->{config});
  $config  ||= SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $::form->{id}) if $::form->{id};

  my $has_active_periodic_invoices =
       $self->type eq SALES_ORDER_TYPE()
    && $config
    && $config->active
    && (!$config->end_date || ($config->end_date > DateTime->today_local))
    && $config->get_previous_billed_period_start_date;

  $_[0]->render(\ !!$has_active_periodic_invoices, { type => 'text' });
}

sub action_save_and_new_record {
  my ($self) = @_;
  my $to_type = $::form->{to_type};
  my $to_controller = get_object_name_from_type($to_type);

  $self->save();
  flash_later('info', $self->type_data->text('saved'));

  my %additional_params = ();
  if ($::form->{only_selected_item_positions}) { # ids can be unset before save
    my $item_positions = $::form->{selected_item_positions} || [];
    my @from_item_ids = map { $self->order->items_sorted->[$_]->id } @$item_positions;
    $additional_params{from_item_ids} = \@from_item_ids;
  }

  $self->redirect_to(
    controller => $to_controller,
    action     => 'add_from_record',
    type       => $to_type,
    from_id    => $self->order->id,
    from_type  => $self->order->type,
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
    %additional_params,
  );
}

# save the order and redirect to the frontend subroutine for a new
# invoice
sub action_save_and_invoice {
  my ($self) = @_;

  $self->save_and_redirect_to(
    controller => 'oe.pl',
    action     => 'oe_invoice_from_order',
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
  );
}

sub action_save_and_invoice_for_advance_payment {
  my ($self) = @_;

  $self->save_and_redirect_to(
    controller       => 'oe.pl',
    action           => 'oe_invoice_from_order',
    new_invoice_type => 'invoice_for_advance_payment',
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
  );
}

sub action_save_and_final_invoice {
  my ($self) = @_;

  $self->save_and_redirect_to(
    controller       => 'oe.pl',
    action           => 'oe_invoice_from_order',
    new_invoice_type => 'final_invoice',
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
  );
}

# workflows to all types of this controller
sub action_save_and_order_workflow {
  my ($self) = @_;

  $self->save_and_redirect_to(
    action     => 'order_workflow',
    type       => $self->type,
    to_type    => $::form->{to_type},
    use_shipto => $::form->{use_shipto},
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
  );
}

# workflow from purchase order to ap transaction
sub action_save_and_ap_transaction {
  my ($self) = @_;

  $self->save_and_redirect_to(
    controller => 'ap.pl',
    action     => 'add_from_purchase_order',
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
  );
}

sub action_order_workflow {
  my ($self) = @_;

  $self->load_order;

  my $destination_type = $::form->{to_type} ? $::form->{to_type} : '';

  my $from_side        = $self->order->is_sales ? 'sales' : 'purchase';
  my $to_side          = (any { $destination_type eq $_ } (SALES_ORDER_INTAKE_TYPE(), SALES_ORDER_TYPE(), SALES_QUOTATION_TYPE())) ? 'sales' : 'purchase';

  # check for direct delivery
  # copy shipto in custom shipto (custom shipto will be copied by new_from() in case)
  my $custom_shipto;
  if (   $from_side eq 'sales' && $to_side eq 'purchase'
      && $::form->{use_shipto} && $self->order->shipto) {
    $custom_shipto = $self->order->shipto->clone('SL::DB::Order');
  }

  my $no_linked_records =    (any { $destination_type eq $_ } (SALES_QUOTATION_TYPE(), REQUEST_QUOTATION_TYPE()))
                          && $from_side eq $to_side;

  $self->order(SL::Model::Record->new_from_workflow($self->order, $destination_type, no_linked_records => $no_linked_records));

  delete $::form->{id};

  if (!$no_linked_records) {
    $self->{converted_from_oe_id}         = $self->order->{ RECORD_ID()      };
    $_   ->{converted_from_orderitems_id} = $_          ->{ RECORD_ITEM_ID() } for @{ $self->order->items_sorted };
  }

  if ($from_side eq 'sales' && $to_side eq 'purchase') {
    $self->order->notes('');
    if ($::form->{use_shipto}) {
      $self->order->custom_shipto($custom_shipto) if $custom_shipto;
    } else {
      # remove any custom shipto if not wanted
      $self->order->custom_shipto(SL::DB::Shipto->new(module => 'OE', custom_variables => []));
    }
  }

  $self->reinit_after_new_order();

  $self->action_add;
}

# set form elements in respect to a changed customer or vendor
#
# This action is called on an change of the customer/vendor picker.
sub action_customer_vendor_changed {
  my ($self) = @_;

  $self->order(SL::Model::Record->update_after_customer_vendor_change($self->order));

  $self->recalc();

  my $cv_method = $self->cv;

  if ($self->order->$cv_method->contacts && scalar @{ $self->order->$cv_method->contacts } > 0) {
    $self->js->show('#cp_row');
  } else {
    $self->js->hide('#cp_row');
  }

  if ($self->order->$cv_method->shipto && scalar @{ $self->order->$cv_method->shipto } > 0) {
    $self->js->show('#shipto_selection');
  } else {
    $self->js->hide('#shipto_selection');
  }

  if ($cv_method eq 'customer') {
    my $show_hide = scalar @{ $self->order->customer->additional_billing_addresses } > 0 ? 'show' : 'hide';
    $self->js->$show_hide('#billing_address_row');
  }

  $self->js->val( '#order_salesman_id',      $self->order->salesman_id)        if $self->order->is_sales;

  $self->js
    ->replaceWith('#order_cp_id',              $self->build_contact_select)
    ->replaceWith('#order_shipto_id',          $self->build_shipto_select)
    ->replaceWith('#shipto_inputs  ',          $self->build_shipto_inputs)
    ->replaceWith('#order_billing_address_id', $self->build_billing_address_select)
    ->replaceWith('#business_info_row',        $self->build_business_info_row)
    ->val(        '#order_taxzone_id',         $self->order->taxzone_id)
    ->val(        '#order_taxincluded',        $self->order->taxincluded)
    ->val(        '#order_currency_id',        $self->order->currency_id)
    ->val(        '#order_payment_id',         $self->order->payment_id)
    ->val(        '#order_delivery_term_id',   $self->order->delivery_term_id)
    ->val(        '#order_intnotes',           $self->order->intnotes)
    ->val(        '#order_language_id',        $self->order->$cv_method->language_id)
    ->focus(      '#order_' . $self->cv . '_id')
    ->run('kivi.Order.update_exchangerate');

  $self->js_redisplay_amounts_and_taxes;
  $self->js_redisplay_cvpartnumbers;
  $self->js->render();
}

# called if a unit in an existing item row is changed
sub action_unit_changed {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{orderitem_ids} };
  my $item = $self->order->items_sorted->[$idx];

  my $old_unit_obj = SL::DB::Unit->new(name => $::form->{old_unit})->load;
  $item->sellprice($item->unit_obj->convert_to($item->sellprice, $old_unit_obj));

  $self->recalc();

  $self->js
    ->run('kivi.Order.update_sellprice', $::form->{item_id}, $item->sellprice_as_number);
  $self->js_redisplay_line_values;
  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# update item input row when a part ist picked
sub action_update_item_input_row {
  my ($self) = @_;

  delete $::form->{add_item}->{$_} for qw(create_part_type sellprice_as_number discount_as_percent);

  my $form_attr = $::form->{add_item};

  return unless $form_attr->{parts_id};

  my $record       = $self->order;
  my $item         = SL::DB::OrderItem->new(%$form_attr);
  $item->qty(1) if !$item->qty;
  $item->unit($item->part->unit);

  my ($price_src, $discount_src) = SL::Model::Record->get_best_price_and_discount_source($record, $item, ignore_given => 0);

  my $texts = SL::Model::Record->get_part_texts($item->part, $record->language_id);

  $self->js
    ->val     ('#add_item_unit',                $item->unit)
    ->val     ('#add_item_description',         $texts->{description})
    ->val     ('#add_item_sellprice_as_number', '')
    ->attr    ('#add_item_sellprice_as_number', 'placeholder', $price_src->price_as_number)
    ->attr    ('#add_item_sellprice_as_number', 'title',       $price_src->source_description)
    ->val     ('#add_item_discount_as_percent', '')
    ->attr    ('#add_item_discount_as_percent', 'placeholder', $discount_src->discount_as_percent)
    ->attr    ('#add_item_discount_as_percent', 'title',       $discount_src->source_description)
    ->render;
}

# add an item row for a new item entered in the input row
sub action_add_item {
  my ($self) = @_;

  delete $::form->{add_item}->{create_part_type};

  my $form_attr = $::form->{add_item};

  return unless $form_attr->{parts_id};

  my $item = new_item($self->order, $form_attr);

  $self->order->add_items($item);

  $self->recalc();

  $self->get_item_cvpartnumber($item);

  my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $row_as_html = $self->p->render('order/tabs/_row',
                                     ITEM => $item,
                                     ID   => $item_id,
                                     SELF => $self,
  );

  if ($::form->{insert_before_item_id}) {
    $self->js
      ->before ('.row_entry:has(#item_' . $::form->{insert_before_item_id} . ')', $row_as_html);
  } else {
    $self->js
      ->before('#row_table_footer', $row_as_html);
  }

  if ( $item->part->is_assortment ) {
    $form_attr->{qty_as_number} = 1 unless $form_attr->{qty_as_number};
    foreach my $assortment_item ( @{$item->part->assortment_items} ) {
      my $attr = { parts_id => $assortment_item->parts_id,
                   qty      => $assortment_item->qty * $::form->parse_amount(\%::myconfig, $form_attr->{qty_as_number}), # TODO $form_attr->{unit}
                   unit     => $assortment_item->unit,
                   description => $assortment_item->part->description,
                 };
      my $item = new_item($self->order, $attr);

      # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
      $item->discount(1) unless $assortment_item->charge;

      $self->order->add_items( $item );
      $self->recalc();
      $self->get_item_cvpartnumber($item);
      my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
      my $row_as_html = $self->p->render('order/tabs/_row',
                                         ITEM => $item,
                                         ID   => $item_id,
                                         SELF => $self,
      );
      if ($::form->{insert_before_item_id}) {
        $self->js
          ->before ('.row_entry:has(#item_' . $::form->{insert_before_item_id} . ')', $row_as_html);
      } else {
        $self->js
          ->before('#row_table_footer', $row_as_html);
      }
    };
  };

  $self->js
    ->val('.add_item_input', '')
    ->attr('.add_item_input', 'placeholder', '')
    ->attr('.add_item_input', 'title', '')
    ->attr('#add_item_qty_as_number', 'placeholder', '1')
    ->run('kivi.Order.init_row_handlers')
    ->run('kivi.Order.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.Order.row_table_scroll_down') if !$::form->{insert_before_item_id};

  # alternate scroll behaviour if item input below positions and unlimited scroll height
  $self->js->run('kivi.Order.scroll_page_after_row_insert', $item_id)
    if 0 == SL::Helper::UserPreferences::PositionsScrollbar->new()->get_height
    && SL::Helper::UserPreferences::ItemInputPosition->new()->get_order_item_input_position
       // $::instance_conf->get_order_item_input_position;

  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# add item rows for multiple items at once
sub action_add_multi_items {
  my ($self) = @_;

  my @form_attr = grep { $_->{qty_as_number} } @{ $::form->{add_items} };
  return $self->js->render() unless scalar @form_attr;

  my @items;
  foreach my $attr (@form_attr) {
    my $item = new_item($self->order, $attr);
    push @items, $item;
    if ( $item->part->is_assortment ) {
      foreach my $assortment_item ( @{$item->part->assortment_items} ) {
        my $attr = { parts_id => $assortment_item->parts_id,
                     qty      => $assortment_item->qty * $item->qty, # TODO $form_attr->{unit}
                     unit     => $assortment_item->unit,
                     description => $assortment_item->part->description,
                   };
        my $item = new_item($self->order, $attr);

        # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
        $item->discount(1) unless $assortment_item->charge;
        push @items, $item;
      }
    }
  }
  $self->order->add_items(@items);

  $self->recalc();

  foreach my $item (@items) {
    $self->get_item_cvpartnumber($item);
    my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
    my $row_as_html = $self->p->render('order/tabs/_row',
                                       ITEM => $item,
                                       ID   => $item_id,
                                       SELF => $self,
    );

    if ($::form->{insert_before_item_id}) {
      $self->js
        ->before ('.row_entry:has(#item_' . $::form->{insert_before_item_id} . ')', $row_as_html);
    } else {
      $self->js
        ->append('#row_table_id', $row_as_html);
    }
  }

  $self->js
    ->run('kivi.Part.close_picker_dialogs')
    ->run('kivi.Order.init_row_handlers')
    ->run('kivi.Order.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.Order.row_table_scroll_down') if !$::form->{insert_before_item_id};

  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# recalculate all linetotals, amounts and taxes and redisplay them
sub action_recalc_amounts_and_taxes {
  my ($self) = @_;

  $self->recalc();

  $self->js_redisplay_line_values;
  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

sub action_update_exchangerate {
  my ($self) = @_;

  my $data = {
    is_standard   => $self->order->currency_id == $::instance_conf->get_currency_id,
    currency_name => $self->order->currency->name,
    exchangerate  => $self->order->daily_exchangerate_as_null_number,
  };

  $self->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

# redisplay item rows if they are sorted by an attribute
sub action_reorder_items {
  my ($self) = @_;

  my %sort_keys = (
    partnumber   => sub { $_[0]->part->partnumber },
    description  => sub { $_[0]->description },
    qty          => sub { $_[0]->qty },
    sellprice    => sub { $_[0]->sellprice },
    discount     => sub { $_[0]->discount },
    cvpartnumber => sub { $_[0]->{cvpartnumber} },
  );

  $self->get_item_cvpartnumber($_) for @{$self->order->items_sorted};

  my $method = $sort_keys{$::form->{order_by}};
  my @to_sort = map { { old_pos => $_->position, order_by => $method->($_) } } @{ $self->order->items_sorted };
  if ($::form->{sort_dir}) {
    if ( $::form->{order_by} =~ m/qty|sellprice|discount/ ){
      @to_sort = sort { $a->{order_by} <=> $b->{order_by} } @to_sort;
    } else {
      @to_sort = sort { $a->{order_by} cmp $b->{order_by} } @to_sort;
    }
  } else {
    if ( $::form->{order_by} =~ m/qty|sellprice|discount/ ){
      @to_sort = sort { $b->{order_by} <=> $a->{order_by} } @to_sort;
    } else {
      @to_sort = sort { $b->{order_by} cmp $a->{order_by} } @to_sort;
    }
  }
  $self->js
    ->run('kivi.Order.redisplay_items', \@to_sort)
    ->render;
}

# show the popup to choose a price/discount source
sub action_price_popup {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{orderitem_ids} };
  my $item = $self->order->items_sorted->[$idx];

  $self->render_price_dialog($item);
}

# save the order in a session variable and redirect to the part controller
sub action_create_part {
  my ($self) = @_;

  my $previousform = $::auth->save_form_in_session(non_scalars => 1);

  my $callback     = $self->url_for(
    action       => 'return_from_create_part',
    type         => $self->type, # type is needed for check_auth on return
    previousform => $previousform,
  );

  flash_later('info', t8('You are adding a new part while you are editing another document. You will be redirected to your document when saving the new part or aborting this form.'));

  my @redirect_params = (
    controller    => 'Part',
    action        => 'add',
    part_type     => $::form->{add_item}->{create_part_type},
    callback      => $callback,
    inline_create => 1,
  );

  $self->redirect_to(@redirect_params);
}

sub action_return_from_create_part {
  my ($self) = @_;

  $self->{created_part} = SL::DB::Part->new(
    id => delete $::form->{new_parts_id}
  )->load if $::form->{new_parts_id};

  $::auth->restore_form_from_session(delete $::form->{previousform});

  $self->order($self->init_order);
  $self->reinit_after_new_order();

  if ($self->order->id) {
    $self->pre_render();
    $self->render(
      'order/form',
      title => $self->type_data->text('edit'),
      %{$self->{template_args}}
    );
  } else {
    $self->action_add;
  }
}

# load the second row for one or more items
#
# This action gets the html code for all items second rows by rendering a template for
# the second row and sets the html code via client js.
sub action_load_second_rows {
  my ($self) = @_;

  $self->recalc() if $self->order->is_sales; # for margin calculation

  foreach my $item_id (@{ $::form->{item_ids} }) {
    my $idx  = first_index { $_ eq $item_id } @{ $::form->{orderitem_ids} };
    my $item = $self->order->items_sorted->[$idx];

    $self->js_load_second_row($item, $item_id, 0);
  }

  $self->js->run('kivi.Order.init_row_handlers') if $self->order->is_sales; # for lastcosts change-callback

  $self->js->render();
}

# update description, notes and sellprice from master data
sub action_update_row_from_master_data {
  my ($self) = @_;

  foreach my $item_id (@{ $::form->{item_ids} }) {
    my $idx   = first_index { $_ eq $item_id } @{ $::form->{orderitem_ids} };
    my $item  = $self->order->items_sorted->[$idx];
    my $texts = SL::Model::Record->get_part_texts($item->part, $self->order->language_id);

    $item->description($texts->{description});
    $item->longdescription($texts->{longdescription});

    my ($price_src, $discount_src) = SL::Model::Record->get_best_price_and_discount_source($self->order, $item, ignore_given => 1);
    $item->sellprice($price_src->price);
    $item->active_price_source($price_src);
    $item->discount($discount_src->discount);
    $item->active_discount_source($discount_src);

    my $price_editable = $self->order->is_sales ? $::auth->assert('sales_edit_prices', 1) : $::auth->assert('purchase_edit_prices', 1);

    $self->js
      ->run('kivi.Order.set_price_and_source_text',    $item_id, $price_src   ->source, $price_src   ->source_description, $item->sellprice_as_number, $price_editable)
      ->run('kivi.Order.set_discount_and_source_text', $item_id, $discount_src->source, $discount_src->source_description, $item->discount_as_percent, $price_editable)
      ->html('.row_entry:has(#item_' . $item_id . ') [name = "partnumber"] a', $item->part->partnumber)
      ->val ('.row_entry:has(#item_' . $item_id . ') [name = "order.orderitems[].description"]', $item->description)
      ->val ('.row_entry:has(#item_' . $item_id . ') [name = "order.orderitems[].longdescription"]', $item->longdescription);

    if ($self->search_cvpartnumber) {
      $self->get_item_cvpartnumber($item);
      $self->js->html('.row_entry:has(#item_' . $item_id . ') [name = "cvpartnumber"]', $item->{cvpartnumber});
    }
  }

  $self->recalc();
  $self->js_redisplay_line_values;
  $self->js_redisplay_amounts_and_taxes;

  $self->js->render();
}

sub action_save_phone_note {
  my ($self) = @_;

  my $phone_note = $self->parse_phone_note;
  my $is_new     = !$phone_note->id;

  $phone_note->save;
  $self->order(SL::DB::Order->new(id => $self->order->id)->load);

  my $tab_as_html = $self->p->render('order/tabs/phone_notes', SELF => $self);

  return $self->js
    ->replaceWith('#phone-notes', $tab_as_html)
    ->html('#num_phone_notes', (scalar @{$self->order->phone_notes}) ? ' (' . scalar @{$self->order->phone_notes} . ')' : '')
    ->flash('info', $is_new ? t8('Phone note has been created.') : t8('Phone note has been updated.'))
    ->reinit_widgets
    ->render;
}

sub action_delete_phone_note {
  my ($self) = @_;

  my $phone_note = first { $_->id == $::form->{phone_note}->{id} } @{$self->order->phone_notes};

  return $self->js->flash('error', t8('Phone note not found for this order.'))->render if !$phone_note;

  $phone_note->delete;
  $self->order(SL::DB::Order->new(id => $self->order->id)->load);

  my $tab_as_html = $self->p->render('order/tabs/phone_notes', SELF => $self);

  return $self->js
    ->replaceWith('#phone-notes', $tab_as_html)
    ->html('#num_phone_notes', (scalar @{$self->order->phone_notes}) ? ' (' . scalar @{$self->order->phone_notes} . ')' : '')
    ->flash('info', t8('Phone note has been deleted.'))
    ->reinit_widgets
    ->render;
}

sub action_close_quotations {
  my ($self) = @_;

  my @redirect_params = $::form->{callback} ? ($::form->{callback})
                                            : (controller => 'LoginScreen', action => 'user_login');

  if (!$::form->{ids} || !@{$::form->{ids}}) {
    flash_later('info', t8('Nothing selected!'));
    $self->redirect_to(@redirect_params);
    $::dispatcher->end_request;
  }

  my $sales_quotations   = SL::DB::Manager::Order->get_all(where => [id            => $::form->{ids},
                                                                     or             => [closed => 0, closed => undef],
                                                                     record_type    => SALES_QUOTATION_TYPE()]);

  my $request_quotations = SL::DB::Manager::Order->get_all(where => [id            => $::form->{ids},
                                                                     or             => [closed => 0, closed => undef],
                                                                     record_type    => REQUEST_QUOTATION_TYPE()]);

  $::auth->assert('sales_quotation_edit')   if scalar @$sales_quotations;
  $::auth->assert('request_quotation_edit') if scalar @$request_quotations;

  my $employee_id = SL::DB::Manager::Employee->current->id;
  SL::DB->client->with_transaction(sub {
    SL::DB::Manager::Order->update_all(set   => {closed => 1},
                                       where => [id => $::form->{ids}]);

    foreach my $quotation (@$sales_quotations, @$request_quotations) {
      SL::DB::History->new(
        trans_id    => $quotation->id,
        employee_id => $employee_id,
        what_done   => $quotation->type,
        snumbers    => 'quonumber_' . $quotation->number,
        addition    => 'SAVED',
      )->save;
    }

    1;
  }) || do {
    $::form->error(t8('Closing the selected quotations failed: #1', SL::DB->client->error));
  };

  flash_later('info', t8('The selected quotations where closed.'));
  $self->redirect_to(@redirect_params);
}

sub action_show_conversion_to_purchase_delivery_order_item_selection {
  my ($self) = @_;

  my $items = $self->order->items_sorted;

  if (@$items) {
    my @part_ids          = uniq map { $_->{parts_id} } @$items;
    my %parts_by_id       = map { ($_->id => $_) } @{ SL::DB::Manager::Part->get_all(where => [ id => \@part_ids ]) };
    my %make_models_by_id = map { ($_->parts_id => $_->model) } @{
      SL::DB::Manager::MakeModel->get_all(
        where => [
          parts_id => \@part_ids,
          make     => $::form->{order}->{vendor_id},
        ])
    };

    foreach my $item (@$items) {
      $item->{partnumber}        = $parts_by_id{ $item->{parts_id} }->partnumber;
      $item->{vendor_partnumber} = $make_models_by_id{ $item->{parts_id} };
    }
  }

  $self->render(
    'order/tabs/_purchase_delivery_order_item_selection',
    { layout => 0 },
    ITEMS => $items,
  );
}

sub js_load_second_row {
  my ($self, $item, $item_id, $do_parse) = @_;

  if ($do_parse) {
    # Parse values from form (they are formated while rendering (template)).
    # Workaround to pre-parse number-cvars (parse_custom_variable_values does not parse number values).
    # This parsing is not necessary at all, if we assure that the second row/cvars are only loaded once.
    foreach my $var (@{ $item->cvars_by_config }) {
      $var->unparsed_value($::form->parse_amount(\%::myconfig, $var->{__unparsed_value})) if ($var->config->type eq 'number' && exists($var->{__unparsed_value}));
    }
    $item->parse_custom_variable_values;
  }

  my $row_as_html = $self->p->render('order/tabs/_second_row', ITEM => $item, TYPE => $self->type);

  $self->js
    ->html('#second_row_' . $item_id, $row_as_html)
    ->data('#second_row_' . $item_id, 'loaded', 1);
}

sub js_redisplay_line_values {
  my ($self) = @_;

  my $is_sales = $self->order->is_sales;

  # sales orders with margins
  my @data;
  if ($is_sales) {
    @data = map {
      [
       $::form->format_amount(\%::myconfig, $_->{linetotal},     2, 0),
       $::form->format_amount(\%::myconfig, $_->{marge_total},   2, 0),
       $::form->format_amount(\%::myconfig, $_->{marge_percent}, 2, 0),
      ]} @{ $self->order->items_sorted };
  } else {
    @data = map {
      [
       $::form->format_amount(\%::myconfig, $_->{linetotal},     2, 0),
      ]} @{ $self->order->items_sorted };
  }

  $self->js
    ->run('kivi.Order.redisplay_line_values', $is_sales, \@data);
}

sub js_redisplay_amounts_and_taxes {
  my ($self) = @_;

  if (scalar @{ $self->{taxes} }) {
    $self->js->show('#taxincluded_row_id');
  } else {
    $self->js->hide('#taxincluded_row_id');
  }

  if ($self->order->taxincluded) {
    $self->js->hide('#subtotal_row_id');
  } else {
    $self->js->show('#subtotal_row_id');
  }

  if ($self->order->is_sales) {
    my $is_neg = $self->order->marge_total < 0;
    $self->js
      ->html('#marge_total_id',   $::form->format_amount(\%::myconfig, $self->order->marge_total,   2))
      ->html('#marge_percent_id', $::form->format_amount(\%::myconfig, $self->order->marge_percent, 2))
      ->action_if( $is_neg, 'addClass',    '#marge_total_id',        'plus0')
      ->action_if( $is_neg, 'addClass',    '#marge_percent_id',      'plus0')
      ->action_if( $is_neg, 'addClass',    '#marge_percent_sign_id', 'plus0')
      ->action_if(!$is_neg, 'removeClass', '#marge_total_id',        'plus0')
      ->action_if(!$is_neg, 'removeClass', '#marge_percent_id',      'plus0')
      ->action_if(!$is_neg, 'removeClass', '#marge_percent_sign_id', 'plus0');
  }

  $self->js
    ->html('#netamount_id', $::form->format_amount(\%::myconfig, $self->order->netamount, -2))
    ->html('#amount_id',    $::form->format_amount(\%::myconfig, $self->order->amount,    -2))
    ->remove('.tax_row')
    ->insertBefore($self->build_tax_rows, '#amount_row_id');
}

sub js_redisplay_cvpartnumbers {
  my ($self) = @_;

  $self->get_item_cvpartnumber($_) for @{$self->order->items_sorted};

  my @data = map {[$_->{cvpartnumber}]} @{ $self->order->items_sorted };

  $self->js
    ->run('kivi.Order.redisplay_cvpartnumbers', \@data);
}

sub js_reset_order_and_item_ids_after_save {
  my ($self) = @_;

  $self->js
    ->val('#id', $self->order->id)
    ->val('#converted_from_record_type_ref', '')
    ->val('#converted_from_record_id',  '')
    ->val('#order_' . $self->nr_key(), $self->order->number);

  my $idx = 0;
  foreach my $form_item_id (@{ $::form->{orderitem_ids} }) {
    next if !$self->order->items_sorted->[$idx]->id;
    next if $form_item_id !~ m{^new};
    $self->js
      ->val ('[name="orderitem_ids[+]"][value="' . $form_item_id . '"]', $self->order->items_sorted->[$idx]->id)
      ->val ('#item_' . $form_item_id, $self->order->items_sorted->[$idx]->id)
      ->attr('#item_' . $form_item_id, "id", 'item_' . $self->order->items_sorted->[$idx]->id);
  } continue {
    $idx++;
  }
  $self->js->val('[name="converted_from_record_item_type_refs[+]"]', '');
  $self->js->val('[name="converted_from_record_item_ids[+]"]', '');
  $self->js->val('[name="basket_item_ids[+]"]', '');
}

#
# helpers
#

sub init_valid_types {
  $_[0]->type_data->valid_types;
}

sub init_type {
  my ($self) = @_;

  my $type = $self->order->record_type;
  if (none { $type eq $_ } @{$self->valid_types}) {
    die "Not a valid type for order";
  }

  $self->type($type);
}

sub init_cv {
  my ($self) = @_;

  return $self->type_data->properties('customervendor');
}

sub init_search_cvpartnumber {
  my ($self) = @_;

  my $user_prefs = SL::Helper::UserPreferences::PartPickerSearch->new();
  my $search_cvpartnumber;
  $search_cvpartnumber = !!$user_prefs->get_sales_search_customer_partnumber() if $self->cv eq 'customer';
  $search_cvpartnumber = !!$user_prefs->get_purchase_search_makemodel()        if $self->cv eq 'vendor';

  return $search_cvpartnumber;
}

sub init_show_update_button {
  my ($self) = @_;

  !!SL::Helper::UserPreferences::UpdatePositions->new()->get_show_update_button();
}

sub init_p {
  SL::Presenter->get;
}

sub init_order {
  $_[0]->make_order;
}

sub init_all_price_factors {
  SL::DB::Manager::PriceFactor->get_all;
}

sub init_part_picker_classification_ids {
  my ($self)    = @_;

  return [ map { $_->id } @{ SL::DB::Manager::PartClassification->get_all(
    where => $self->type_data->part_classification_query()) } ];
}

sub init_is_final_version {
  # VALID States for current Sales Version
  # 1. save create version without email_id             -> open
  # 2. send email set email_id for version 1            -> final
  # 3. save and subversion new version without email_id -> open
  # 4. send email set email_id for current subversion   -> final
  # for all versions > 1 set postfix -2 .. -n for recordnumber
  return $::instance_conf->get_lock_oe_subversions    ?  # conf enabled
         $_[0]->order->id                             ?  # is saved
         $_[0]->order->is_final_version               :  # is final
         undef                                        :  # is not final
         undef;                                          # conf disabled
}

sub check_auth {
  my ($self) = @_;
  $::auth->assert($self->type_data->rights('view'));
}

sub check_auth_for_edit {
  my ($self) = @_;
  $::auth->assert($self->type_data->rights('edit'));
}

# build the selection box for contacts
#
# Needed, if customer/vendor changed.
sub build_contact_select {
  my ($self) = @_;

  select_tag('order.cp_id', [ $self->order->{$self->cv}->contacts ],
    value_key  => 'cp_id',
    title_key  => 'full_name_dep',
    default    => $self->order->cp_id,
    with_empty => 1,
    style      => 'width: 300px',
  );
}

# build the selection box for the additional billing address
#
# Needed, if customer/vendor changed.
sub build_billing_address_select {
  my ($self) = @_;

  return '' if $self->cv ne 'customer';

  select_tag('order.billing_address_id',
             [ {displayable_id => '', id => ''}, $self->order->{$self->cv}->additional_billing_addresses ],
             value_key  => 'id',
             title_key  => 'displayable_id',
             default    => $self->order->billing_address_id,
             with_empty => 0,
             style      => 'width: 300px',
  );
}

# build the selection box for shiptos
#
# Needed, if customer/vendor changed.
sub build_shipto_select {
  my ($self) = @_;

  select_tag('order.shipto_id',
             [ {displayable_id => t8("No/individual shipping address"), shipto_id => ''}, $self->order->{$self->cv}->shipto ],
             value_key  => 'shipto_id',
             title_key  => 'displayable_id',
             default    => $self->order->shipto_id,
             with_empty => 0,
             style      => 'width: 300px',
  );
}

# build the inputs for the cusom shipto dialog
#
# Needed, if customer/vendor changed.
sub build_shipto_inputs {
  my ($self) = @_;

  my $content = $self->p->render('common/_ship_to_dialog',
                                 vc_obj      => $self->order->customervendor,
                                 cs_obj      => $self->order->custom_shipto,
                                 cvars       => $self->order->custom_shipto->cvars_by_config,
                                 id_selector => '#order_shipto_id');

  div_tag($content, id => 'shipto_inputs');
}

# render the info line for business
#
# Needed, if customer/vendor changed.
sub build_business_info_row
{
  $_[0]->p->render('order/tabs/_business_info_row', SELF => $_[0]);
}

# build the rows for displaying taxes
#
# Called if amounts where recalculated and redisplayed.
sub build_tax_rows {
  my ($self) = @_;

  my $rows_as_html;
  foreach my $tax (sort { $a->{tax}->rate cmp $b->{tax}->rate } @{ $self->{taxes} }) {
    $rows_as_html .= $self->p->render(
      'order/tabs/_tax_row',
      SELF => $self,
      TAX => $tax,
      TAXINCLUDED => $self->order->taxincluded,
      QUOTATION => $self->order->quotation
    );
  }
  return $rows_as_html;
}


sub render_price_dialog {
  my ($self, $record_item) = @_;

  my $price_source = SL::PriceSource->new(record_item => $record_item, record => $self->order);

  $self->js
    ->run(
      'kivi.io.price_chooser_dialog',
      t8('Available Prices'),
      $self->render('order/tabs/_price_sources_dialog', { output => 0 }, price_source => $price_source)
    )
    ->reinit_widgets;

#   if (@errors) {
#     $self->js->text('#dialog_flash_error_content', join ' ', @errors);
#     $self->js->show('#dialog_flash_error');
#   }

  $self->js->render;
}

sub load_order {
  my ($self) = @_;

  return if !$::form->{id};

  $self->order(SL::DB::Order->new(id => $::form->{id})->load);

  $self->reinit_after_new_order();

  return $self->order;
}

# load or create a new order object
#
# And assign changes from the form to this object.
# If the order is loaded from db, check if items are deleted in the form,
# remove them form the object and collect them for removing from db on saving.
# Then create/update items from form (via make_item) and add them.
sub make_order {
  my ($self) = @_;

  # add_items adds items to an order with no items for saving, but they cannot
  # be retrieved via items until the order is saved. Adding empty items to new
  # order here solves this problem.
  my $order;
  if ($::form->{id}) {
    $order   = SL::DB::Order->new(
      id => $::form->{id}
    )->load(
      with => [
        'orderitems',
        'orderitems.part',
      ]
    );
  } else {
    $order = SL::DB::Order->new(
      orderitems  => [],
      record_type => $::form->{type},
      currency_id => $::instance_conf->get_currency_id(),
    );
    $order = SL::Model::Record->update_after_new($order)
  }

  my $cv_id_method = $order->type_data->properties('customervendor'). '_id';
  if (!$::form->{id} && $::form->{$cv_id_method}) {
    $order->$cv_id_method($::form->{$cv_id_method});
    $order = SL::Model::Record->update_after_customer_vendor_change($order);
  }

  # don't assign hashes as objects
  my $form_orderitems               = delete $::form->{order}->{orderitems};
  my $form_periodic_invoices_config = delete $::form->{order}->{periodic_invoices_config};

  $order->assign_attributes(%{$::form->{order}});

  # restore form values
  $::form->{order}->{orderitems}               = $form_orderitems;
  $::form->{order}->{periodic_invoices_config} = $form_periodic_invoices_config;

  $self->setup_custom_shipto_from_form($order, $::form);

  if (
    my $periodic_invoices_config_attrs = $form_periodic_invoices_config ?
        SL::YAML::Load($form_periodic_invoices_config)
      : undef
  ) {
    my $periodic_invoices_config =
         $order->periodic_invoices_config
      || $order->periodic_invoices_config(SL::DB::PeriodicInvoicesConfig->new);
    $periodic_invoices_config->assign_attributes(
      %$periodic_invoices_config_attrs
    );
  }

  # remove deleted items
  $self->item_ids_to_delete([]);
  foreach my $idx (reverse 0..$#{$order->orderitems}) {
    my $item = $order->orderitems->[$idx];
    if (none { $item->id == $_->{id} } @{$form_orderitems}) {
      splice @{$order->orderitems}, $idx, 1;
      push @{$self->item_ids_to_delete}, $item->id;
    }
  }

  my @items;
  my $pos = 1;
  foreach my $form_attr (@{$form_orderitems}) {
    my $item = make_item($order, $form_attr);
    $item->position($pos);
    push @items, $item;
    $pos++;
  }
  $order->add_items(grep {!$_->id} @items);

  return $order;
}

# create or update items from form
#
# Make item objects from form values. For items already existing read from db.
# Create a new item else. And assign attributes.
sub make_item {
  my ($record, $attr) = @_;

  my $item;
  $item = first { $_->id == $attr->{id} } @{$record->items} if $attr->{id};

  my $is_new = !$item;

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $item ||= SL::DB::OrderItem->new(custom_variables => []);

  $item->assign_attributes(%$attr);

  if ($is_new) {
    my $texts = SL::Model::Record->get_part_texts($item->part, $record->language_id);
    $item->longdescription($texts->{longdescription})              if !defined $attr->{longdescription};
    $item->project_id($record->globalproject_id)                   if !defined $attr->{project_id};
    $item->lastcost($record->is_sales ? $item->part->lastcost : 0) if !defined $attr->{lastcost_as_number};
  }

  return $item;
}

# create a new item
#
# This is used to add one item
sub new_item {
  my ($record, $attr) = @_;

  my $item = SL::DB::OrderItem->new;

  # Remove attributes where the user left or set the inputs empty.
  # So these attributes will be undefined and we can distinguish them
  # from zero later on.
  for (qw(qty_as_number sellprice_as_number discount_as_percent)) {
    delete $attr->{$_} if $attr->{$_} eq '';
  }

  $item->assign_attributes(%$attr);
  $item->qty(1.0)                   if !$item->qty;
  $item->unit($item->part->unit)    if !$item->unit;

  my ($price_src, $discount_src) = SL::Model::Record->get_best_price_and_discount_source($record, $item, ignore_given => 0);

  my $texts = SL::Model::Record->get_part_texts($item->part, $record->language_id);

  my %new_attr;
  $new_attr{description}            = $texts->{description}        if ! $item->description;
  $new_attr{qty}                    = 1.0                          if ! $item->qty;
  $new_attr{price_factor_id}        = $item->part->price_factor_id if ! $item->price_factor_id;
  $new_attr{sellprice}              = $price_src->price;
  $new_attr{discount}               = $discount_src->discount;
  $new_attr{active_price_source}    = $price_src;
  $new_attr{active_discount_source} = $discount_src;
  $new_attr{longdescription}        = $texts->{longdescription}    if ! defined $attr->{longdescription};
  $new_attr{project_id}             = $record->globalproject_id;
  $new_attr{lastcost}               = $record->is_sales ? $item->part->lastcost : 0;

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $new_attr{custom_variables} = [];

  $item->assign_attributes(%new_attr);

  return $item;
}

sub get_basket_info_from_from {
  my ($self) = @_;

  my $order = $self->order;
  my $basket_item_ids = $::form->{basket_item_ids};
  if (scalar @{ $basket_item_ids || [] }) {
    for my $idx (0 .. $#{ $order->items_sorted }) {
      my $order_item = $order->items_sorted->[$idx];
      $order_item->{basket_item_id} = $basket_item_ids->[$idx];
    }
  }
}

# setup custom shipto from form
#
# The dialog returns form variables starting with 'shipto' and cvars starting
# with 'shiptocvar_'.
# Mark it to be deleted if a shipto from master data is selected
# (i.e. order has a shipto).
# Else, update or create a new custom shipto. If the fields are empty, it
# will not be saved on save.
sub setup_custom_shipto_from_form {
  my ($self, $order, $form) = @_;

  if ($order->shipto) {
    $self->is_custom_shipto_to_delete(1);
  } else {
    my $custom_shipto =
       $order->custom_shipto
    || $order->custom_shipto(
         SL::DB::Shipto->new(module => 'OE', custom_variables => [])
       );

    my $shipto_cvars  = {map { my ($key) = m{^shiptocvar_(.+)}; $key => delete $form->{$_}} grep { m{^shiptocvar_} } keys %$form};
    my $shipto_attrs  = {map {                                  $_   => delete $form->{$_}} grep { m{^shipto}      } keys %$form};

    $custom_shipto->assign_attributes(%$shipto_attrs);
    $custom_shipto->cvar_by_name($_)->value($shipto_cvars->{$_}) for keys %$shipto_cvars;
  }
}

# recalculate prices and taxes
#
# Using the PriceTaxCalculator. Store linetotals in the item objects.
sub recalc {
  my ($self) = @_;

  my %pat = $self->order->calculate_prices_and_taxes();

  $self->{taxes} = [];
  foreach my $tax_id (keys %{ $pat{taxes_by_tax_id} }) {
    my $netamount = sum0 map { $pat{amounts}->{$_}->{amount} } grep { $pat{amounts}->{$_}->{tax_id} == $tax_id } keys %{ $pat{amounts} };

    push(@{ $self->{taxes} }, { amount    => $pat{taxes_by_tax_id}->{$tax_id},
                                netamount => $netamount,
                                tax       => SL::DB::Tax->new(id => $tax_id)->load });
  }
  pairwise { $a->{linetotal} = $b->{linetotal} } @{$self->order->items_sorted}, @{$pat{items}};
}

# get data for saving, printing, ..., that is not changed in the form
#
# Only cvars for now.
sub get_unalterable_data {
  my ($self) = @_;

  foreach my $item (@{ $self->order->items }) {
    # autovivify all cvars that are not in the form (cvars_by_config can do it).
    # workaround to pre-parse number-cvars (parse_custom_variable_values does not parse number values).
    foreach my $var (@{ $item->cvars_by_config }) {
      $var->unparsed_value($::form->parse_amount(\%::myconfig, $var->{__unparsed_value})) if ($var->config->type eq 'number' && exists($var->{__unparsed_value}));
    }
    $item->parse_custom_variable_values;
  }
}

# parse new or updated phone note
#
# And put them into the order object.
sub parse_phone_note {
  my ($self) = @_;

  if (!$::form->{phone_note}->{subject} || !$::form->{phone_note}->{body}) {
    die t8('Phone note needs a subject and a body.');
  }

  my $phone_note;
  if ($::form->{phone_note}->{id}) {
    $phone_note = first { $_->id == $::form->{phone_note}->{id} } @{$self->order->phone_notes};
    die t8('Phone note not found for this order.') if !$phone_note;
  }

  $phone_note = SL::DB::Note->new() if !$phone_note;
  my $is_new  = !$phone_note->id;

  $phone_note->assign_attributes(%{ $::form->{phone_note} },
                                 trans_id     => $self->order->id,
                                 trans_module => 'oe',
                                 employee     => SL::DB::Manager::Employee->current);

  $self->order->add_phone_notes($phone_note) if $is_new;
  return $phone_note;
}

sub check_if_periodic_invoices_contact_matches_customer {
  my ($self) = @_;

  return if !$self->order->is_type(SL::DB::Order::SALES_ORDER_TYPE());

  my $cfg = SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $self->order->id);
  return if !$cfg || !$cfg->email_recipient_contact_id;

  my $contact = SL::DB::Manager::Contact->find_by(cp_id => $cfg->email_recipient_contact_id);
  return if !$contact;

  if ($contact->cp_cv_id != $self->order->customer_id) {
    $cfg->update_attributes(email_recipient_contact_id => undef);
  }
}

# save the order
#
# And delete items that are deleted in the form.
sub save {
  my ($self) = @_;

  my $is_new = !$self->order->id;

  $self->parse_phone_note if $::form->{phone_note}->{subject} || $::form->{phone_note}->{body};

  # Test for order locked items if they are not wanted for this record type.
  if ($self->type_data->no_order_locked_parts) {
    my @order_locked_positions = map { $_->position } grep { $_->part->order_locked } @{ $self->order->items_sorted };
    die t8('This record contains not orderable items at position #1', join ', ', @order_locked_positions) if @order_locked_positions;
  }

  # create first version if none exists
  $self->order->add_order_version(SL::DB::OrderVersion->new(version => 1)) if !$self->order->order_version;

  set_record_link_conversions($self->order,
    delete $::form->{RECORD_TYPE_REF()}
      => delete $::form->{RECORD_ID()},
    delete $::form->{RECORD_ITEM_TYPE_REF()}
      => delete $::form->{RECORD_ITEM_ID()},
  );

  my @converted_from_oe_ids;
  if ($self->order->{RECORD_TYPE_REF()} eq 'SL::DB::Order'
      && $self->order->{RECORD_ID()}) {
    @converted_from_oe_ids = split ' ', $self->order->{RECORD_ID()};
  }

  # check for purchase basket items
  my %basket_item_id_to_orderitem =
    map { $_->{basket_item_id} => $_ }
    grep { $_->{basket_item_id} ne '' }
    $self->order->orderitems;
  my @basket_item_ids = keys %basket_item_id_to_orderitem;
  if (scalar @basket_item_ids) {
    my $basket_items = SL::DB::Manager::PurchaseBasketItem->get_all(
      where => [ id => \@basket_item_ids ]);
    if (scalar @$basket_items != scalar @basket_item_ids) {
      my %basket_item_exists = map { $_->id => 1 } @$basket_items;
      my @missing_for_positions =
        map { $_->position }
        map { $basket_item_id_to_orderitem{$_} }
        grep { !$basket_item_exists{$_} }
        @basket_item_ids;
      return [t8('Purchase basket item not existing any more for position(s): #1.',
                 join(',', @missing_for_positions))];
    }
  }

  my $objects_to_close = scalar @converted_from_oe_ids
                       ? SL::DB::Manager::Order->get_all(where => [
                           id => \@converted_from_oe_ids,
                           or => [  record_type => SALES_QUOTATION_TYPE(),
                                    record_type => REQUEST_QUOTATION_TYPE(),
                                   (record_type => PURCHASE_QUOTATION_INTAKE_TYPE()) x $self->order->is_type(PURCHASE_ORDER_TYPE()),
                                   (record_type => PURCHASE_ORDER_TYPE())            x $self->order->is_type(PURCHASE_ORDER_CONFIRMATION_TYPE())  ]
                           ])
                       : undef;

  my $items_to_delete  = scalar @{ $self->item_ids_to_delete || [] }
                       ? SL::DB::Manager::OrderItem->get_all(where => [id => $self->item_ids_to_delete])
                       : undef;

  SL::Model::Record->save($self->order,
                          with_validity_token  => { scope => SL::DB::ValidityToken::SCOPE_ORDER_SAVE(), token => $::form->{form_validity_token} },
                          delete_custom_shipto => $self->order->custom_shipto && ($self->is_custom_shipto_to_delete || $self->order->custom_shipto->is_empty),
                          items_to_delete      => $items_to_delete,
                          objects_to_close     => $objects_to_close,
                          link_requirement_specs_linking_to_created_from_objects => \@converted_from_oe_ids,
                          set_project_in_linked_requirement_specs                => 1,
  );

  if ($::form->{email_journal_id}) {
    my $email_journal = SL::DB::EmailJournal->new(
      id => delete $::form->{email_journal_id}
    )->load;
    $email_journal->link_to_record_with_attachment(
      $self->order,
      delete $::form->{email_attachment_id}
    );
  }

  if ($is_new && $self->order->is_sales && $::lx_office_conf{imap_client}->{enabled}) {
    my $imap_client = SL::IMAPClient->new(%{$::lx_office_conf{imap_client}});
    if ($imap_client) {
      $imap_client->create_folder_for_record(record => $self->order);
    }
  }

  $self->check_if_periodic_invoices_contact_matches_customer;

  delete $::form->{form_validity_token};
}

sub reinit_after_new_order {
  my ($self) = @_;

  # change form type
  $::form->{type} = $self->order->type;
  $self->type($self->init_type);
  $self->type_data($self->init_type_data);
  $self->cv($self->init_cv);
  $self->check_auth;

  $self->setup_custom_shipto_from_form($self->order, $::form);

  foreach my $item (@{$self->order->items_sorted}) {
    # set item ids to new fake id, to identify them as new items
    $item->{new_fake_id} = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);

    # trigger rendering values for second row as hidden, because they
    # are loaded only on demand. So we need to keep the values from the
    # source.
    $item->{render_second_row} = 1;
  }

  # Warn on order locked items if they are not wanted for this record type
  if ($self->type_data->no_order_locked_parts) {
    my @order_locked_positions =
      map { $_->position }
      grep { $_->part->order_locked }
      @{ $self->order->items_sorted };
    flash('warning', t8(
        'This record contains not orderable items at position #1',
        join ', ', @order_locked_positions)
    ) if @order_locked_positions;
  }

  $self->get_unalterable_data();
  $self->recalc();
}

sub pre_render {
  my ($self) = @_;

  $self->{all_taxzones}               = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_currencies}             = SL::DB::Manager::Currency->get_all_sorted();
  $self->{all_departments}            = SL::DB::Manager::Department->get_all_sorted();
  $self->{all_languages}              = SL::DB::Manager::Language->get_all_sorted( query => [ or => [ obsolete => 0, id => $self->order->language_id ] ] );
  $self->{all_employees}              = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->order->employee_id,
                                                                                              deleted => 0 ] ],
                                                                           sort_by => 'name');
  $self->{all_salesmen}               = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->order->salesman_id,
                                                                                              deleted => 0 ] ],
                                                                           sort_by => 'name');
  $self->{all_payment_terms}          = SL::DB::Manager::PaymentTerm->get_all_sorted(where => [ or => [ id => $self->order->payment_id,
                                                                                                        obsolete => 0 ] ]);
  $self->{all_delivery_terms}         = SL::DB::Manager::DeliveryTerm->get_valid($self->order->delivery_term_id);
  $self->{all_statuses}               = SL::DB::Manager::OrderStatus->get_all_sorted(where => [ or => [ id => $self->order->order_status_id,
                                                                                                        obsolete => 0,  ] ] );
  $self->{current_employee_id}        = SL::DB::Manager::Employee->current->id;
  $self->{periodic_invoices_status}   = $self->get_periodic_invoices_status($self->order->periodic_invoices_config);
  $self->{order_probabilities}        = [ map { { title => ($_ * 10) . '%', id => $_ * 10 } } (0..10) ];
  $self->{positions_scrollbar_height} = SL::Helper::UserPreferences::PositionsScrollbar->new()->get_height();

  my $print_form = Form->new('');
  $print_form->{type}        = $self->type;
  $print_form->{printers}    = SL::DB::Manager::Printer->get_all_sorted;
  $self->{print_options}     = SL::Helper::PrintOptions->get_print_options(
    form => $print_form,
    options => {dialog_name_prefix => 'print_options.',
                show_headers       => 1,
                no_queue           => 1,
                no_postscript      => 1,
                no_opendocument    => 0,
                no_html            => 0},
  );

  foreach my $item (@{$self->order->orderitems}) {
    my $price_source = SL::PriceSource->new(record_item => $item, record => $self->order);
    $item->active_price_source(   $price_source->price_from_source(   $item->active_price_source   ));
    $item->active_discount_source($price_source->discount_from_source($item->active_discount_source));
  }

  if (any { $self->type eq $_ } (SALES_ORDER_INTAKE_TYPE(), SALES_ORDER_TYPE(), PURCHASE_ORDER_TYPE(), PURCHASE_ORDER_CONFIRMATION_TYPE())) {
    # Calculate shipped qtys here to prevent calling calculate for every item via the items method.
    # Do not use write_to_objects to prevent order->delivered to be set, because this should be
    # the value from db, which can be set manually or is set when linked delivery orders are saved.
    SL::Helper::ShippedQty->new->calculate($self->order)->write_to(\@{$self->order->items});
  }

  if ($self->order->number && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => $self->type,
      number   => $self->order->number,
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $self->{template_args}->{WEBDAV} } = map { { name => $_->filename,
                                                    type => t8('File'),
                                                    link => File::Spec->catfile($_->full_filedescriptor),
                                                } } @all_objects;
  }

  if (   (any { $self->type eq $_ } (SALES_QUOTATION_TYPE(), SALES_ORDER_INTAKE_TYPE(), SALES_ORDER_TYPE()))
      && $::instance_conf->get_transport_cost_reminder_article_number_id ) {
    $self->{template_args}->{transport_cost_reminder_article} = SL::DB::Part->new(id => $::instance_conf->get_transport_cost_reminder_article_number_id)->load;
  }
  $self->{template_args}->{longdescription_dialog_size_percentage} = SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();
  $self->{template_args}->{order_item_input_position} = SL::Helper::UserPreferences::ItemInputPosition->new()->get_order_item_input_position
                                                      // $::instance_conf->get_order_item_input_position;

  $self->get_item_cvpartnumber($_) for @{$self->order->items_sorted};

  $self->{template_args}->{num_phone_notes} = scalar @{ $self->order->phone_notes || [] };

  $::request->{layout}->use_javascript("${_}.js") for qw(kivi.Validator kivi.SalesPurchase kivi.Order kivi.File
                                                         edit_periodic_invoices_config calculate_qty follow_up show_history);
  $self->setup_edit_action_bar;
}

sub setup_edit_action_bar {
  my ($self, %params) = @_;

  my @valid = qw(
    kivi.Order.check_cv
  );
  push @valid, "kivi.Order.check_duplicate_parts" if $::instance_conf->get_order_warn_duplicate_parts;
  push @valid, "kivi.Order.check_valid_reqdate"   if $::instance_conf->get_order_warn_no_deliverydate;
  my @req_trans_cost_art = qw(kivi.Order.check_transport_cost_article_presence) x!!$::instance_conf->get_transport_cost_reminder_article_number_id;
  my @req_cusordnumber   = qw(kivi.Order.check_cusordnumber_presence)           x(( any {$self->type eq $_} (SALES_ORDER_INTAKE_TYPE(), SALES_ORDER_TYPE()) ) && $::instance_conf->get_order_warn_no_cusordnumber);

  my $has_invoice_for_advance_payment;
  if ($self->order->id && $self->type eq SALES_ORDER_TYPE()) {
    my $lr = $self->order->linked_records(direction => 'to', to => ['Invoice']);
    $has_invoice_for_advance_payment = any {'SL::DB::Invoice' eq ref $_ && "invoice_for_advance_payment" eq $_->type} @$lr;
  }

  my $has_final_invoice;
  if ($self->order->id && $self->type eq SALES_ORDER_TYPE()) {
    my $lr = $self->order->linked_records(direction => 'to', to => ['Invoice']);
    $has_final_invoice               = any {'SL::DB::Invoice' eq ref $_ && "final_invoice" eq $_->type} @$lr;
  }

  my $may_edit_create   = $::auth->assert($self->type_data->rights('edit'), 'may fail');

  my $is_final_version = $self->is_final_version;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          call      => [ 'kivi.Order.save', {
              action             => 'save',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices', ['kivi.validate_form','#order_form'],
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : $is_final_version ? t8('This record is the final version. Please create a new sub-version') : undef,
        ],
        action => [
          t8('Save and Close'),
          call      => [ 'kivi.Order.save', {
              action             => 'save',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
              form_params        => [
                { name => 'back_to_caller', value => 1 },
              ],
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices', ['kivi.validate_form','#order_form'],
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : $is_final_version ? t8('This record is the final version. Please create a new sub-version') : undef,
        ],
        action => [
          t8('Create Sub-Version'),
          call      => [ 'kivi.Order.save', { action => 'add_subversion' } ],
          only_if   => $::instance_conf->get_lock_oe_subversions,
          disabled => !$may_edit_create  ? t8('You do not have the permissions to access this function.')
                    : !$is_final_version ? t8('This sub-version is not yet finalized')
                    :                      undef,
        ],
        action => [
          t8('Save as new'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_as_new',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices',
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                     : !$self->order->id ? t8('This object has not been saved yet.')
                     :                     undef,
        ],
      ], # end of combobox "Save"

      combobox => [
        action => [
          t8('Workflow'),
        ],
        action => [
          t8('Save and Quotation'),
          call     => [ 'kivi.submit_ajax_form', $self->url_for(action => "save_and_order_workflow", to_type => SALES_QUOTATION_TYPE()), '#order_form' ],
          checks   => [ @valid, @req_trans_cost_art, @req_cusordnumber ],
          only_if  => $self->type_data->show_menu('save_and_quotation'),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and RFQ'),
          call     => [ 'kivi.Order.purchase_check_for_direct_delivery', { to_type => REQUEST_QUOTATION_TYPE() } ],
          checks   => [ @valid ],
          only_if  => $self->type_data->show_menu('save_and_rfq'),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Purchase Quotation Intake'),
          call     => [ 'kivi.submit_ajax_form', $self->url_for(action => "save_and_order_workflow", to_type => PURCHASE_QUOTATION_INTAKE_TYPE()), '#order_form' ],
          only_if  => $self->type_data->show_menu('save_and_purchase_quotation_intake'),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Sales Order Intake'),
          call     => [ 'kivi.submit_ajax_form', $self->url_for(action => "save_and_order_workflow", to_type => SALES_ORDER_INTAKE_TYPE()), '#order_form' ],
          only_if  => $self->type_data->show_menu('save_and_sales_order_intake'),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Sales Order Confirmation'),
          call     => [ 'kivi.submit_ajax_form', $self->url_for(action => "save_and_order_workflow", to_type => SALES_ORDER_TYPE()), '#order_form' ],
          checks   => [ @valid, @req_trans_cost_art ],
          only_if  => $self->type_data->show_menu('save_and_sales_order'),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Purchase Order'),
          call      => [ 'kivi.Order.purchase_check_for_direct_delivery', { to_type => PURCHASE_ORDER_TYPE() } ],
          checks    => [ @valid, @req_trans_cost_art, @req_cusordnumber ],
          only_if   => $self->type_data->show_menu('save_and_purchase_order'),
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Purchase Order Confirmation'),
          call      => [ 'kivi.Order.purchase_check_for_direct_delivery', { to_type => PURCHASE_ORDER_CONFIRMATION_TYPE() } ],
          checks    => [ @valid, @req_trans_cost_art, @req_cusordnumber ],
          only_if   => $self->type_data->show_menu('save_and_purchase_order_confirmation'),
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Sales Delivery Order'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
              form_params        => [
                { name => 'to_type', value => SALES_DELIVERY_ORDER_TYPE() },
              ],
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices',
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          only_if   => $self->type_data->show_menu('save_and_sales_delivery_order'),
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Purchase Delivery Order'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
              form_params        => [
                { name => 'to_type', value => PURCHASE_DELIVERY_ORDER_TYPE() },
              ],
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices',
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          only_if   => $self->type_data->show_menu('save_and_purchase_delivery_order'),
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Purchase Delivery Order with item selection'),
          call      => [
            'kivi.Order.show_purchase_delivery_order_select_items', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
              form_params        => [
                { name => 'to_type', value => PURCHASE_DELIVERY_ORDER_TYPE() },
              ],
            }],
          checks    => [ @req_trans_cost_art, @req_cusordnumber ],
          only_if   => $self->type_data->show_menu('save_and_purchase_delivery_order'),
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Supplier Delivery Order'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
              form_params        => [
                { name => 'to_type', value => SUPPLIER_DELIVERY_ORDER_TYPE() },
              ],
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices',
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          only_if   => $self->type_data->show_menu('save_and_supplier_delivery_order'),
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Reclamation'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
              form_params        => [
                { name => 'to_type',
                  value => $self->order->is_sales ? SALES_RECLAMATION_TYPE()
                                                  : PURCHASE_RECLAMATION_TYPE() },
              ],
            }],
          only_if   => $self->type_data->show_menu('save_and_reclamation'),
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and Invoice'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_invoice',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices',
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          disabled  => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
          only_if   => $self->type_data->show_menu('save_and_invoice'),
        ],
        action => [
          ($has_invoice_for_advance_payment ? t8('Save and Further Invoice for Advance Payment') : t8('Save and Invoice for Advance Payment')),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_invoice_for_advance_payment',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices',
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          disabled  => !$may_edit_create  ? t8('You do not have the permissions to access this function.')
                     : $has_final_invoice ? t8('This order has already a final invoice.')
                     :                      undef,
          only_if   => $self->type_data->show_menu('save_and_invoice_for_advance_payment'),
        ],
        action => [
          t8('Save and Final Invoice'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_final_invoice',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
            }],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices',
                         @req_trans_cost_art, @req_cusordnumber,
          ],
          disabled  => !$may_edit_create  ? t8('You do not have the permissions to access this function.')
                     : $has_final_invoice ? t8('This order has already a final invoice.')
                     :                      undef,
          only_if   => $self->type_data->show_menu('save_and_final_invoice') && $has_invoice_for_advance_payment,
        ],
        action => [
          t8('Save and AP Transaction'),
          call      => [ 'kivi.Order.save', {
              action             => 'save_and_ap_transaction',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
            }],
          only_if   => $self->type_data->show_menu('save_and_ap_transaction'),
          disabled  => !$may_edit_create  ? t8('You do not have the permissions to access this function.') : undef,
        ],

      ], # end of combobox "Workflow"

      combobox => [
        action => [
          t8('Export'),
        ],
        action => [
          t8('Save and preview PDF'),
          call     => [ 'kivi.Order.save', {
              action             => 'preview_pdf',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
            }],
          checks   => [ @req_trans_cost_art, @req_cusordnumber ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : $is_final_version ? t8('This record is the final version. Please create a new sub-version') : undef,
          only_if  => $self->type_data->show_menu('save_and_print'),
        ],
        action => [
          t8('Save and print'),
          call     => [ 'kivi.Order.show_print_options', { warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
                                                           warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate },
          ],
          checks   => [ @req_trans_cost_art, @req_cusordnumber ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : $is_final_version ? t8('This record is the final version. Please create a new sub-version') : undef,
          only_if  => $self->type_data->show_menu('save_and_print'),
        ],
        action => [
          ($is_final_version ? t8('E-mail') : t8('Save and E-mail')),
          id       => 'save_and_email_action',
          call     => [ 'kivi.Order.save', {
              action             => 'save_and_show_email_dialog',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
            }],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : !$self->order->id ? t8('This object has not been saved yet.')
                    : undef,
          only_if  => $self->type_data->show_menu('save_and_email'),
        ],
        action => [
          t8('Download attachments of all parts'),
          call     => [ 'kivi.File.downloadOrderitemsFiles', $::form->{type}, $::form->{id} ],
          disabled => !$self->order->id ? t8('This object has not been saved yet.') : undef,
          only_if  => $::instance_conf->get_doc_storage,
        ],
      ], # end of combobox "Export"

      action => [
        t8('Delete'),
        call     => [ 'kivi.Order.delete_order' ],
        confirm  => $::locale->text('Do you really want to delete this object?'),
        disabled => !$may_edit_create  ? t8('You do not have the permissions to access this function.')
                  : !$self->order->id  ? t8('This object has not been saved yet.')
                  :                      undef,
        only_if  => $self->type_data->show_menu('delete'),
      ],

      combobox => [
        action => [
          t8('more')
        ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $self->order->id, 'id' ],
          disabled => !$self->order->id ? t8('This record has not been saved yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'kivi.Order.follow_up_window' ],
          disabled => !$self->order->id ? t8('This object has not been saved yet.') : undef,
          only_if  => $::auth->assert('productivity', 1),
        ],
      ], # end of combobox "more"
    );
  }
}

sub generate_doc {
  my ($self, $doc_ref, $params) = @_;

  my $order  = $self->order;
  my @errors = ();

  my $print_form = Form->new('');
  $print_form->{type}        = $order->type;
  $print_form->{formname}    = $params->{formname} || $order->type;
  $print_form->{format}      = $params->{format}   || 'pdf';
  $print_form->{media}       = $params->{media}    || 'file';
  $print_form->{groupitems}  = $params->{groupitems};
  $print_form->{printer_id}  = $params->{printer_id};
  $print_form->{media}       = 'file'                             if $print_form->{media} eq 'screen';

  $order->language($params->{language});
  $order->flatten_to_form($print_form, format_amounts => 1);

  my $template_ext;
  my $template_type;
  if ($print_form->{format} =~ /(opendocument|oasis)/i) {
    $template_ext  = 'odt';
    $template_type = 'OpenDocument';
  } elsif ($print_form->{format} =~ m{html}i) {
    $template_ext  = 'html';
    $template_type = 'HTML';
  }

  # search for the template
  my ($template_file, @template_files) = SL::Helper::CreatePDF->find_template(
    name        => $print_form->{formname},
    extension   => $template_ext,
    email       => $print_form->{media} eq 'email',
    language    => $params->{language},
    printer_id  => $print_form->{printer_id},
  );

  if (!defined $template_file) {
    push @errors, $::locale->text('Cannot find matching template for this print request. Please contact your template maintainer. I tried these: #1.', join ', ', map { "'$_'"} @template_files);
  }

  return @errors if scalar @errors;

  $print_form->throw_on_error(sub {
    eval {
      $print_form->prepare_for_printing;

      $$doc_ref = SL::Helper::CreatePDF->create_pdf(
        format        => $print_form->{format},
        template_type => $template_type,
        template      => $template_file,
        variables     => $print_form,
        variable_content_types => {
          longdescription => 'html',
          partnotes       => 'html',
          notes           => 'html',
          $::form->get_variable_content_types_for_cvars,
        },
      );
      1;
    } || push @errors, ref($EVAL_ERROR) eq 'SL::X::FormError' ? $EVAL_ERROR->error : $EVAL_ERROR;
  });

  return @errors;
}

sub get_files_for_email_dialog {
  my ($self) = @_;

  my %files = map { ($_ => []) } qw(versions files vc_files part_files);

  return %files if !$::instance_conf->get_doc_storage;

  if ($self->order->id) {
    $files{versions} = [ SL::File->get_all_versions(object_id => $self->order->id,              object_type => $self->order->type, file_type => 'document') ];
    $files{files}    = [ SL::File->get_all(         object_id => $self->order->id,              object_type => $self->order->type, file_type => 'attachment') ];
    $files{vc_files} = [ SL::File->get_all(         object_id => $self->order->{$self->cv}->id, object_type => $self->cv,          file_type => 'attachment') ];
    $files{project_files} = [ SL::File->get_all(    object_id => $self->order->globalproject_id, object_type => 'project',         file_type => 'attachment') ];
  }

  my @parts =
    uniq_by { $_->{id} }
    map {
      +{ id         => $_->part->id,
         partnumber => $_->part->partnumber }
    } @{$self->order->items_sorted};

  foreach my $part (@parts) {
    my @pfiles = SL::File->get_all(object_id => $part->{id}, object_type => 'part');
    push @{ $files{part_files} }, map { +{ %{ $_ }, partnumber => $part->{partnumber} } } @pfiles;
  }

  foreach my $key (keys %files) {
    $files{$key} = [ sort_by { lc $_->{db_file}->{file_name} } @{ $files{$key} } ];
  }

  return %files;
}

sub make_periodic_invoices_config_from_yaml {
  my ($yaml_config) = @_;

  return if !$yaml_config;
  my $attr = SL::YAML::Load($yaml_config);
  return if 'HASH' ne ref $attr;
  return SL::DB::PeriodicInvoicesConfig->new(%$attr);
}


sub get_periodic_invoices_status {
  my ($self, $config) = @_;

  return                      if $self->type ne SALES_ORDER_TYPE();
  return t8('not configured') if !$config;

  my $active = ('HASH' eq ref $config)                           ? $config->{active}
             : ('SL::DB::PeriodicInvoicesConfig' eq ref $config) ? $config->active
             :                                                     die "Cannot get status of periodic invoices config";

  return $active ? t8('active') : t8('inactive');
}

sub get_item_cvpartnumber {
  my ($self, $item) = @_;

  return if !$self->search_cvpartnumber;
  return if !$self->order->customervendor;

  if ($self->cv eq 'vendor') {
    my @mms = grep { $_->make eq $self->order->customervendor->id } @{$item->part->makemodels};
    $item->{cvpartnumber} = $mms[0]->model if scalar @mms;
  } elsif ($self->cv eq 'customer') {
    my @cps = grep { $_->customer_id eq $self->order->customervendor->id } @{$item->part->customerprices};
    $item->{cvpartnumber} = $cps[0]->customer_partnumber if scalar @cps;
  }
}

sub nr_key {
  my ($self) = @_;

  return $self->type_data->properties('nr_key');
}

sub save_and_redirect_to {
  my ($self, %params) = @_;

  $self->save();

  flash_later('info', $self->type_data->text('saved'));

  $self->redirect_to(%params, id => $self->order->id);
}

sub save_history {
  my ($self, $addition) = @_;

  my $number_type = $self->order->type =~ m{order} ? 'ordnumber' : 'quonumber';
  my $snumbers    = $number_type . '_' . $self->order->$number_type;

  SL::DB::History->new(
    trans_id    => $self->order->id,
    employee_id => SL::DB::Manager::Employee->current->id,
    what_done   => $self->order->type,
    snumbers    => $snumbers,
    addition    => $addition,
  )->save;
}

sub store_doc_to_webdav_and_filemanagement {
  my ($self, $content, $filename, $variant) = @_;

  my $order = $self->order;
  my @errors;

  # copy file to webdav folder
  if ($order->number && $::instance_conf->get_webdav_documents) {
    my $webdav = SL::Webdav->new(
      type     => $order->type,
      number   => $order->number,
    );
    my $webdav_file = SL::Webdav::File->new(
      webdav   => $webdav,
      filename => $filename,
    );
    eval {
      $webdav_file->store(data => \$content);
      1;
    } or do {
      push @errors, t8('Storing the document to the WebDAV folder failed: #1', $@);
    };
  }
  my $file_obj;
  if ($order->id && $::instance_conf->get_doc_storage) {
    eval {
      $file_obj = SL::File->save(object_id     => $order->id,
                                 object_type   => $order->type,
                                 mime_type     => SL::MIME->mime_type_from_ext($filename),
                                 source        => 'created',
                                 file_type     => 'document',
                                 file_name     => $filename,
                                 file_contents => $content,
                                 print_variant => $variant);

      $self->{file_id}  = $file_obj->id;
      1;
    } or do {
      push @errors, t8('Storing the document in the storage backend failed: #1', $@);
    };
  }

  return @errors;
}

sub init_type_data {
  my ($self) = @_;
  SL::DB::Helper::TypeDataProxy->new('SL::DB::Order', $self->order->record_type);
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Order - controller for orders

=head1 SYNOPSIS

This is a new form to enter orders, completely rewritten with the use
of controller and java script techniques.

The aim is to provide the user a better experience and a faster workflow. Also
the code should be more readable, more reliable and better to maintain.

=head2 Key Features

=over 4

=item *

One input row, so that input happens every time at the same place.

=item *

Use of pickers where possible.

=item *

Possibility to enter more than one item at once.

=item *

Item list in a scrollable area, so that the workflow buttons stay at
the bottom.

=item *

Reordering item rows with drag and drop is possible. Sorting item rows is
possible (by partnumber, description, qty, sellprice and discount for now).

=item *

No C<update> is necessary. All entries and calculations are managed
with ajax-calls and the page only reloads on C<save>.

=item *

User can see changes immediately, because of the use of java script
and ajax.

=back

=head1 CODE

=head2 Layout

=over 4

=item * C<SL/Controller/Order.pm>

the controller

=item * C<template/webpages/order/form.html>

main form

=item * C<template/webpages/order/tabs/basic_data.html>

Main tab for basic_data.

This is the only tab here for now. "linked records" and "webdav" tabs are
reused from generic code.

=over 4

=item * C<template/webpages/order/tabs/_business_info_row.html>

For displaying information on business type

=item * C<template/webpages/order/tabs/_item_input.html>

The input line for items

=item * C<template/webpages/order/tabs/_row.html>

One row for already entered items

=item * C<template/webpages/order/tabs/_tax_row.html>

Displaying tax information

=item * C<template/webpages/order/tabs/_price_sources_dialog.html>

Dialog for selecting price and discount sources

=back

=item * C<js/kivi.Order.js>

java script functions

=back

=head1 TODO

=over 4

=item * testing

=item * price sources: little symbols showing better price / better discount

=item * select units in input row?

=item * check for direct delivery (workflow sales order -> purchase order)

=item * access rights

=item * display weights

=item * mtime check

=item * optional client/user behaviour

(transactions has to be set - department has to be set -
 force project if enabled in client config)

=back

=head1 KNOWN BUGS AND CAVEATS

=over 4

=item *

No indication that <shift>-up/down expands/collapses second row.

=item *

Table header is not sticky in the scrolling area.

=item *

Sorting does not include C<position>, neither does reordering.

This behavior was implemented intentionally. But we can discuss, which behavior
should be implemented.

=back

=head1 To discuss / Nice to have

=over 4

=item *

How to expand/collapse second row. Now it can be done clicking the icon or
<shift>-up/down.

=item *

This controller uses a (changed) copy of the template for the PriceSource
dialog. Maybe there could be used one code source.

=item *

Rounding-differences between this controller (PriceTaxCalculator) and the old
form. This is not only a problem here, but also in all parts using the PTC.
There exists a ticket and a patch. This patch should be testet.

=item *

An indicator, if the actual inputs are saved (like in an
editor or on text processing application).

=item *

A warning when leaving the page without saving unchanged inputs.


=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
