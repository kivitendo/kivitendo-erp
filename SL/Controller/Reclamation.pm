package SL::Controller::Reclamation;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash_later);
use SL::HTML::Util;
use SL::Presenter::Tag qw(select_tag hidden_tag div_tag);
use SL::Presenter::ReclamationFilter qw(filter);
use SL::Locale::String qw(t8);
use SL::SessionFile::Random;
use SL::PriceSource;
use SL::ReportGenerator;
use SL::Controller::Helper::ReportGenerator;
use SL::Webdav;
use SL::File;
use SL::MIME;
use SL::Util qw(trim);
use SL::YAML;
use SL::DB::History;
use SL::DB::Reclamation;
use SL::DB::ReclamationItem;
use SL::DB::Default;
use SL::DB::Printer;
use SL::DB::Language;
use SL::DB::RecordLink;
use SL::DB::Shipto;
use SL::DB::Translation;
use SL::DB::ValidityToken;
use SL::DB::EmailJournal;
use SL::DB::Helper::RecordLink qw(set_record_link_conversions RECORD_ID RECORD_TYPE_REF RECORD_ITEM_ID RECORD_ITEM_TYPE_REF);
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Helper::Record qw(get_object_name_from_type get_class_from_type);

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;
use SL::Helper::UserPreferences::PositionsScrollbar;
use SL::Helper::UserPreferences::UpdatePositions;

use SL::Controller::Helper::GetModels;

use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Invoice;
use SL::Model::Record;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Reclamation::TypeData qw(:types);

use List::Util qw(first sum0);
use List::UtilsBy qw(sort_by uniq_by);
use List::MoreUtils qw(any none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;
use Cwd;
use Sort::Naturally;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(item_ids_to_delete is_custom_shipto_to_delete) ],
 'scalar --get_set_init' => [qw(
    all_price_factors cv models p part_picker_classification_ids reclamation
    search_cvpartnumber show_update_button type valid_types type_data
 )],
);


# safety
__PACKAGE__->run_before('check_auth');

__PACKAGE__->run_before('recalc',
                        only => [qw(
                          save save_as_new print preview_pdf send_email
                          save_and_show_email_dialog
                          save_and_new_record
                          save_and_credit_note
                       )]);

__PACKAGE__->run_before('get_unalterable_data',
                        only => [qw(
                          save save_as_new print preview_pdf send_email
                          save_and_show_email_dialog
                          save_and_new_record
                          save_and_credit_note
                        )]);

#
# actions
#

# add a new reclamation
sub action_add {
  my ($self) = @_;

  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_RECLAMATION_SAVE())->token;
  }

  $self->render(
    'reclamation/form',
    title => $self->type_data->text('add'),
    %{$self->{template_args}},
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
  my $reclamation = SL::Model::Record->new_from_workflow($record, $self->type, %flags);
  $self->reclamation($reclamation);
  $self->reinit_after_new_reclamation();

  if ($record->type eq SALES_RECLAMATION_TYPE()) { # check for direct delivery
    # copy shipto in custom shipto (custom shipto will be copied by new_from() in case)
    if ($::form->{use_shipto}) {
      my $custom_shipto = $record->shipto->clone('SL::DB::Reclamation');
      $self->reclamation->custom_shipto($custom_shipto) if $custom_shipto;
    } else {
      # remove any custom shipto if not wanted
      $self->reclamation->custom_shipto(SL::DB::Shipto->new(module => 'RC', custom_variables => []));
    }
  }

  $self->action_add;
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

# edit an existing reclamation
sub action_edit {
  my ($self) = @_;
  die "No 'id' was given." unless $::form->{id};

  $self->load_reclamation();

  $self->pre_render();
  $self->render(
    'reclamation/form',
    title => $self->type_data->text('edit'),
    %{$self->{template_args}},
  );
}

# delete the reclamation
sub action_delete {
  my ($self) = @_;


  SL::Model::Record->delete($self->reclamation);
  flash_later('info', $self->type_data->text('delete'));

  my @redirect_params = (
    action => 'add',
    type   => $self->type,
  );

  $self->redirect_to(@redirect_params);
}

# save the reclamation
sub action_save {
  my ($self) = @_;

  $self->save();

  flash_later('info', t8('The reclamation has been saved'));

  my @redirect_params;
  if ($::form->{back_to_caller}) {
    @redirect_params = $::form->{callback} ? ($::form->{callback})
                                           : (controller => 'LoginScreen', action => 'user_login');
  } else {
    @redirect_params = (
      action => 'edit',
      type   => $self->type,
      id     => $self->reclamation->id,
      callback => $::form->{callback},
    );
  }

  $self->redirect_to(@redirect_params);
}

sub action_list {
  my ($self) = @_;

  $self->_setup_search_action_bar;
  $self->prepare_report;
  $self->report_generator_list_objects(
    report => $self->{report},
    objects => $self->models->get,
    options => {
      action_bar_additional_submit_values => {
        type => $self->type,
      },
    },
  );
}

# save the reclamation as new document an open it for edit
sub action_save_as_new {
  my ($self) = @_;

  my $reclamation = $self->reclamation;

  if (!$reclamation->id) {
    $self->js->flash('error', t8('This object has not been saved yet.'));
    return $self->js->render();
  }

  my $saved_reclamation = SL::DB::Reclamation->new(id => $reclamation->id)->load;

  # Create new record from current one
  my $new_reclamation = SL::Model::Record->clone_for_save_as_new($saved_reclamation, $reclamation);
  $self->reclamation($new_reclamation);

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_RECLAMATION_SAVE())->token;
  }

  # save
  $self->action_save();
}

# print the reclamation
#
# This is called if "print" is pressed in the print dialog.
# If PDF creation was requested and succeeded, the pdf is offered for download
# via send_file (which uses ajax in this case).
sub action_print {
  my ($self) = @_;

  $self->save();

  $self->js_reset_reclamation_and_item_ids_after_save;

  my $format      = $::form->{print_options}->{format};
  my $media       = $::form->{print_options}->{media};
  my $formname    = $::form->{print_options}->{formname};
  my $copies      = $::form->{print_options}->{copies};
  my $groupitems  = $::form->{print_options}->{groupitems};
  my $printer_id  = $::form->{print_options}->{printer_id};

  # only pdf and opendocument by now
  if (none { $format eq $_ } qw(pdf opendocument opendocument_pdf)) {
    return $self->js->flash('error', t8('Format \'#1\' is not supported yet/anymore.', $format))->render;
  }

  # only screen or printer by now
  if (none { $media eq $_ } qw(screen printer)) {
    return $self->js->flash('error', t8('Media \'#1\' is not supported yet/anymore.', $media))->render;
  }

  # create a form for generate_attachment_filename
  my $form   = Form->new;
  $form->{record_number} = $self->reclamation->record_number;
  $form->{type}          = $self->type;
  $form->{format}        = $format;
  $form->{formname}      = $formname;
  $form->{language}      = '_' . $self->reclamation->language->template_code if $self->reclamation->language;
  my $pdf_filename       = $form->generate_attachment_filename();

  my $pdf;
  my @errors = generate_pdf($self->reclamation, \$pdf, {
                              format     => $format,
                              formname   => $formname,
                              language   => $self->reclamation->language,
                              printer_id => $printer_id,
                              groupitems => $groupitems,
                            });
  if (scalar @errors) {
    return $self->js->flash('error', t8('Conversion to PDF failed: #1', $errors[0]))->render;
  }

  if ($media eq 'screen') { # screen/download
    $self->js->flash('info', t8('The PDF has been created'));
    $self->send_file(
      \$pdf,
      type         => SL::MIME->mime_type_from_ext($pdf_filename),
      name         => $pdf_filename,
      js_no_render => 1,
    );
  } elsif ($media eq 'printer') { # printer
    my $printer_id = $::form->{print_options}->{printer_id};
    SL::DB::Printer->new(id => $printer_id)->load->print_document(
      copies  => $copies,
      content => $pdf,
    );
    $self->js->flash('info', t8('The PDF has been printed'));
  }

  my @warnings = store_pdf_to_webdav_and_filemanagement($self->reclamation, $pdf, $pdf_filename);
  if (scalar @warnings) {
    $self->js->flash('warning', $_) for @warnings;
  }

  $self->save_history('PRINTED');

  $self->js
    ->run('kivi.ActionBar.setEnabled', '#save_and_email_action')
    ->render;
}

sub action_preview_pdf {
  my ($self) = @_;

  $self->save();

  $self->js_reset_reclamation_and_item_ids_after_save;

  my $format      = 'pdf';
  my $media       = 'screen';
  my $formname    = $self->type;

  # only pdf
  # create a form for generate_attachment_filename
  my $form   = Form->new;
  $form->{record_number} = $self->reclamation->record_number;
  $form->{type}          = $self->type;
  $form->{format}        = $format;
  $form->{formname}      = $formname;
  $form->{language}      = '_' . $self->reclamation->language->template_code if $self->reclamation->language;
  my $pdf_filename       = $form->generate_attachment_filename();

  my $pdf;
  my @errors = generate_pdf($self->reclamation, \$pdf, {
                             format     => $format,
                             formname   => $formname,
                             language   => $self->reclamation->language,
                           });
  if (scalar @errors) {
    return $self->js->flash('error', t8('Conversion to PDF failed: #1', $errors[0]))->render;
  }
  $self->save_history('PREVIEWED');
  $self->js->flash('info', t8('The PDF has been previewed'));
  # screen/download
  $self->send_file(
    \$pdf,
    type         => SL::MIME->mime_type_from_ext($pdf_filename),
    name         => $pdf_filename,
    js_no_render => 0,
  );
}

# open the email dialog
sub action_save_and_show_email_dialog {
  my ($self) = @_;

  $self->save();
  $self->js_reset_reclamation_and_item_ids_after_save;

  my $cv = $self->reclamation->customervendor
    or return $self->js->flash('error',
      $self->type_data->properties('is_customer') ?
          t8('Cannot send E-mail without customer given')
        : t8('Cannot send E-mail without vendor given')
    )->render($self);

  my $form = Form->new;
  $form->{record_number}    = $self->reclamation->record_number;
  $form->{cv_record_number} = $self->reclamation->cv_record_number;
  $form->{formname}         = $self->type;
  $form->{type}             = $self->type;
  $form->{language}         = '_' . $self->reclamation->language->template_code if $self->reclamation->language;
  $form->{language_id}      = $self->reclamation->language->id                  if $self->reclamation->language;
  $form->{format}           = 'pdf';
  $form->{cp_id}            = $self->reclamation->contact->cp_id if $self->reclamation->contact;

  my $email_form;
  $email_form->{to} =
       ($self->reclamation->contact ? $self->reclamation->contact->cp_email : undef)
    ||  $cv->email;
  $email_form->{cc}  = $cv->cc;
  $email_form->{bcc} = join ', ', grep $_, $cv->bcc;
  # TODO: get addresses from shipto, if any
  $email_form->{subject}             = $form->generate_email_subject();
  $email_form->{attachment_filename} = $form->generate_attachment_filename();
  $email_form->{message}             = $form->generate_email_body();
  $email_form->{js_send_function}    = 'kivi.Reclamation.send_email()';

  my %files = $self->get_files_for_email_dialog();

  my @employees_with_email = grep {
    my $user = SL::DB::Manager::AuthUser->find_by(login => $_->login);
    $user && !!trim($user->get_config_value('email'));
  } @{ SL::DB::Manager::Employee->get_all_sorted(query => [ deleted => 0 ]) };

  my $dialog_html = $self->render(
    'common/_send_email_dialog', { output => 0 },
    email_form  => $email_form,
    show_bcc    => $::auth->assert('email_bcc', 'may fail'),
    FILES       => \%files,
    is_customer => $self->type_data->properties('is_customer'),
    ALL_EMPLOYEES => \@employees_with_email,
    ALL_PARTNER_EMAIL_ADDRESSES => $cv->get_all_email_addresses(),
  );

  $self->js
    ->run('kivi.Reclamation.show_email_dialog', $dialog_html)
    ->reinit_widgets
    ->render($self);
}

# send email
sub action_send_email {
  my ($self) = @_;

  eval {
    $self->save();
    1;
  } or do {
    $self->js->run('kivi.Reclamation.close_email_dialog');
    die $EVAL_ERROR;
  };

  my @redirect_params = (
    action => 'edit',
    type   => $self->type,
    id     => $self->reclamation->id,
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

  $::form->{$_}     = $::form->{print_options}->{$_} for keys %{$::form->{print_options}};
  $::form->{media}  = 'email';

  $::form->{attachment_policy} //= '';

  # Is an old file version available?
  my $attfile;
  if ($::form->{attachment_policy} eq 'old_file') {
    $attfile = SL::File->get_all(
      object_id     => $self->reclamaiton->id,
      object_type   => $self->type,
      print_variant => $::form->{formname},
    );
  }

  if (   $::form->{attachment_policy} ne 'no_file'
    && !($::form->{attachment_policy} eq 'old_file' && $attfile)
  ) {
    my $pdf;
    my @errors = generate_pdf(
      $self->reclamation, \$pdf, {
        media      => $::form->{media},
        format     => $::form->{print_options}->{format},
        formname   => $::form->{print_options}->{formname},
        language   => $self->reclamation->language,
        printer_id => $::form->{print_options}->{printer_id},
        groupitems => $::form->{print_options}->{groupitems},
      });
    if (scalar @errors) {
      $::form->error(t8('Generating the document failed: #1', $errors[0]));
    }

    my @warnings = store_pdf_to_webdav_and_filemanagement(
      $self->reclamation, $pdf, $::form->{attachment_filename}
    );
    if (scalar @warnings) {
      flash_later('warning', $_) for @warnings;
    }

    my $sfile = SL::SessionFile::Random->new(mode => "w");
    $sfile->fh->print($pdf);
    $sfile->fh->close;

    $::form->{tmpfile} = $sfile->file_name;
    $::form->{tmpdir}  = $sfile->get_path; # for Form::cleanup which may be
                                           # called in Form::send_email
  }

  $::form->{id} = $self->reclamation->id; # this is used in SL::Mailer to
                                          # create a linked record to the mail
  $::form->send_email(\%::myconfig, 'pdf');

  flash_later('info', t8('The email has been sent.'));
  $self->save_history('MAILED');

  # internal notes unless no email journal
  unless ($::instance_conf->get_email_journal) {
    my $intnotes = $self->reclamation->intnotes;
    $intnotes   .= "\n\n" if $self->reclamation->intnotes;
    $intnotes   .= t8('[email]')                                       . "\n";
    $intnotes   .= t8('Date')       . ": " . $::locale->format_date_object(
                                               DateTime->now_local,
                                               precision => 'seconds') . "\n";
    $intnotes   .= t8('To (email)') . ": " . $::form->{email}          . "\n";
    $intnotes   .= t8('Cc')         . ": " . $::form->{cc}             . "\n"    if $::form->{cc};
    $intnotes   .= t8('Bcc')        . ": " . $::form->{bcc}            . "\n"    if $::form->{bcc};
    $intnotes   .= t8('Subject')    . ": " . $::form->{subject}        . "\n\n";
    $intnotes   .= t8('Message')    . ": " . SL::HTML::Util->strip($::form->{message});

    $self->reclamation->update_attributes(intnotes => $intnotes);
  }

  $self->redirect_to(@redirect_params);
}

sub action_save_and_new_record {
  my ($self) = @_;
  my $to_type = $::form->{to_type};
  my $to_controller = get_object_name_from_type($to_type);

  $self->save();
  flash_later('info', t8('The reclamation has been saved'));

  my %additional_params = ();
  if ($::form->{only_selected_item_positions}) { # ids can be unset before save
    my $item_positions = $::form->{selected_item_positions} || [];
    my @from_item_ids = map { $self->reclamation->items_sorted->[$_]->id } @$item_positions;
    $additional_params{from_item_ids} = \@from_item_ids;
  }

  $self->redirect_to(
    controller => $to_controller,
    action     => 'add_from_record',
    type       => $to_type,
    from_id    => $self->reclamation->id,
    from_type  => $self->reclamation->type,
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
    %additional_params,
  );
}

# save the reclamation and redirect to the frontend subroutine for a new
# credit_note
sub action_save_and_credit_note {
  my ($self) = @_;

  # always save
  $self->save();

  if (!$self->reclamation->is_sales) {
    $self->js->flash('error', t8("Can't convert Purchase Reclamation to Credit Note"));
    return $self->js->render();
  }

  flash_later('info', t8('The reclamation has been saved'));
  $self->redirect_to(
    controller => 'is.pl',
    action     => 'credit_note_from_reclamation',
    from_id    => $self->reclamation->id,
    email_journal_id    => $::form->{workflow_email_journal_id},
    email_attachment_id => $::form->{workflow_email_attachment_id},
    callback            => $::form->{workflow_email_callback},
  );
}

# set form elements in respect to a changed customer or vendor
#
# This action is called on an change of the customer/vendor picker.
sub action_customer_vendor_changed {
  my ($self) = @_;

  $self->reclamation(
    SL::Model::Record->update_after_customer_vendor_change($self->reclamation));

  $self->recalc();

  if ( $self->reclamation->customervendor->contacts
       && scalar @{ $self->reclamation->customervendor->contacts } > 0) {
    $self->js->show('#cp_row');
  } else {
    $self->js->hide('#cp_row');
  }

  if ($self->reclamation->customervendor->shipto
      && scalar @{ $self->reclamation->customervendor->shipto } > 0) {
    $self->js->show('#shipto_selection');
  } else {
    $self->js->hide('#shipto_selection');
  }

  $self->js->val( '#reclamation_salesman_id', $self->reclamation->salesman_id) if $self->reclamation->is_sales;

  $self->js
    ->replaceWith('#reclamation_cp_id',            $self->build_contact_select)
    ->replaceWith('#reclamation_shipto_id',        $self->build_shipto_select)
    ->replaceWith('#shipto_inputs  ',              $self->build_shipto_inputs)
    ->replaceWith('#business_info_row',            $self->build_business_info_row)
    ->val(        '#reclamation_taxzone_id',       $self->reclamation->taxzone_id)
    ->val(        '#reclamation_taxincluded',      $self->reclamation->taxincluded)
    ->val(        '#reclamation_currency_id',      $self->reclamation->currency_id)
    ->val(        '#reclamation_payment_id',       $self->reclamation->payment_id)
    ->val(        '#reclamation_delivery_term_id', $self->reclamation->delivery_term_id)
    ->val(        '#reclamation_intnotes',         $self->reclamation->intnotes)
    ->val(        '#reclamation_language_id',      $self->reclamation->customervendor->language_id)
    ->focus(      '#reclamation_' . $self->cv . '_id')
    ->run('kivi.Reclamation.update_exchangerate');

  $self->js_redisplay_amounts_and_taxes;
  $self->js_redisplay_cvpartnumbers;
  $self->js->render();
}

# called if a unit in an existing item row is changed
sub action_unit_changed {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{reclamationitem_ids} };
  my $item = $self->reclamation->items_sorted->[$idx];

  my $old_unit_obj = SL::DB::Unit->new(name => $::form->{old_unit})->load;
  $item->sellprice($item->unit_obj->convert_to($item->sellprice, $old_unit_obj));

  $self->recalc();

  $self->js
    ->run('kivi.Reclamation.update_sellprice', $::form->{item_id}, $item->sellprice_as_number);
  $self->js_redisplay_line_values;
  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# add an item row for a new item entered in the input row
sub action_add_item {
  my ($self) = @_;

  delete $::form->{add_item}->{create_part_type};

  my $form_attr = $::form->{add_item};

  unless ($form_attr->{parts_id}) {
    $self->js->flash('error', t8("No part was selected."));
    return $self->js->render();
  }


  my $item = new_item($self->reclamation, $form_attr);

  $self->reclamation->add_items($item);

  $self->recalc();

  $self->get_item_cvpartnumber($item);

  my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $row_as_html = $self->p->render('reclamation/tabs/basic_data/_row',
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

  if ( $item->part->is_assortment ) {
    $form_attr->{qty_as_number} = 1 unless $form_attr->{qty_as_number};
    foreach my $assortment_item ( @{$item->part->assortment_items} ) {
      my $attr = { parts_id => $assortment_item->parts_id,
                   qty      => $assortment_item->qty * $::form->parse_amount(\%::myconfig, $form_attr->{qty_as_number}), # TODO $form_attr->{unit}
                   unit     => $assortment_item->unit,
                   description => $assortment_item->part->description,
                 };
      my $item = new_item($self->reclamation, $attr);

      # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
      $item->discount(1) unless $assortment_item->charge;

      $self->reclamation->add_items( $item );
      $self->recalc();
      $self->get_item_cvpartnumber($item);
      my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
      my $row_as_html = $self->p->render('reclamation/tabs/basic_data/_row',
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
    };
  };

  $self->js
    ->val('.add_item_input', '')
    ->run('kivi.Reclamation.init_row_handlers')
    ->run('kivi.Reclamation.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.Reclamation.row_table_scroll_down') if !$::form->{insert_before_item_id};

  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# add item rows for multiple items at once
sub action_add_multi_items {
  my ($self) = @_;

  my @form_attr = grep { $_->{qty_as_number} } @{ $::form->{add_items} };
  unless (scalar(@form_attr)) {
    $self->js->flash('error', t8("No part was selected."));
    return $self->js->render();
  }

  my @items;
  foreach my $attr (@form_attr) {
    my $item = new_item($self->reclamation, $attr);
    push @items, $item;
    if ( $item->part->is_assortment ) {
      foreach my $assortment_item ( @{$item->part->assortment_items} ) {
        my $attr = { parts_id => $assortment_item->parts_id,
                     qty      => $assortment_item->qty * $item->qty, # TODO $form_attr->{unit}
                     unit     => $assortment_item->unit,
                     description => $assortment_item->part->description,
                   };
        my $item = new_item($self->reclamation, $attr);

        # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
        $item->discount(1) unless $assortment_item->charge;
        push @items, $item;
      }
    }
  }
  $self->reclamation->add_items(@items);

  $self->recalc();

  foreach my $item (@items) {
    $self->get_item_cvpartnumber($item);
    my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
    my $row_as_html = $self->p->render('reclamation/tabs/basic_data/_row',
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
    ->run('kivi.Reclamation.init_row_handlers')
    ->run('kivi.Reclamation.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.Reclamation.row_table_scroll_down') if !$::form->{insert_before_item_id};

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
    is_standard   => $self->reclamation->currency_id == $::instance_conf->get_currency_id,
    currency_name => $self->reclamation->currency->name,
    exchangerate  => $self->reclamation->daily_exchangerate_as_null_number,
  };

  $self->render(\SL::JSON::to_json($data), { type => 'json', process => 0 });
}

# redisplay item rows if they are sorted by an attribute
sub action_reorder_items {
  my ($self) = @_;

  my %sort_keys = (
    partnumber   => sub { $_[0]->part->partnumber },
    description  => sub { $_[0]->description },
    reason       => sub { $_[0]->reason eq undef ? "" : $_[0]->reason->name },
    reason_description_ext => sub { $_[0]->reason_description_ext },
    reason_description_int => sub { $_[0]->reason_description_int },
    qty          => sub { $_[0]->qty },
    sellprice    => sub { $_[0]->sellprice },
    discount     => sub { $_[0]->discount },
    cvpartnumber => sub { $_[0]->{cvpartnumber} },
  );

  $self->get_item_cvpartnumber($_) for @{$self->reclamation->items_sorted};

  my $method = $sort_keys{$::form->{order_by}};
  my @to_sort = map { { old_pos => $_->position, order_by => $method->($_) } } @{ $self->reclamation->items_sorted };
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
    ->run('kivi.Reclamation.redisplay_items', \@to_sort)
    ->render;
}

# show the popup to choose a price/discount source
sub action_price_popup {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{reclamation_items_ids} };
  my $item = $self->reclamation->items_sorted->[$idx];
  if ($item->is_linked_to_record) {
    $self->js->flash('error', t8("Can't change price of a linked item"));
    return $self->js->render();
  }

  $self->render_price_dialog($item);
}

# save the reclamation in a session variable and redirect to the part controller
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
    controller => 'Part',
    action     => 'add',
    part_type  => $::form->{add_item}->{create_part_type},
    callback   => $callback,
    show_abort => 1,
  );

  $self->redirect_to(@redirect_params);
}

sub action_return_from_create_part {
  my ($self) = @_;

  $self->{created_part} = SL::DB::Part->new(
    id => delete $::form->{new_parts_id}
  )->load if $::form->{new_parts_id};

  $::auth->restore_form_from_session(delete $::form->{previousform});
  $self->reclamation($self->init_reclamation);
  $self->reinit_after_new_reclamation();

  if ($self->reclamation->id) {
    $self->pre_render();
    $self->render(
      'reclamation/form',
      title => $self->type_data->text('edit'),
      %{$self->{template_args}},
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

  foreach my $item_id (@{ $::form->{reclamation_items_ids} }) {
    my $idx  = first_index { $_ eq $item_id } @{ $::form->{reclamation_items_ids} };
    my $item = $self->reclamation->items_sorted->[$idx];

    $self->js_load_second_row($item, $item_id, 0);
  }

  $self->js->run('kivi.Reclamation.init_row_handlers') if $self->reclamation->is_sales; # for lastcosts change-callback

  $self->js->render();
}

# update description, notes and sellprice from master data
sub action_update_row_from_master_data {
  my ($self) = @_;

  foreach my $item_id (@{ $::form->{item_ids} }) {
    my $idx   = first_index { $_ eq $item_id } @{ $::form->{reclamationitem_ids} };
    my $item  = $self->reclamation->items_sorted->[$idx];

    if ($item->is_linked_to_record) {
      $self->js->flash_later('error', t8("Can't change data of a linked item. Part: " . $item->part->partnumber));
      next;
    }

    my $texts = get_part_texts($item->part, $self->reclamation->language_id);

    $item->description($texts->{description});
    $item->longdescription($texts->{longdescription});

    my ($price_src, undef) = SL::Model::Record->get_best_price_and_discount_source($self->reclamation, $item, ignore_given => 1);
    $item->sellprice($price_src->price);
    $item->active_price_source($price_src);

    $self->js
      ->run('kivi.Reclamation.update_sellprice', $item_id, $item->sellprice_as_number)
      ->html('.row_entry:has(#item_' . $item_id
             . ') [name = "partnumber"] a', $item->part->partnumber)
      ->val ('.row_entry:has(#item_' . $item_id
             . ') [name = "reclamation.reclamation_items[].description"]',
             $item->description)
      ->val ('.row_entry:has(#item_' . $item_id
             . ') [name = "reclamation.reclamation_items[].longdescription"]',
             $item->longdescription);

    if ($self->search_cvpartnumber) {
      $self->get_item_cvpartnumber($item);
      $self->js->html('.row_entry:has(#item_' . $item_id
                      . ') [name = "cvpartnumber"]', $item->{cvpartnumber});
    }
  }

  $self->recalc();
  $self->js_redisplay_line_values;
  $self->js_redisplay_amounts_and_taxes;

  $self->js->render();
}

sub js_load_second_row {
  my ($self, $item, $item_id, $do_parse) = @_;

  if ($do_parse) {
    # Parse values from form (they are formated while rendering (template)).
    # Workaround to pre-parse number-cvars (parse_custom_variable_values does
    # not parse number values). This parsing is not necessary at all, if we
    # assure that the second row/cvars are only loaded once.
    foreach my $var (@{ $item->cvars_by_config }) {
      if ($var->config->type eq 'number' && exists($var->{__unparsed_value})) {
        $var->unparsed_value($::form->parse_amount(\%::myconfig, $var->{__unparsed_value}));
      }
    }
    $item->parse_custom_variable_values;
  }

  my $row_as_html = $self->p->render('reclamation/tabs/basic_data/_second_row', ITEM => $item, TYPE => $self->type);

  $self->js
    ->html('#second_row_' . $item_id, $row_as_html)
    ->data('#second_row_' . $item_id, 'loaded', 1);
}

sub js_redisplay_line_values {
  my ($self) = @_;

  my @data = map {[
       $::form->format_amount(\%::myconfig, $_->{linetotal}, 2, 0),
      ]} @{ $self->reclamation->items_sorted };

  $self->js
    ->run('kivi.Reclamation.redisplay_line_values', $self->reclamation->is_sales, \@data);
}

sub js_redisplay_amounts_and_taxes {
  my ($self) = @_;

  if (scalar @{ $self->reclamation->taxes }) {
    $self->js->show('#taxincluded_row_id');
  } else {
    $self->js->hide('#taxincluded_row_id');
  }

  if ($self->reclamation->taxincluded) {
    $self->js->hide('#subtotal_row_id');
  } else {
    $self->js->show('#subtotal_row_id');
  }

  $self->js
    ->html('#netamount_id', $::form->format_amount(\%::myconfig, $self->reclamation->netamount, -2))
    ->html('#amount_id',    $::form->format_amount(\%::myconfig, $self->reclamation->amount,    -2))
    ->remove('.tax_row')
    ->insertBefore($self->build_tax_rows, '#amount_row_id');
}

sub js_redisplay_cvpartnumbers {
  my ($self) = @_;

  $self->get_item_cvpartnumber($_) for @{$self->reclamation->items_sorted};

  my @data = map {[$_->{cvpartnumber}]} @{ $self->reclamation->items_sorted };

  $self->js
    ->run('kivi.Reclamation.redisplay_cvpartnumbers', \@data);
}
sub js_reset_reclamation_and_item_ids_after_save {
  my ($self) = @_;

  $self->js
    ->val('#id', $self->reclamation->id)
    ->val('#converted_from_record_type_ref', '')
    ->val('#converted_from_record_id',  '')
    ->val('#reclamation_record_number', $self->reclamation->record_number);

  my $idx = 0;
  foreach my $form_item_id (@{ $::form->{reclamationitem_ids} }) {
    next if !$self->reclamation->items_sorted->[$idx]->id;
    next if $form_item_id !~ m{^new};
    $self->js
      ->val ('[name="reclamationitem_ids[+]"][value="' . $form_item_id . '"]',
             $self->reclamation->items_sorted->[$idx]->id)
      ->val ('#item_' . $form_item_id,
             $self->reclamation->items_sorted->[$idx]->id)
      ->attr('#item_' . $form_item_id, "id",
             'item_' . $self->reclamation->items_sorted->[$idx]->id);
  } continue {
    $idx++;
  }
  $self->js->val('[name="converted_from_record_item_type_refs[+]"]', '');
  $self->js->val('[name="converted_from_record_item_ids[+]"]', '');
}

#
# helpers
#

sub init_valid_types {
  $_[0]->type_data->valid_types;
}

sub init_type {
  my ($self) = @_;

  my $type = $self->reclamation->record_type;
  if (none { $type eq $_ } @{$self->valid_types}) {
    die "Not a valid type for reclamation";
  }

  $self->type($type);
}

sub init_cv {
  my ($self) = @_;

  $self->type_data->properties('customervendor');
}

sub init_search_cvpartnumber {
  my ($self) = @_;

  my $user_prefs = SL::Helper::UserPreferences::PartPickerSearch->new();
  my $search_cvpartnumber;
  if ($self->type_data->properties('is_customer')) {
    $search_cvpartnumber = !!$user_prefs->get_sales_search_customer_partnumber()
  } else {
    $search_cvpartnumber = !!$user_prefs->get_purchase_search_makemodel();
  }

  return $search_cvpartnumber;
}

sub init_show_update_button {
  my ($self) = @_;

  !!SL::Helper::UserPreferences::UpdatePositions->new()->get_show_update_button();
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      _default  => {
        by  => 'record_number',
        dir => 0,
      },
      id                      => t8('ID'),
      record_number           => t8('Reclamation Number'),
      employee                => t8('Employee'),
      salesman                => t8('Salesman'),
      customer                => t8('Customer'),
      vendor                  => t8('Vendor'),
      contact                 => t8('Contact'),
      language                => t8('Language'),
      department              => t8('Department'),
      globalproject           => t8('Project Number'),
      cv_record_number        => ($self->type_data->properties('is_customer') ? t8('Customer Record Number') : t8('Vendor Record Number')),
      transaction_description => t8('Description'),
      notes                   => t8('Notes'),
      intnotes                => t8('Internal Notes'),
      shippingpoint           => t8('Shipping Point'),
      shipvia                 => t8('Ship via'),
      shipto_id               => t8('Shipping Address'),
      amount                  => t8('Total'),
      netamount               => t8('Subtotal'),
      delivery_term           => t8('Delivery Terms'),
      payment                 => t8('Payment Terms'),
      currency                => t8('Currency'),
      exchangerate            => t8('Exchangerate'),
      taxincluded             => t8('Tax Included'),
      taxzone                 => t8('Tax zone'),
      tax_point               => t8('Tax point'),
      reqdate                 => t8('Deadline'),
      transdate               => t8('Booking Date'),
      itime                   => t8('Creation Time'),
      mtime                   => t8('Last modification Time'),
      delivered               => t8('Delivered'),
      closed                  => t8('Closed'),
    },
    query => [
      SL::DB::Manager::Reclamation->type_filter($self->type),
      (salesman_id => SL::DB::Manager::Employee->current->id) x ($self->reclamation->is_sales  && !$::auth->assert('sales_all_edit', 1)),
      (employee_id => SL::DB::Manager::Employee->current->id) x ($self->reclamation->is_sales  && !$::auth->assert('sales_all_edit', 1)),
      (employee_id => SL::DB::Manager::Employee->current->id) x (!$self->reclamation->is_sales && !$::auth->assert('purchase_all_edit', 1)),
    ],

    with_objects => [
        'customer',      'vendor',   'employee',   'salesman',
        'contact',       'language', 'department', 'globalproject',
        'delivery_term', 'payment',  'currency',   'taxzone',
      ],
    );
}

sub init_p {
  SL::Presenter->get;
}

sub init_reclamation {
  $_[0]->make_reclamation;
}

sub init_all_price_factors {
  SL::DB::Manager::PriceFactor->get_all;
}

sub init_part_picker_classification_ids {
  my ($self)    = @_;

  return [ map { $_->id } @{ SL::DB::Manager::PartClassification->get_all(where => $self->type_data->part_classification_query()) } ];
}

sub check_auth {
  my ($self) = @_;
  $::auth->assert($self->type_data->rights('edit'));
}

# build the selection box for contacts
#
# Needed, if customer/vendor changed.
sub build_contact_select {
  my ($self) = @_;

  select_tag('reclamation.contact_id', [ $self->reclamation->customervendor->contacts ],
    value_key  => 'cp_id',
    title_key  => 'full_name_dep',
    default    => $self->reclamation->contact_id,
    with_empty => 1,
    style      => 'width: 300px',
  );
}

# build the selection box for shiptos
#
# Needed, if customer/vendor changed.
sub build_shipto_select {
  my ($self) = @_;

  select_tag('reclamation.shipto_id',
             [ {displayable_id => t8("No/individual shipping address"),
                shipto_id => '',
               },
               $self->reclamation->customervendor->shipto
             ],
             value_key  => 'shipto_id',
             title_key  => 'displayable_id',
             default    => $self->reclamation->shipto_id,
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
                                 cv_obj      => $self->reclamation->customervendor,
                                 cs_obj      => $self->reclamation->custom_shipto,
                                 cvars       => $self->reclamation->custom_shipto->cvars_by_config,
                                 id_selector => '#reclamation_shipto_id');

  div_tag($content, id => 'shipto_inputs');
}

# render the info line for business
#
# Needed, if customer/vendor changed.
sub build_business_info_row
{
  $_[0]->p->render('reclamation/tabs/basic_data/_business_info_row', SELF => $_[0]);
}

# build the rows for displaying taxes
#
# Called if amounts where recalculated and redisplayed.
sub build_tax_rows {
  my ($self) = @_;

  my $rows_as_html;
  foreach my $tax (sort { $a->{tax}->rate cmp $b->{tax}->rate } @{ $self->reclamation->taxes }) {
    $rows_as_html .= $self->p->render(
                       'reclamation/tabs/basic_data/_tax_row',
                       SELF => $self,
                       TAX => $tax,
                       TAXINCLUDED => $self->reclamation->taxincluded,
                     );
  }
  return $rows_as_html;
}

sub render_price_dialog {
  my ($self, $record_item) = @_;

  my $price_source = SL::PriceSource->new(
                       record_item => $record_item,
                       record => $self->reclamation,
                     );

  $self->js
    ->run(
      'kivi.io.price_chooser_dialog',
      t8('Available Prices'),
      $self->render(
        'reclamation/tabs/basic_data/_price_sources_dialog',
        { output => 0 },
        price_source => $price_source,
      ),
    )
    ->reinit_widgets;

#   if (@errors) {
#     $self->js->text('#dialog_flash_error_content', join ' ', @errors);
#     $self->js->show('#dialog_flash_error');
#   }

  $self->js->render;
}

# load or create a new reclamation object
#
# And assign changes from the form to this object.
# If the reclamation is loaded from db, check if items are deleted in the form,
# remove them form the object and collect them for removing from db on saving.
# Then create/update items from form (via make_item) and add them.
sub make_reclamation {
  my ($self) = @_;

  # add_items adds items to an reclamation with no items for saving, but they
  # cannot be retrieved via items until the reclamation is saved. Adding empty
  # items to new reclamation here solves this problem.
  my $reclamation;
  if ($::form->{id}) {
    $reclamation = SL::DB::Reclamation->new(id => $::form->{id})->load();
  } else {
    $reclamation = SL::DB::Reclamation->new(
                     record_type        => $::form->{type},
                     reclamation_items  => [],
                     currency_id => $::instance_conf->get_currency_id(),
                   );
    $reclamation = SL::Model::Record->update_after_new($reclamation)
  }

  my $cv_id_method = $reclamation->type_data->properties('customervendor'). '_id';
  if (!$::form->{id} && $::form->{$cv_id_method}) {
    $reclamation->$cv_id_method($::form->{$cv_id_method});
    $reclamation = SL::Model::Record->update_after_customer_vendor_change($reclamation);
  }

  # don't assign hashes as objects
  my $form_reclamation_items = delete $::form->{reclamation}->{reclamation_items};

  $reclamation->assign_attributes(%{$::form->{reclamation}});

  # restore form values
  $::form->{reclamation}->{reclamation_items} = $form_reclamation_items;

  $self->setup_custom_shipto_from_form($reclamation, $::form);

  # remove deleted items
  $self->item_ids_to_delete([]);
  foreach my $idx (reverse 0..$#{$reclamation->reclamation_items}) {
    my $item = $reclamation->reclamation_items->[$idx];
    if (none { $item->id == $_->{id} } @{$form_reclamation_items}) {
      splice @{$reclamation->reclamation_items}, $idx, 1;
      push @{$self->item_ids_to_delete}, $item->id;
    }
  }

  my @items;
  my $pos = 1;
  foreach my $form_attr (@{$form_reclamation_items}) {
    my $item = make_item($reclamation, $form_attr);
    $item->position($pos);
    push @items, $item;
    $pos++;
  }
  $reclamation->add_items(grep {!$_->id} @items);

  return $reclamation;
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

  # add_custom_variables adds cvars to an reclamation_item with no cvars for
  # saving, but they cannot be retrieved via custom_variables until the
  # reclamation/reclamation_item is saved. Adding empty custom_variables to new
  # reclamationitem here solves this problem.
  $item ||= SL::DB::ReclamationItem->new(custom_variables => []);

  $item->assign_attributes(%$attr);

  if ($is_new) {
    my $texts = get_part_texts($item->part, $record->language_id);
    $item->longdescription($texts->{longdescription})              if !defined $attr->{longdescription};
    $item->project_id($record->globalproject_id)                   if !defined $attr->{project_id};
    $item->lastcost($record->is_sales ? $item->part->lastcost : 0) if !defined $attr->{lastcost_as_number};
  }

  return $item;
}

sub load_reclamation {
  my ($self) = @_;

  return if !$::form->{id};

  $self->reclamation(SL::DB::Reclamation->new(id => $::form->{id})->load);

  $self->reinit_after_new_reclamation();

  return $self->reclamation;
}

# create a new item
#
# This is used to add one item
sub new_item {
  my ($record, $attr) = @_;

  my $item = SL::DB::ReclamationItem->new;

  # Remove attributes where the user left or set the inputs empty.
  # So these attributes will be undefined and we can distinguish them
  # from zero later on.
  for (qw(qty_as_number sellprice_as_number discount_as_percent)) {
    delete $attr->{$_} if $attr->{$_} eq '';
  }

  $item->assign_attributes(%$attr);

  my $part = SL::DB::Part->new(id => $attr->{parts_id})->load;
  $item->qty(1.0)          if !$item->qty;
  $item->unit($part->unit) if !$item->unit;

  my ($price_src, $discount_src) = SL::Model::Record->get_best_price_and_discount_source($record, $item, ignore_given => 0);

  my %new_attr;
  $new_attr{part}                   = $part;
  $new_attr{description}            = $part->description     if ! $item->description;
  $new_attr{qty}                    = 1.0                    if ! $item->qty;
  $new_attr{price_factor_id}        = $part->price_factor_id if ! $item->price_factor_id;
  $new_attr{sellprice}              = $price_src->price;
  $new_attr{discount}               = $discount_src->discount;
  $new_attr{active_price_source}    = $price_src;
  $new_attr{active_discount_source} = $discount_src;
  $new_attr{longdescription}        = $part->notes           if ! defined $attr->{longdescription};
  $new_attr{project_id}             = $record->globalproject_id;
  $new_attr{lastcost}               = $record->is_sales ? $part->lastcost : 0;

  # add_custom_variables adds cvars to an reclamationitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the reclamation/reclamationitem is
  # saved. Adding empty custom_variables to new reclamationitem here solves this problem.
  $new_attr{custom_variables} = [];

  my $texts = get_part_texts($part, $record->language_id,
                description => $new_attr{description},
                longdescription => $new_attr{longdescription},
              );

  $item->assign_attributes(%new_attr, %{ $texts });

  $item->reclamation($record);
  return $item;
}

# setup custom shipto from form
#
# The dialog returns form variables starting with 'shipto' and cvars starting
# with 'shiptocvar_'.
# Mark it to be deleted if a shipto from master data is selected
# (i.e. reclamation has a shipto).
# Else, update or create a new custom shipto. If the fields are empty, it
# will not be saved on save.
sub setup_custom_shipto_from_form {
  my ($self, $reclamation, $form) = @_;

  if ($reclamation->shipto) {
    $self->is_custom_shipto_to_delete(1);
  } else {
    my $custom_shipto =    $reclamation->custom_shipto
                        || $reclamation->custom_shipto(
                             SL::DB::Shipto->new(module => 'RC', custom_variables => [])
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

  my %pat = $self->reclamation->calculate_prices_and_taxes();

  pairwise { $a->{linetotal} = $b->{linetotal} } @{$self->reclamation->items_sorted}, @{$pat{items}};
}

# get data for saving, printing, ..., that is not changed in the form
#
# Only cvars for now.
sub get_unalterable_data {
  my ($self) = @_;

  foreach my $item (@{ $self->reclamation->items }) {
    # autovivify all cvars that are not in the form (cvars_by_config can do it).
    # workaround to pre-parse number-cvars (parse_custom_variable_values does not parse number values).
    foreach my $var (@{ $item->cvars_by_config }) {
      if ($var->config->type eq 'number' && exists($var->{__unparsed_value})) {
        $var->unparsed_value($::form->parse_amount(\%::myconfig, $var->{__unparsed_value}));
      }
    }
    $item->parse_custom_variable_values;
  }
}

# save the reclamation
#
# And delete items that are deleted in the form.
sub save {
  my ($self) = @_;

  set_record_link_conversions($self->reclamation,
    delete $::form->{RECORD_TYPE_REF()}
      => delete $::form->{RECORD_ID()},
    delete $::form->{RECORD_ITEM_TYPE_REF()}
      => delete $::form->{RECORD_ITEM_ID()},
  );

  my $items_to_delete  = scalar @{ $self->item_ids_to_delete || [] }
                       ? SL::DB::Manager::ReclamationItem->get_all(where => [id => $self->item_ids_to_delete])
                       : undef;

  SL::Model::Record->save($self->reclamation,
                          with_validity_token  => { scope => SL::DB::ValidityToken::SCOPE_RECLAMATION_SAVE(), token => $::form->{form_validity_token} },
                          delete_custom_shipto => $self->reclamation->custom_shipto && ($self->is_custom_shipto_to_delete || $self->reclamation->custom_shipto->is_empty),
                          items_to_delete      => $items_to_delete,
  );

  if ($::form->{email_journal_id}) {
    my $email_journal = SL::DB::EmailJournal->new(
      id => delete $::form->{email_journal_id}
    )->load;
    $email_journal->link_to_record_with_attachment(
      $self->reclamation,
      delete $::form->{email_attachment_id}
    );
  }

  delete $::form->{form_validity_token};
}

sub reinit_after_new_reclamation {
  my ($self) = @_;

  # change form type
  $::form->{type} = $self->reclamation->type;
  $self->type($self->init_type);
  $self->type_data($self->init_type_data);
  $self->cv($self->init_cv);
  $self->check_auth;

  $self->setup_custom_shipto_from_form($self->reclamation, $::form);

  foreach my $item (@{$self->reclamation->items_sorted}) {
    # set item ids to new fake id, to identify them as new items
    $item->{new_fake_id} = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);

    # trigger rendering values for second row as hidden, because they
    # are loaded only on demand. So we need to keep the values from the
    # source.
    $item->{render_second_row} = 1;
  }

  $self->get_unalterable_data();
  $self->recalc();
}

sub pre_render {
  my ($self) = @_;

  $self->{all_taxzones}               = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_currencies}             = SL::DB::Manager::Currency->get_all_sorted();
  $self->{all_departments}            = SL::DB::Manager::Department->get_all_sorted();
  $self->{all_languages}              = SL::DB::Manager::Language->get_all_sorted();
  $self->{all_employees}              = SL::DB::Manager::Employee->get_all(
                                          where => [ or => [
                                                        id => $self->reclamation->employee_id,
                                                        deleted => 0 ] ],
                                                     sort_by => 'name');
  $self->{all_salesmen}               = SL::DB::Manager::Employee->get_all(
                                          where => [ or => [
                                                        id => $self->reclamation->salesman_id,
                                                        deleted => 0 ] ],
                                          sort_by => 'name');
  $self->{all_payment_terms}          = SL::DB::Manager::PaymentTerm->get_all_sorted(
                                          where => [ or => [
                                                        id => $self->reclamation->payment_id,
                                                        obsolete => 0 ] ]);
  $self->{all_delivery_terms}         = SL::DB::Manager::DeliveryTerm->get_all_sorted();
  $self->{current_employee_id}        = SL::DB::Manager::Employee->current->id;

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
                no_html            => 1},
  );
  foreach my $item (@{$self->reclamation->reclamation_items}) {
    my $price_source = SL::PriceSource->new(record_item => $item, record => $self->reclamation);
    $item->active_price_source(   $price_source->price_from_source(   $item->active_price_source   ));
    $item->active_discount_source($price_source->discount_from_source($item->active_discount_source));
  }

  if ($self->reclamation->record_number && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => $self->type,
      number   => $self->reclamation->record_number,
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $self->{template_args}->{WEBDAV} } = map { { name => $_->filename,
                                                    type => t8('File'),
                                                    link => File::Spec->catfile($_->full_filedescriptor),
                                                } } @all_objects;
  }

  $self->get_item_cvpartnumber($_) for @{$self->reclamation->items_sorted};

  $::request->{layout}->use_javascript("${_}.js") for
    qw(kivi.SalesPurchase kivi.Reclamation kivi.File
       calculate_qty kivi.Validator follow_up
       show_history
      );
  $self->_setup_edit_action_bar;
}

sub prepare_report {
  my ($self)         = @_;

  my $report         =  SL::ReportGenerator->new(\%::myconfig, $::form);
  $report->{title}   =  t8('Sales Reclamations');
  if ($self->type eq PURCHASE_RECLAMATION_TYPE()){
    $report->{title} = t8('Purchase Reclamations');
  }

  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->add_additional_url_params(type => $self->type);
  $self->models->finalize; # for filter laundering

  my $callback    = $self->models->get_callback;

  $self->{report} = $report;

  # TODO: shipto_id is not linked to custom_shipto
  my @columns_order = qw(
    id
    record_number
    employee
    salesman
    customer
    vendor
    contact
    language
    department
    globalproject
    cv_record_number
    transaction_description
    notes
    intnotes
    shippingpoint
    shipvia
    amount
    netamount
    delivery_term
    payment
    currency
    exchangerate
    taxincluded
    taxzone
    tax_point
    reqdate
    transdate
    itime
    mtime
    delivered
    closed
  );

  my @default_columns = qw(
    record_number
    employee
    department
    globalproject
    cv_record_number
    transaction_description
    amount
    reqdate
    transdate
    itime
    mtime
    delivered
    closed
  );

  my %column_defs = (
    id => {
      obj_link => sub {$self->url_for(action => 'edit', id => $_[0]->id, type => $self->type, callback => $callback)},
      sub      => sub { $_[0]->id },
    },
    record_number => {
      obj_link => sub {$self->url_for(action => 'edit', id => $_[0]->id, type => $self->type, callback => $callback)},
      sub      => sub { $_[0]->record_number },
    },
    employee => {
      sub      => sub { $_[0]->employee ? $_[0]->employee->name : '' },
    },
    salesman => {
      sub      => sub { $_[0]->salesman ? $_[0]->salesman->name : '' },
    },
    language => {
      sub      => sub { $_[0]->language ? $_[0]->language->article_code : '' },
    },
    department => {
      sub      => sub { $_[0]->department ? $_[0]->department->description : '' },
    },
    globalproject => {
      obj_link => sub { $_[0]->globalproject_id ?
       $self->url_for(
          controller => "controller.pl",
          action => 'Project/edit',
          id => $_[0]->globalproject_id,
          callback => $callback
        ) : '' },
      sub      => sub { !$_[0]->globalproject ? '' : $_[0]->globalproject->projectnumber },
    },
    cv_record_number => {
      sub      => sub { $_[0]->cv_record_number },
    },
    transaction_description => {
      sub      => sub { $_[0]->transaction_description },
    },
    notes => {
      sub      => sub { $_[0]->notes },
    },
    intnotes => {
      sub      => sub { $_[0]->intnotes },
    },
    shippingpoint => {
      sub      => sub { $_[0]->shippingpoint },
    },
    shipvia => {
      sub      => sub { $_[0]->shipvia },
    },
    # TODO: custom ship to is not safed in reclamation
    #shipto_id => {
    #  sub      => sub { $_[0]->shipto ? $_[0]->shipto->shiptoname : '' },
    #},
    amount  => {
      sub      => sub { $_[0]->amount_as_number },
    },
    netamount  => {
      sub      => sub { $_[0]->netamount_as_number },
    },
    delivery_term => {
      obj_link => sub { $_[0]->delivery_term_id ?
       $self->url_for(
          controller => "controller.pl",
          action => 'DeliveryTerm/edit',
          id => $_[0]->delivery_term_id,
          callback => $callback
        ) : '' },
      sub      => sub { $_[0]->delivery_term ? $_[0]->delivery_term->description : '' },
    },
    payment => {
      obj_link => sub { $_[0]->payment_id ?
       $self->url_for(
          controller => "controller.pl",
          action => 'PaymentTerm/edit',
          id => $_[0]->payment_id,
          callback => $callback
        ) : '' },
      sub      => sub { $_[0]->payment ? $_[0]->payment->description : '' },
    },
    currency => {
      sub      => sub { $_[0]->currency ? $_[0]->currency->name : '' },
    },
    exchangerate  => {
      sub      => sub { $_[0]->exchangerate ? $_[0]->exchangerate_as_number : '' },
    },
    taxincluded => {
      sub      => sub { $_[0]->taxincluded ? t8('Yes') : t8('No') },
    },
    taxzone => {
      obj_link => sub { $_[0]->taxzone_id ?
       $self->url_for(
          controller => "controller.pl",
          action => 'Taxzones/edit',
          id => $_[0]->taxzone_id,
          callback => $callback
        ) : '' },
      sub      => sub { $_[0]->taxzone ? $_[0]->taxzone->description : '' },
    },
    tax_point  => {
      sub      => sub { $_[0]->tax_point ? ($_[0]->tax_point)->to_kivitendo(precision => 'day') : '' },
    },
    reqdate  => {
      sub      => sub { $_[0]->reqdate ? ($_[0]->reqdate)->to_kivitendo(precision => 'day') : '' },
    },
    transdate  => {
      sub      => sub { $_[0]->transdate ? ($_[0]->transdate)->to_kivitendo(precision => 'day') : '' },
    },
    itime      => {
      sub      => sub { $_[0]->itime->to_kivitendo(precision => 'minute') }
    },
    mtime      => {
      sub      => sub { $_[0]->mtime ? $_[0]->mtime->to_kivitendo(precision => 'minute') : '' }
    },
    delivered => {
      sub      => sub { $_[0]->delivered ? t8('Yes') : t8('No') },
    },
    closed => {
      sub      => sub { $_[0]->closed ? t8('Yes') : t8('No') },
    },
  );
  if ($self->type_data->properties('is_customer')) {
    $column_defs{customer} = ({
      raw_data => sub { $_[0]->customervendor->presenter->customer(display => 'table-cell', callback => $callback) },
      sub      => sub { $_[0]->customervendor->name },
    });
    $column_defs{contact} = ({
      obj_link => sub { $self->url_for(
          controller => "controller.pl",
          action => 'CustomerVendor/edit',
          db => 'customer',
          id => $_[0]->customer_id
        ) . '#contacts'
      },
      sub      => sub { $_[0]->contact ? $_[0]->contact->cp_name : '' },
    });
  } else {
    $column_defs{vendor} = ({
      raw_data => sub { $_[0]->customervendor->presenter->vendor(display => 'table-cell', callback => $callback) },
      sub      => sub { $_[0]->customervendor->name },
    });
    $column_defs{contact} = ({
      obj_link => sub { $self->url_for(
          controller => "controller.pl",
          action => 'CustomerVendor/edit',
          db => 'vendor',
          id => $_[0]->vendor_id
        ) . "#contacts"
      },
      sub      => sub { $_[0]->contact ? $_[0]->contact->cp_name : '' },
    });
  }
  $column_defs{$_}->{text} ||= t8( $self->models->get_sort_spec->{$_}->{title} || $_ ) for keys %column_defs;

  unless ($::form->{active_in_report}) {
    $::form->{active_in_report}->{$_} = 1 foreach @default_columns;
  }
  $self->models->add_additional_url_params(
    active_in_report => $::form->{active_in_report});
  map { $column_defs{$_}->{visible} = $::form->{active_in_report}->{"$_"} }
    keys %column_defs;

  ## add cvars TODO: Add own cvars
  #my %cvar_column_defs = map {
  #  my $cfg = $_;
  #  (('cvar_' . $cfg->name) => {
  #    sub     => sub { my $var = $_[0]->cvar_by_name($cfg->name); $var ? $var->value_as_text : '' },
  #    text    => $cfg->description,
  #    visible => $self->include_cvars->{ $cfg->name } ? 1 : 0,
  #  })
  #} @{ $self->includeable_cvar_configs };

  #push @columns, map { 'cvar_' . $_->name } @{ $self->includeable_cvar_configs };
  #%column_defs = (%column_defs, %cvar_column_defs);

  #my @cvar_column_form_names = ('_include_cvars_from_form', map { "include_cvars_" . $_->name } @{ $self->includeable_cvar_configs });

  # make all sortable
  my @sortable = keys %column_defs;

  my $filter_html = SL::Presenter::ReclamationFilter::filter(
    $::form->{filter}, $self->type, active_in_report => $::form->{active_in_report}
  );

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'Reclamation',
    output_format         => 'HTML',
    raw_top_info_text     => $self->render(
     'reclamation/_report_top',
     { output => 0 },
     FILTER_HTML => $filter_html,
    ),
    raw_bottom_info_text  => $self->render(
     'reclamation/_report_bottom',
     { output => 0 },
     models => $self->models
    ),
    title                 => $self->type_data->text('list'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns_order);
  #$report->set_export_options(qw(list filter), @cvar_column_form_names); TODO: for cvars
  $report->set_export_options(qw(list filter active_in_report));
  $report->set_options_from_form;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);
}

sub _setup_edit_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
            }],
          checks    => [
            ['kivi.validate_form','#reclamation_form'],
          ],
        ],
        action => [
          t8('Save and Close'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
              form_params        => [
                { name => 'back_to_caller', value => 1 },
              ],
            }],
          checks    => [
            ['kivi.validate_form','#reclamation_form'],
          ],
        ],
        action => [
          t8('Save as new'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save_as_new',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
            }],
          disabled  => !$self->reclamation->id ? t8('This object has not been saved yet.') : undef,
        ],
      ], # end of combobox "Save"

      combobox => [
        action => [
          t8('Workflow'),
        ],
        action => [
          t8('Save and Sales Reclamation'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
              form_params        => [
                { name => 'to_type', value => SALES_RECLAMATION_TYPE() },
              ],
            }],
          only_if  => $self->type_data->show_menu('save_and_sales_reclamation'),
        ],
        action => [
          t8('Save and Purchase Reclamation'),
          call      => [ 'kivi.Reclamation.purchase_reclamation_check_for_direct_delivery', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
              form_params        => [
                { name => 'to_type', value => PURCHASE_RECLAMATION_TYPE() },
              ],
            }
          ],
          only_if  => $self->type_data->show_menu('save_and_purchase_reclamation'),
        ],
        action => [
          t8('Save and Order'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
              form_params        => [
                { name => 'to_type',
                  value => $self->reclamation->is_sales ? SALES_ORDER_TYPE()
                                                        : PURCHASE_ORDER_TYPE() },
              ],
            }],
        ],
        action => [
          t8('Save and RMA Delivery Order'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
              form_params        => [
                { name => 'to_type', value => RMA_DELIVERY_ORDER_TYPE() },
              ],
            }],
          only_if  => $self->type_data->show_menu('save_and_rma_delivery_order'),
        ],
        action => [
          t8('Save and Supplier Delivery Order'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save_and_new_record',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
              form_params        => [
                { name => 'to_type', value => SUPPLIER_DELIVERY_ORDER_TYPE() },
              ],
            }],
          only_if  => $self->type_data->show_menu('save_and_supplier_delivery_order'),
        ],
        action => [
          t8('Save and Credit Note'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save_and_credit_note',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
              form_params        => [
                { name => 'to_type', value => 'credit_note' },
              ],
            }],
          only_if  => $self->type_data->show_menu('save_and_credit_note'),
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [
          t8('Export'),
        ],
        action => [
          t8('Save and preview PDF'),
          call      => [ 'kivi.Reclamation.save', {
              action             => 'preview_pdf',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
            }],
        ],
        action => [
          t8('Save and print'),
          call => [
            'kivi.Reclamation.show_print_options',
            $::instance_conf->get_reclamation_warn_duplicate_parts,
            $::instance_conf->get_reclamation_warn_no_reqdate,
          ],
        ],
        action => [
          t8('Save and E-mail'),
          id   => 'save_and_email_action',
          call      => [ 'kivi.Reclamation.save', {
              action             => 'save_and_show_email_dialog',
              warn_on_duplicates => $::instance_conf->get_reclamation_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_reclamation_warn_no_reqdate,
            }],
          disabled => !$self->reclamation->id ? t8('This object has not been saved yet.') : undef,
        ],
        action => [
          t8('Download attachments of all parts'),
          call     => [ 'kivi.File.downloadReclamationitemsFiles', $::form->{type}, $::form->{id} ],
          disabled => !$self->reclamation->id ? t8('This object has not been saved yet.') : undef,
          only_if  => $::instance_conf->get_doc_storage,
        ],
      ], # end of combobox "Export"

      action => [
        t8('Delete'),
        call     => [ 'kivi.Reclamation.delete_reclamation' ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => !$self->reclamation->id ? t8('This object has not been saved yet.') : undef,
        only_if  => $self->type_data->show_menu('delete'),
      ],

      combobox => [
        action => [
          t8('more')
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'kivi.Reclamation.follow_up_window' ],
          disabled => !$self->reclamation->id ? t8('This object has not been saved yet.') : undef,
          only_if  => $::auth->assert('productivity', 1),
        ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $self->reclamation->id, 'id' ],
          disabled => !$self->reclamation->id ? t8('This record has not been saved yet.') : undef,
        ],
      ], # end of combobox "more"
    );
  }
}

sub _setup_search_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#search_form', { action => 'Reclamation/list', type => $self->type } ],
        accesskey => 'enter',
      ],
      link => [
        t8('Add'),
        link => $self->url_for(action => 'add', type => $self->type),
      ],
    );
  }
}

sub generate_pdf {
  my ($reclamation, $pdf_ref, $params) = @_;

  my @errors = ();

  my $print_form = Form->new('');
  $print_form->{type}        = $reclamation->type;
  $print_form->{formname}    = $params->{formname} || $reclamation->type;
  $print_form->{format}      = $params->{format}   || 'pdf';
  $print_form->{media}       = $params->{media}    || 'file';
  $print_form->{groupitems}  = $params->{groupitems};
  $print_form->{printer_id}  = $params->{printer_id};
  $print_form->{language_id} = $params->{language} ? $params->{language}->id : undef;
  $print_form->{media}       = 'file'       if $print_form->{media} eq 'screen';

  $reclamation->language($params->{language});

  # Make reclamation available in template
  $print_form->{reclamation} = $reclamation;

  my $template_ext;
  my $template_type;
  my $variable_content_types;
  if ($print_form->{format} =~ /(opendocument|oasis)/i) {
    $template_ext  = 'odt';
    $template_type = 'OpenDocument';

    # add variables for printing with the built-in parser
    $reclamation->flatten_to_form($print_form, format_amounts => 1);
    $reclamation->add_legacy_template_arrays($print_form);

    $variable_content_types = {
      longdescription => 'html',
      notes           => 'html',
      $::form->get_variable_content_types_for_cvars,
    }
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
    push @errors, t8(
      'Cannot find matching template for this print request. Please contact your template maintainer. I tried these: #1.',
      join ', ',
      map { "'$_'"} @template_files
    );
  }

  return @errors if scalar @errors;

  $print_form->throw_on_error(sub {
    eval {
      $print_form->prepare_for_printing;

      $$pdf_ref = SL::Helper::CreatePDF->create_pdf(
        format        => $print_form->{format},
        template_type => $template_type,
        template      => $template_file,
        variables     => $print_form,
        variable_content_types => $variable_content_types,
      );
      1;
    } || push @errors, ref($EVAL_ERROR) eq 'SL::X::FormError' ? $EVAL_ERROR->error : $EVAL_ERROR;
  });

  return @errors;
}

sub get_files_for_email_dialog {
  my ($self) = @_;

  my %files = map { ($_ => []) } qw(versions files cv_files project_files part_files);

  return %files if !$::instance_conf->get_doc_storage;

  if ($self->reclamation->id) {
    $files{versions} = [
      SL::File->get_all_versions(
        object_id => $self->reclamation->id,
        object_type => $self->reclamation->type,
        file_type => 'document')
    ];
    $files{files} = [
      SL::File->get_all(
        object_id => $self->reclamation->id,
        object_type => $self->reclamation->type,
        file_type => 'attachment')
    ];
    $files{cv_files} = [
      SL::File->get_all(
        object_id => $self->reclamation->customervendor->id,
        object_type => $self->cv,
        file_type => 'attachment')
    ];
    $files{project_files} = [
      SL::File->get_all(
        object_id => $self->reclamation->globalproject_id,
        object_type => 'project',
        file_type => 'attachment')
    ];
  }

  my @parts =
    uniq_by { $_->{id} }
    map {
      +{ id         => $_->part->id,
         partnumber => $_->part->partnumber }
    } @{$self->reclamation->items_sorted};

  foreach my $part (@parts) {
    my @pfiles = SL::File->get_all(object_id => $part->{id}, object_type => 'part');
    push @{ $files{part_files} }, map { +{ %{ $_ }, partnumber => $part->{partnumber} } } @pfiles;
  }

  foreach my $key (keys %files) {
    $files{$key} = [ sort_by { lc $_->{db_file}->{file_name} } @{ $files{$key} } ];
  }

  return %files;
}

sub get_item_cvpartnumber {
  my ($self, $item) = @_;

  return if !$self->search_cvpartnumber;
  return if !$self->reclamation->customervendor;

  if (!$self->reclamation->is_sales) {
    my @mms = grep { $_->make eq $self->reclamation->customervendor->id } @{$item->part->makemodels};
    $item->{cvpartnumber} = $mms[0]->model if scalar @mms;
  } elsif ($self->reclamation->is_sales) {
    my @cps = grep { $_->customer_id eq $self->reclamation->customervendor->id } @{$item->part->customerprices};
    $item->{cvpartnumber} = $cps[0]->customer_partnumber if scalar @cps;
  }
}

sub get_part_texts {
  my ($part_or_id, $language_or_id, %defaults) = @_;

  my $part        = ref($part_or_id)     ? $part_or_id         : SL::DB::Part->load_cached($part_or_id);
  my $language_id = ref($language_or_id) ? $language_or_id->id : $language_or_id;
  my $texts       = {
    description     => $defaults{description}     // $part->description,
    longdescription => $defaults{longdescription} // $part->notes,
  };

  return $texts unless $language_id;

  my $translation = SL::DB::Manager::Translation->get_first(
    where => [
      parts_id    => $part->id,
      language_id => $language_id,
    ]);

  $texts->{description}     = $translation->translation     if $translation && $translation->translation;
  $texts->{longdescription} = $translation->longdescription if $translation && $translation->longdescription;

  return $texts;
}

sub save_history {
  my ($self, $addition) = @_;

  SL::DB::History->new(
    trans_id    => $self->reclamation->id,
    employee_id => SL::DB::Manager::Employee->current->id,
    what_done   => $self->reclamation->type,
    snumbers    => 'record_number_' . $self->reclamation->record_number,
    addition    => $addition,
  )->save;
}

sub store_pdf_to_webdav_and_filemanagement {
  my($reclamation, $content, $filename) = @_;

  my @errors;

  # copy file to webdav folder
  if ($reclamation->record_number && $::instance_conf->get_webdav_documents) {
    my $webdav = SL::Webdav->new(
      type     => $reclamation->type,
      number   => $reclamation->record_number,
    );
    my $webdav_file = SL::Webdav::File->new(
      webdav   => $webdav,
      filename => $filename,
    );
    eval {
      $webdav_file->store(data => \$content);
      1;
    } or do {
      push @errors, t8('Storing PDF to webdav folder failed: #1', $@);
    };
  }
  if ($reclamation->id && $::instance_conf->get_doc_storage) {
    eval {
      SL::File->save(object_id     => $reclamation->id,
                     object_type   => $reclamation->type,
                     mime_type     => 'application/pdf',
                     source        => 'created',
                     file_type     => 'document',
                     file_name     => $filename,
                     file_contents => $content);
      1;
    } or do {
      push @errors, t8('Storing PDF in storage backend failed: #1', $@);
    };
  }

  return @errors;
}

sub init_type_data {
  my ($self) = @_;
  SL::DB::Helper::TypeDataProxy->new('SL::DB::Reclamation', $self->reclamation->record_type);
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Reclamation - controller for reclamations

=head1 SYNOPSIS

This is a new form to enter reclamations, written with the use
of controller and java script techniques.

The aim is to provide the user a good experience and a fast workflow.

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

Ordering item rows with drag and drop is possible. Sorting item rows is
possible (by partnumber, description, reason, qty, sellprice
and discount for now).

=item *

No C<update> is necessary. All entries and calculations are managed
with ajax-calls and the page only reloads on C<save>.

=item *

User can see changes immediately, because of the use of java script
and ajax.

=item *

Parts that are linked though RecordLinks are protected against price editing.

=back

=head1 CODE

=head2 Layout

=over 4

=item * C<SL/Controller/Reclamation.pm>

the controller

=item * C<template/webpages/reclamation/form.html>

main form

=item * C<template/webpages/reclamation/tabs/basic_data.html>

Main tab for basic_data.

This is the only tab here for now. "webdav", "documents", "attachements" and
"linked records" tabs are reused from generic code.

=over 4

=item * C<template/webpages/reclamation/tabs/basic_data/_business_info_row.html>

For displaying information on business type

=item * C<template/webpages/reclamation/tabs/basic_data/_item_input.html>

The input line for items

=item * C<template/webpages/reclamation/tabs/basic_data/_row.html>

One row for already entered items

=item * C<template/webpages/reclamation/tabs/basic_data/_second_row.html>

Foldable second row for already entered items with more fields

=item * C<template/webpages/reclamation/tabs/basic_data/_tax_row.html>

Displaying tax information

=item * C<template/webpages/reclamation/tabs/basic_data/_price_sources_dialog.html>

Dialog for selecting price and discount sources

=back

=item * C<js/kivi.Reclamation.js>

java script functions

=back

=head1 KNOWN BUGS AND CAVEATS

=over 4

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

Possibility to select PriceSources in input row?

=item *

This controller uses a (changed) copy of the template for the PriceSource
dialog. Maybe there could be used one code source.

=item *

A warning when leaving the page without saving unchanged inputs.

=back

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
