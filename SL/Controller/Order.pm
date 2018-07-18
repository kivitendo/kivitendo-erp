package SL::Controller::Order;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash_later);
use SL::Presenter::Tag qw(select_tag hidden_tag);
use SL::Locale::String qw(t8);
use SL::SessionFile::Random;
use SL::PriceSource;
use SL::Webdav;
use SL::File;
use SL::Util qw(trim);
use SL::DB::Order;
use SL::DB::Default;
use SL::DB::Unit;
use SL::DB::Part;
use SL::DB::Printer;
use SL::DB::Language;
use SL::DB::RecordLink;

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;

use SL::Controller::Helper::GetModels;

use List::Util qw(first);
use List::UtilsBy qw(sort_by uniq_by);
use List::MoreUtils qw(any none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;
use Cwd;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(item_ids_to_delete) ],
 'scalar --get_set_init' => [ qw(order valid_types type cv p multi_items_models all_price_factors) ],
);


# safety
__PACKAGE__->run_before('_check_auth');

__PACKAGE__->run_before('_recalc',
                        only => [ qw(save save_as_new save_and_delivery_order save_and_invoice print create_pdf send_email) ]);

__PACKAGE__->run_before('_get_unalterable_data',
                        only => [ qw(save save_as_new save_and_delivery_order save_and_invoice print create_pdf send_email) ]);

#
# actions
#

# add a new order
sub action_add {
  my ($self) = @_;

  $self->order->transdate(DateTime->now_local());
  my $extra_days = $self->type eq _sales_quotation_type() ? $::instance_conf->get_reqdate_interval : 1;
  $self->order->reqdate(DateTime->today_local->next_workday(extra_days => $extra_days)) if !$self->order->reqdate;

  $self->_pre_render();
  $self->render(
    'order/form',
    title => $self->_get_title_for('add'),
    %{$self->{template_args}}
  );
}

# edit an existing order
sub action_edit {
  my ($self) = @_;

  $self->_load_order;
  $self->_recalc();
  $self->_pre_render();
  $self->render(
    'order/form',
    title => $self->_get_title_for('edit'),
    %{$self->{template_args}}
  );
}

# delete the order
sub action_delete {
  my ($self) = @_;

  my $errors = $self->_delete();

  if (scalar @{ $errors }) {
    $self->js->flash('error', $_) foreach @{ $errors };
    return $self->js->render();
  }

  my $text = $self->type eq _sales_order_type()       ? $::locale->text('The order has been deleted')
           : $self->type eq _purchase_order_type()    ? $::locale->text('The order has been deleted')
           : $self->type eq _sales_quotation_type()   ? $::locale->text('The quotation has been deleted')
           : $self->type eq _request_quotation_type() ? $::locale->text('The rfq has been deleted')
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

  my $errors = $self->_save();

  if (scalar @{ $errors }) {
    $self->js->flash('error', $_) foreach @{ $errors };
    return $self->js->render();
  }

  my $text = $self->type eq _sales_order_type()       ? $::locale->text('The order has been saved')
           : $self->type eq _purchase_order_type()    ? $::locale->text('The order has been saved')
           : $self->type eq _sales_quotation_type()   ? $::locale->text('The quotation has been saved')
           : $self->type eq _request_quotation_type() ? $::locale->text('The rfq has been saved')
           : '';
  flash_later('info', $text);

  my @redirect_params = (
    action => 'edit',
    type   => $self->type,
    id     => $self->order->id,
  );

  $self->redirect_to(@redirect_params);
}

# save the order as new document an open it for edit
sub action_save_as_new {
  my ($self) = @_;

  my $order = $self->order;

  if (!$order->id) {
    $self->js->flash('error', t8('This object has not been saved yet.'));
    return $self->js->render();
  }

  # load order from db to check if values changed
  my $saved_order = SL::DB::Order->new(id => $order->id)->load;

  my %new_attrs;
  # Lets assign a new number if the user hasn't changed the previous one.
  # If it has been changed manually then use it as-is.
  $new_attrs{number}    = (trim($order->number) eq $saved_order->number)
                        ? ''
                        : trim($order->number);

  # Clear transdate unless changed
  $new_attrs{transdate} = ($order->transdate == $saved_order->transdate)
                        ? DateTime->today_local
                        : $order->transdate;

  # Set new reqdate unless changed
  if ($order->reqdate == $saved_order->reqdate) {
    my $extra_days = $self->type eq _sales_quotation_type() ? $::instance_conf->get_reqdate_interval : 1;
    $new_attrs{reqdate} = DateTime->today_local->next_workday(extra_days => $extra_days);
  } else {
    $new_attrs{reqdate} = $order->reqdate;
  }

  # Update employee
  $new_attrs{employee}  = SL::DB::Manager::Employee->current;

  # Create new record from current one
  $self->order(SL::DB::Order->new_from($order, destination_type => $order->type, attributes => \%new_attrs));

  # no linked records on save as new
  delete $::form->{$_} for qw(converted_from_oe_id converted_from_orderitems_ids);

  # save
  $self->action_save();
}

# print the order
#
# This is called if "print" is pressed in the print dialog.
# If PDF creation was requested and succeeded, the pdf is stored in a session
# file and the filename is stored as session value with an unique key. A
# javascript function with this key is then called. This function calls the
# download action below (action_download_pdf), which offers the file for
# download.
sub action_print {
  my ($self) = @_;

  my $format      = $::form->{print_options}->{format};
  my $media       = $::form->{print_options}->{media};
  my $formname    = $::form->{print_options}->{formname};
  my $copies      = $::form->{print_options}->{copies};
  my $groupitems  = $::form->{print_options}->{groupitems};

  # only pdf by now
  if (none { $format eq $_ } qw(pdf)) {
    return $self->js->flash('error', t8('Format \'#1\' is not supported yet/anymore.', $format))->render;
  }

  # only screen or printer by now
  if (none { $media eq $_ } qw(screen printer)) {
    return $self->js->flash('error', t8('Media \'#1\' is not supported yet/anymore.', $media))->render;
  }

  my $language;
  $language = SL::DB::Language->new(id => $::form->{print_options}->{language_id})->load if $::form->{print_options}->{language_id};

  # create a form for generate_attachment_filename
  my $form = Form->new;
  $form->{ordnumber} = $self->order->ordnumber;
  $form->{type}      = $self->type;
  $form->{format}    = $format;
  $form->{formname}  = $formname;
  $form->{language}  = '_' . $language->template_code if $language;
  my $pdf_filename   = $form->generate_attachment_filename();

  my $pdf;
  my @errors = _create_pdf($self->order, \$pdf, { format     => $format,
                                                  formname   => $formname,
                                                  language   => $language,
                                                  groupitems => $groupitems });
  if (scalar @errors) {
    return $self->js->flash('error', t8('Conversion to PDF failed: #1', $errors[0]))->render;
  }

  if ($media eq 'screen') {
    # screen/download
    my $sfile = SL::SessionFile::Random->new(mode => "w");
    $sfile->fh->print($pdf);
    $sfile->fh->close;

    my $key = join('_', Time::HiRes::gettimeofday(), int rand 1000000000000);
    $::auth->set_session_value("Order::create_pdf-${key}" => $sfile->file_name);

    $self->js
    ->run('kivi.Order.download_pdf', $pdf_filename, $key)
    ->flash('info', t8('The PDF has been created'));

  } elsif ($media eq 'printer') {
    # printer
    my $printer_id = $::form->{print_options}->{printer_id};
    SL::DB::Printer->new(id => $printer_id)->load->print_document(
      copies  => $copies,
      content => $pdf,
    );

    $self->js->flash('info', t8('The PDF has been printed'));
  }

  # copy file to webdav folder
  if ($self->order->ordnumber && $::instance_conf->get_webdav_documents) {
    my $webdav = SL::Webdav->new(
      type     => $self->type,
      number   => $self->order->ordnumber,
    );
    my $webdav_file = SL::Webdav::File->new(
      webdav   => $webdav,
      filename => $pdf_filename,
    );
    eval {
      $webdav_file->store(data => \$pdf);
      1;
    } or do {
      $self->js->flash('error', t8('Storing PDF to webdav folder failed: #1', $@));
    }
  }
  if ($self->order->ordnumber && $::instance_conf->get_doc_storage) {
    eval {
      SL::File->save(object_id     => $self->order->id,
                     object_type   => $self->type,
                     mime_type     => 'application/pdf',
                     source        => 'created',
                     file_type     => 'document',
                     file_name     => $pdf_filename,
                     file_contents => $pdf);
      1;
    } or do {
      $self->js->flash('error', t8('Storing PDF in storage backend failed: #1', $@));
    }
  }
  $self->js->render;
}

# offer pdf for download
#
# It needs to get the key for the session value to get the pdf file.
sub action_download_pdf {
  my ($self) = @_;

  my $key = $::form->{key};
  my $tmp_filename = $::auth->get_session_value("Order::create_pdf-${key}");
  return $self->send_file(
    $tmp_filename,
    type => 'application/pdf',
    name => $::form->{pdf_filename},
  );
}

# open the email dialog
sub action_show_email_dialog {
  my ($self) = @_;

  my $cv_method = $self->cv;

  if (!$self->order->$cv_method) {
    return $self->js->flash('error', $self->cv eq 'customer' ? t8('Cannot send E-mail without customer given') : t8('Cannot send E-mail without vendor given'))
                    ->render($self);
  }

  my $email_form;
  $email_form->{to}   = $self->order->contact->cp_email if $self->order->contact;
  $email_form->{to} ||= $self->order->$cv_method->email;
  $email_form->{cc}   = $self->order->$cv_method->cc;
  $email_form->{bcc}  = join ', ', grep $_, $self->order->$cv_method->bcc, SL::DB::Default->get->global_bcc;
  # Todo: get addresses from shipto, if any

  my $form = Form->new;
  $form->{ordnumber} = $self->order->ordnumber;
  $form->{formname}  = $self->type;
  $form->{type}      = $self->type;
  $form->{language} = 'de';
  $form->{format}   = 'pdf';

  $email_form->{subject}             = $form->generate_email_subject();
  $email_form->{attachment_filename} = $form->generate_attachment_filename();
  $email_form->{message}             = $form->generate_email_body();
  $email_form->{js_send_function}    = 'kivi.Order.send_email()';

  my %files = $self->_get_files_for_email_dialog();
  my $dialog_html = $self->render('common/_send_email_dialog', { output => 0 },
                                  email_form  => $email_form,
                                  show_bcc    => $::auth->assert('email_bcc', 'may fail'),
                                  FILES       => \%files,
                                  is_customer => $self->cv eq 'customer',
  );

  $self->js
      ->run('kivi.Order.show_email_dialog', $dialog_html)
      ->reinit_widgets
      ->render($self);
}

# send email
#
# Todo: handling error messages: flash is not displayed in dialog, but in the main form
sub action_send_email {
  my ($self) = @_;

  my $email_form  = delete $::form->{email_form};
  my %field_names = (to => 'email');

  $::form->{ $field_names{$_} // $_ } = $email_form->{$_} for keys %{ $email_form };

  # for Form::cleanup which may be called in Form::send_email
  $::form->{cwd}    = getcwd();
  $::form->{tmpdir} = $::lx_office_conf{paths}->{userspath};

  $::form->{media}  = 'email';

  if (($::form->{attachment_policy} // '') eq 'normal') {
    my $language;
    $language = SL::DB::Language->new(id => $::form->{print_options}->{language_id})->load if $::form->{print_options}->{language_id};

    my $pdf;
    my @errors = _create_pdf($self->order, \$pdf, {media      => $::form->{media},
                                                   format     => $::form->{print_options}->{format},
                                                   formname   => $::form->{print_options}->{formname},
                                                   language   => $language,
                                                   groupitems => $::form->{print_options}->{groupitems}});
    if (scalar @errors) {
      return $self->js->flash('error', t8('Conversion to PDF failed: #1', $errors[0]))->render($self);
    }

    my $sfile = SL::SessionFile::Random->new(mode => "w");
    $sfile->fh->print($pdf);
    $sfile->fh->close;

    $::form->{tmpfile} = $sfile->file_name;
    $::form->{tmpdir}  = $sfile->get_path; # for Form::cleanup which may be called in Form::send_email
  }

  $::form->send_email(\%::myconfig, 'pdf');

  # internal notes
  my $intnotes = $self->order->intnotes;
  $intnotes   .= "\n\n" if $self->order->intnotes;
  $intnotes   .= t8('[email]')                                                                                        . "\n";
  $intnotes   .= t8('Date')       . ": " . $::locale->format_date_object(DateTime->now_local, precision => 'seconds') . "\n";
  $intnotes   .= t8('To (email)') . ": " . $::form->{email}                                                           . "\n";
  $intnotes   .= t8('Cc')         . ": " . $::form->{cc}                                                              . "\n"    if $::form->{cc};
  $intnotes   .= t8('Bcc')        . ": " . $::form->{bcc}                                                             . "\n"    if $::form->{bcc};
  $intnotes   .= t8('Subject')    . ": " . $::form->{subject}                                                         . "\n\n";
  $intnotes   .= t8('Message')    . ": " . $::form->{message};

  $self->js
      ->val('#order_intnotes', $intnotes)
      ->run('kivi.Order.close_email_dialog')
      ->flash('info', t8('The email has been sent.'))
      ->render($self);
}

# open the periodic invoices config dialog
#
# If there are values in the form (i.e. dialog was opened before),
# then use this values. Create new ones, else.
sub action_show_periodic_invoices_config_dialog {
  my ($self) = @_;

  my $config = _make_periodic_invoices_config_from_yaml(delete $::form->{config});
  $config  ||= SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $::form->{id}) if $::form->{id};
  $config  ||= SL::DB::PeriodicInvoicesConfig->new(periodicity             => 'm',
                                                   order_value_periodicity => 'p', # = same as periodicity
                                                   start_date_as_date      => $::form->{transdate} || $::form->current_date,
                                                   extend_automatically_by => 12,
                                                   active                  => 1,
                                                   email_subject           => GenericTranslations->get(
                                                                                language_id      => $::form->{language_id},
                                                                                translation_type =>"preset_text_periodic_invoices_email_subject"),
                                                   email_body              => GenericTranslations->get(
                                                                                language_id      => $::form->{language_id},
                                                                                translation_type =>"preset_text_periodic_invoices_email_body"),
  );
  $config->periodicity('m')             if none { $_ eq $config->periodicity             }       @SL::DB::PeriodicInvoicesConfig::PERIODICITIES;
  $config->order_value_periodicity('p') if none { $_ eq $config->order_value_periodicity } ('p', @SL::DB::PeriodicInvoicesConfig::ORDER_VALUE_PERIODICITIES);

  $::form->get_lists(printers => "ALL_PRINTERS",
                     charts   => { key       => 'ALL_CHARTS',
                                   transdate => 'current_date' });

  $::form->{AR} = [ grep { $_->{link} =~ m/(?:^|:)AR(?::|$)/ } @{ $::form->{ALL_CHARTS} } ];

  if ($::form->{customer_id}) {
    $::form->{ALL_CONTACTS} = SL::DB::Manager::Contact->get_all_sorted(where => [ cp_cv_id => $::form->{customer_id} ]);
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

  my $config = { active                  => $::form->{active}     ? 1 : 0,
                 terminated              => $::form->{terminated} ? 1 : 0,
                 direct_debit            => $::form->{direct_debit} ? 1 : 0,
                 periodicity             => (any { $_ eq $::form->{periodicity}             }       @SL::DB::PeriodicInvoicesConfig::PERIODICITIES)              ? $::form->{periodicity}             : 'm',
                 order_value_periodicity => (any { $_ eq $::form->{order_value_periodicity} } ('p', @SL::DB::PeriodicInvoicesConfig::ORDER_VALUE_PERIODICITIES)) ? $::form->{order_value_periodicity} : 'p',
                 start_date_as_date      => $::form->{start_date_as_date},
                 end_date_as_date        => $::form->{end_date_as_date},
                 first_billing_date_as_date => $::form->{first_billing_date_as_date},
                 print                   => $::form->{print} ? 1 : 0,
                 printer_id              => $::form->{print} ? $::form->{printer_id} * 1 : undef,
                 copies                  => $::form->{copies} * 1 ? $::form->{copies} : 1,
                 extend_automatically_by => $::form->{extend_automatically_by} * 1 || undef,
                 ar_chart_id             => $::form->{ar_chart_id} * 1,
                 send_email                 => $::form->{send_email} ? 1 : 0,
                 email_recipient_contact_id => $::form->{email_recipient_contact_id} * 1 || undef,
                 email_recipient_address    => $::form->{email_recipient_address},
                 email_sender               => $::form->{email_sender},
                 email_subject              => $::form->{email_subject},
                 email_body                 => $::form->{email_body},
               };

  my $periodic_invoices_config = YAML::Dump($config);

  my $status = $self->_get_periodic_invoices_status($config);

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

  my $config = _make_periodic_invoices_config_from_yaml(delete $::form->{config});
  $config  ||= SL::DB::Manager::PeriodicInvoicesConfig->find_by(oe_id => $::form->{id}) if $::form->{id};

  my $has_active_periodic_invoices =
       $self->type eq _sales_order_type()
    && $config
    && $config->active
    && (!$config->end_date || ($config->end_date > DateTime->today_local))
    && $config->get_previous_billed_period_start_date;

  $_[0]->render(\ !!$has_active_periodic_invoices, { type => 'text' });
}

# save the order and redirect to the frontend subroutine for a new
# delivery order
sub action_save_and_delivery_order {
  my ($self) = @_;

  my $errors = $self->_save();

  if (scalar @{ $errors }) {
    $self->js->flash('error', $_) foreach @{ $errors };
    return $self->js->render();
  }

  my $text = $self->type eq _sales_order_type()       ? $::locale->text('The order has been saved')
           : $self->type eq _purchase_order_type()    ? $::locale->text('The order has been saved')
           : $self->type eq _sales_quotation_type()   ? $::locale->text('The quotation has been saved')
           : $self->type eq _request_quotation_type() ? $::locale->text('The rfq has been saved')
           : '';
  flash_later('info', $text);

  my @redirect_params = (
    controller => 'oe.pl',
    action     => 'oe_delivery_order_from_order',
    id         => $self->order->id,
  );

  $self->redirect_to(@redirect_params);
}

# save the order and redirect to the frontend subroutine for a new
# invoice
sub action_save_and_invoice {
  my ($self) = @_;

  my $errors = $self->_save();

  if (scalar @{ $errors }) {
    $self->js->flash('error', $_) foreach @{ $errors };
    return $self->js->render();
  }

  my $text = $self->type eq _sales_order_type()       ? $::locale->text('The order has been saved')
           : $self->type eq _purchase_order_type()    ? $::locale->text('The order has been saved')
           : $self->type eq _sales_quotation_type()   ? $::locale->text('The quotation has been saved')
           : $self->type eq _request_quotation_type() ? $::locale->text('The rfq has been saved')
           : '';
  flash_later('info', $text);

  my @redirect_params = (
    controller => 'oe.pl',
    action     => 'oe_invoice_from_order',
    id         => $self->order->id,
  );

  $self->redirect_to(@redirect_params);
}

# workflow from sales quotation to sales order
sub action_sales_order {
  $_[0]->_workflow_sales_or_purchase_order();
}

# workflow from rfq to purchase order
sub action_purchase_order {
  $_[0]->_workflow_sales_or_purchase_order();
}

# set form elements in respect to a changed customer or vendor
#
# This action is called on an change of the customer/vendor picker.
sub action_customer_vendor_changed {
  my ($self) = @_;

  _setup_order_from_cv($self->order);
  $self->_recalc();

  my $cv_method = $self->cv;

  if ($self->order->$cv_method->contacts && scalar @{ $self->order->$cv_method->contacts } > 0) {
    $self->js->show('#cp_row');
  } else {
    $self->js->hide('#cp_row');
  }

  if ($self->order->$cv_method->shipto && scalar @{ $self->order->$cv_method->shipto } > 0) {
    $self->js->show('#shipto_row');
  } else {
    $self->js->hide('#shipto_row');
  }

  $self->js->val( '#order_salesman_id',      $self->order->salesman_id)        if $self->order->is_sales;

  $self->js
    ->replaceWith('#order_cp_id',            $self->build_contact_select)
    ->replaceWith('#order_shipto_id',        $self->build_shipto_select)
    ->replaceWith('#business_info_row',      $self->build_business_info_row)
    ->val(        '#order_taxzone_id',       $self->order->taxzone_id)
    ->val(        '#order_taxincluded',      $self->order->taxincluded)
    ->val(        '#order_payment_id',       $self->order->payment_id)
    ->val(        '#order_delivery_term_id', $self->order->delivery_term_id)
    ->val(        '#order_intnotes',         $self->order->intnotes)
    ->focus(      '#order_' . $self->cv . '_id');

  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# open the dialog for customer/vendor details
sub action_show_customer_vendor_details_dialog {
  my ($self) = @_;

  my $is_customer = 'customer' eq $::form->{vc};
  my $cv;
  if ($is_customer) {
    $cv = SL::DB::Customer->new(id => $::form->{vc_id})->load;
  } else {
    $cv = SL::DB::Vendor->new(id => $::form->{vc_id})->load;
  }

  my %details = map { $_ => $cv->$_ } @{$cv->meta->columns};
  $details{discount_as_percent} = $cv->discount_as_percent;
  $details{creditlimt}          = $cv->creditlimit_as_number;
  $details{business}            = $cv->business->description      if $cv->business;
  $details{language}            = $cv->language_obj->description  if $cv->language_obj;
  $details{delivery_terms}      = $cv->delivery_term->description if $cv->delivery_term;
  $details{payment_terms}       = $cv->payment->description       if $cv->payment;
  $details{pricegroup}          = $cv->pricegroup->pricegroup     if $is_customer && $cv->pricegroup;

  foreach my $entry (@{ $cv->shipto }) {
    push @{ $details{SHIPTO} },   { map { $_ => $entry->$_ } @{$entry->meta->columns} };
  }
  foreach my $entry (@{ $cv->contacts }) {
    push @{ $details{CONTACTS} }, { map { $_ => $entry->$_ } @{$entry->meta->columns} };
  }

  $_[0]->render('common/show_vc_details', { layout => 0 },
                is_customer => $is_customer,
                %details);

}

# called if a unit in an existing item row is changed
sub action_unit_changed {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{orderitem_ids} };
  my $item = $self->order->items_sorted->[$idx];

  my $old_unit_obj = SL::DB::Unit->new(name => $::form->{old_unit})->load;
  $item->sellprice($item->unit_obj->convert_to($item->sellprice, $old_unit_obj));

  $self->_recalc();

  $self->js
    ->run('kivi.Order.update_sellprice', $::form->{item_id}, $item->sellprice_as_number);
  $self->_js_redisplay_line_values;
  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# add an item row for a new item entered in the input row
sub action_add_item {
  my ($self) = @_;

  my $form_attr = $::form->{add_item};

  return unless $form_attr->{parts_id};

  my $item = _new_item($self->order, $form_attr);

  $self->order->add_items($item);

  $self->_recalc();

  my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $row_as_html = $self->p->render('order/tabs/_row',
                                     ITEM              => $item,
                                     ID                => $item_id,
                                     TYPE              => $self->type,
                                     ALL_PRICE_FACTORS => $self->all_price_factors
  );

  $self->js
    ->append('#row_table_id', $row_as_html);

  if ( $item->part->is_assortment ) {
    $form_attr->{qty_as_number} = 1 unless $form_attr->{qty_as_number};
    foreach my $assortment_item ( @{$item->part->assortment_items} ) {
      my $attr = { parts_id => $assortment_item->parts_id,
                   qty      => $assortment_item->qty * $::form->parse_amount(\%::myconfig, $form_attr->{qty_as_number}), # TODO $form_attr->{unit}
                   unit     => $assortment_item->unit,
                   description => $assortment_item->part->description,
                 };
      my $item = _new_item($self->order, $attr);

      # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
      $item->discount(1) unless $assortment_item->charge;

      $self->order->add_items( $item );
      $self->_recalc();
      my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
      my $row_as_html = $self->p->render('order/tabs/_row',
                                         ITEM              => $item,
                                         ID                => $item_id,
                                         TYPE              => $self->type,
                                         ALL_PRICE_FACTORS => $self->all_price_factors
      );
      $self->js
        ->append('#row_table_id', $row_as_html);
    };
  };

  $self->js
    ->val('.add_item_input', '')
    ->run('kivi.Order.init_row_handlers')
    ->run('kivi.Order.row_table_scroll_down')
    ->run('kivi.Order.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# open the dialog for entering multiple items at once
sub action_show_multi_items_dialog {
  require SL::DB::PartsGroup;
  $_[0]->render('order/tabs/_multi_items_dialog', { layout => 0 },
                all_partsgroups => SL::DB::Manager::PartsGroup->get_all);
}

# update the filter results in the multi item dialog
sub action_multi_items_update_result {
  my $max_count = 100;

  $::form->{multi_items}->{filter}->{obsolete} = 0;

  my $count = $_[0]->multi_items_models->count;

  if ($count == 0) {
    my $text = SL::Presenter::EscapedText->new(text => $::locale->text('No results.'));
    $_[0]->render($text, { layout => 0 });
  } elsif ($count > $max_count) {
    my $text = SL::Presenter::EscapedText->new(text => $::locale->text('Too many results (#1 from #2).', $count, $max_count));
    $_[0]->render($text, { layout => 0 });
  } else {
    my $multi_items = $_[0]->multi_items_models->get;
    $_[0]->render('order/tabs/_multi_items_result', { layout => 0 },
                  multi_items => $multi_items);
  }
}

# add item rows for multiple items at once
sub action_add_multi_items {
  my ($self) = @_;

  my @form_attr = grep { $_->{qty_as_number} } @{ $::form->{add_multi_items} };
  return $self->js->render() unless scalar @form_attr;

  my @items;
  foreach my $attr (@form_attr) {
    my $item = _new_item($self->order, $attr);
    push @items, $item;
    if ( $item->part->is_assortment ) {
      foreach my $assortment_item ( @{$item->part->assortment_items} ) {
        my $attr = { parts_id => $assortment_item->parts_id,
                     qty      => $assortment_item->qty * $item->qty, # TODO $form_attr->{unit}
                     unit     => $assortment_item->unit,
                     description => $assortment_item->part->description,
                   };
        my $item = _new_item($self->order, $attr);

        # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
        $item->discount(1) unless $assortment_item->charge;
        push @items, $item;
      }
    }
  }
  $self->order->add_items(@items);

  $self->_recalc();

  foreach my $item (@items) {
    my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
    my $row_as_html = $self->p->render('order/tabs/_row',
                                       ITEM              => $item,
                                       ID                => $item_id,
                                       TYPE              => $self->type,
                                       ALL_PRICE_FACTORS => $self->all_price_factors
    );

    $self->js->append('#row_table_id', $row_as_html);
  }

  $self->js
    ->run('kivi.Order.close_multi_items_dialog')
    ->run('kivi.Order.init_row_handlers')
    ->run('kivi.Order.row_table_scroll_down')
    ->run('kivi.Order.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# recalculate all linetotals, amounts and taxes and redisplay them
sub action_recalc_amounts_and_taxes {
  my ($self) = @_;

  $self->_recalc();

  $self->_js_redisplay_line_values;
  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# redisplay item rows if they are sorted by an attribute
sub action_reorder_items {
  my ($self) = @_;

  my %sort_keys = (
    partnumber  => sub { $_[0]->part->partnumber },
    description => sub { $_[0]->description },
    qty         => sub { $_[0]->qty },
    sellprice   => sub { $_[0]->sellprice },
    discount    => sub { $_[0]->discount },
  );

  my $method = $sort_keys{$::form->{order_by}};
  my @to_sort = map { { old_pos => $_->position, order_by => $method->($_) } } @{ $self->order->items_sorted };
  if ($::form->{sort_dir}) {
    @to_sort = sort { $a->{order_by} cmp $b->{order_by} } @to_sort;
  } else {
    @to_sort = sort { $b->{order_by} cmp $a->{order_by} } @to_sort;
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

# get the longdescription for an item if the dialog to enter/change the
# longdescription was opened and the longdescription is empty
#
# If this item is new, get the longdescription from Part.
# Otherwise get it from OrderItem.
sub action_get_item_longdescription {
  my $longdescription;

  if ($::form->{item_id}) {
    $longdescription = SL::DB::OrderItem->new(id => $::form->{item_id})->load->longdescription;
  } elsif ($::form->{parts_id}) {
    $longdescription = SL::DB::Part->new(id => $::form->{parts_id})->load->notes;
  }
  $_[0]->render(\ $longdescription, { type => 'text' });
}

# load the second row for one or more items
#
# This action gets the html code for all items second rows by rendering a template for
# the second row and sets the html code via client js.
sub action_load_second_rows {
  my ($self) = @_;

  $self->_recalc() if $self->order->is_sales; # for margin calculation

  foreach my $item_id (@{ $::form->{item_ids} }) {
    my $idx  = first_index { $_ eq $item_id } @{ $::form->{orderitem_ids} };
    my $item = $self->order->items_sorted->[$idx];

    $self->_js_load_second_row($item, $item_id, 0);
  }

  $self->js->run('kivi.Order.init_row_handlers') if $self->order->is_sales; # for lastcosts change-callback

  $self->js->render();
}

sub _js_load_second_row {
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
    ->html('.row_entry:has(#item_' . $item_id . ') [name = "second_row"]', $row_as_html)
    ->data('.row_entry:has(#item_' . $item_id . ') [name = "second_row"]', 'loaded', 1);
}

sub _js_redisplay_line_values {
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

sub _js_redisplay_amounts_and_taxes {
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

  $self->js
    ->html('#netamount_id', $::form->format_amount(\%::myconfig, $self->order->netamount, -2))
    ->html('#amount_id',    $::form->format_amount(\%::myconfig, $self->order->amount,    -2))
    ->remove('.tax_row')
    ->insertBefore($self->build_tax_rows, '#amount_row_id');
}

#
# helpers
#

sub init_valid_types {
  [ _sales_order_type(), _purchase_order_type(), _sales_quotation_type(), _request_quotation_type() ];
}

sub init_type {
  my ($self) = @_;

  if (none { $::form->{type} eq $_ } @{$self->valid_types}) {
    die "Not a valid type for order";
  }

  $self->type($::form->{type});
}

sub init_cv {
  my ($self) = @_;

  my $cv = (any { $self->type eq $_ } (_sales_order_type(),    _sales_quotation_type()))   ? 'customer'
         : (any { $self->type eq $_ } (_purchase_order_type(), _request_quotation_type())) ? 'vendor'
         : die "Not a valid type for order";

  return $cv;
}

sub init_p {
  SL::Presenter->get;
}

sub init_order {
  $_[0]->_make_order;
}

# model used to filter/display the parts in the multi-items dialog
sub init_multi_items_models {
  SL::Controller::Helper::GetModels->new(
    controller     => $_[0],
    model          => 'Part',
    with_objects   => [ qw(unit_obj) ],
    disable_plugin => 'paginated',
    source         => $::form->{multi_items},
    sorted         => {
      _default    => {
        by  => 'partnumber',
        dir => 1,
      },
      partnumber  => t8('Partnumber'),
      description => t8('Description')}
  );
}

sub init_all_price_factors {
  SL::DB::Manager::PriceFactor->get_all;
}

sub _check_auth {
  my ($self) = @_;

  my $right_for = { map { $_ => $_.'_edit' } @{$self->valid_types} };

  my $right   = $right_for->{ $self->type };
  $right    ||= 'DOES_NOT_EXIST';

  $::auth->assert($right);
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

# build the selection box for shiptos
#
# Needed, if customer/vendor changed.
sub build_shipto_select {
  my ($self) = @_;

  select_tag('order.shipto_id', [ $self->order->{$self->cv}->shipto ],
    value_key  => 'shipto_id',
    title_key  => 'displayable_id',
    default    => $self->order->shipto_id,
    with_empty => 1,
    style      => 'width: 300px',
  );
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
    $rows_as_html .= $self->p->render('order/tabs/_tax_row', TAX => $tax, TAXINCLUDED => $self->order->taxincluded);
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

sub _load_order {
  my ($self) = @_;

  return if !$::form->{id};

  $self->order(SL::DB::Manager::Order->find_by(id => $::form->{id}));
}

# load or create a new order object
#
# And assign changes from the form to this object.
# If the order is loaded from db, check if items are deleted in the form,
# remove them form the object and collect them for removing from db on saving.
# Then create/update items from form (via _make_item) and add them.
sub _make_order {
  my ($self) = @_;

  # add_items adds items to an order with no items for saving, but they cannot
  # be retrieved via items until the order is saved. Adding empty items to new
  # order here solves this problem.
  my $order;
  $order   = SL::DB::Manager::Order->find_by(id => $::form->{id}) if $::form->{id};
  $order ||= SL::DB::Order->new(orderitems => [],
                                quotation  => (any { $self->type eq $_ } (_sales_quotation_type(), _request_quotation_type())));

  my $cv_id_method = $self->cv . '_id';
  if (!$::form->{id} && $::form->{$cv_id_method}) {
    $order->$cv_id_method($::form->{$cv_id_method});
    _setup_order_from_cv($order);
  }

  my $form_orderitems               = delete $::form->{order}->{orderitems};
  my $form_periodic_invoices_config = delete $::form->{order}->{periodic_invoices_config};

  $order->assign_attributes(%{$::form->{order}});

  my $periodic_invoices_config = _make_periodic_invoices_config_from_yaml($form_periodic_invoices_config);
  $order->periodic_invoices_config($periodic_invoices_config) if $periodic_invoices_config;

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
    my $item = _make_item($order, $form_attr);
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
sub _make_item {
  my ($record, $attr) = @_;

  my $item;
  $item = first { $_->id == $attr->{id} } @{$record->items} if $attr->{id};

  my $is_new = !$item;

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $item ||= SL::DB::OrderItem->new(custom_variables => []);

  $item->assign_attributes(%$attr);
  $item->longdescription($item->part->notes)                     if $is_new && !defined $attr->{longdescription};
  $item->project_id($record->globalproject_id)                   if $is_new && !defined $attr->{project_id};
  $item->lastcost($record->is_sales ? $item->part->lastcost : 0) if $is_new && !defined $attr->{lastcost_as_number};

  return $item;
}

# create a new item
#
# This is used to add one item
sub _new_item {
  my ($record, $attr) = @_;

  my $item = SL::DB::OrderItem->new;
  $item->assign_attributes(%$attr);

  my $part         = SL::DB::Part->new(id => $attr->{parts_id})->load;
  my $price_source = SL::PriceSource->new(record_item => $item, record => $record);

  $item->unit($part->unit) if !$item->unit;

  my $price_src;
  if ( $part->is_assortment ) {
    # add assortment items with price 0, as the components carry the price
    $price_src = $price_source->price_from_source("");
    $price_src->price(0);
  } elsif ($item->sellprice) {
    $price_src = $price_source->price_from_source("");
    $price_src->price($item->sellprice);
  } else {
    $price_src = $price_source->best_price
           ? $price_source->best_price
           : $price_source->price_from_source("");
    $price_src->price(0) if !$price_source->best_price;
  }

  my $discount_src;
  if ($item->discount) {
    $discount_src = $price_source->discount_from_source("");
    $discount_src->discount($item->discount);
  } else {
    $discount_src = $price_source->best_discount
                  ? $price_source->best_discount
                  : $price_source->discount_from_source("");
    $discount_src->discount(0) if !$price_source->best_discount;
  }

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

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $new_attr{custom_variables} = [];

  $item->assign_attributes(%new_attr);

  return $item;
}

sub _setup_order_from_cv {
  my ($order) = @_;

  $order->$_($order->customervendor->$_) for (qw(taxzone_id payment_id delivery_term_id));

  $order->intnotes($order->customervendor->notes);

  if ($order->is_sales) {
    $order->salesman_id($order->customer->salesman_id);
    $order->taxincluded(defined($order->customer->taxincluded_checked)
                        ? $order->customer->taxincluded_checked
                        : $::myconfig{taxincluded_checked});
  }

}

# recalculate prices and taxes
#
# Using the PriceTaxCalculator. Store linetotals in the item objects.
sub _recalc {
  my ($self) = @_;

  # bb: todo: currency later
  $self->order->currency_id($::instance_conf->get_currency_id());

  my %pat = $self->order->calculate_prices_and_taxes();
  $self->{taxes} = [];
  foreach my $tax_chart_id (keys %{ $pat{taxes} }) {
    my $tax = SL::DB::Manager::Tax->find_by(chart_id => $tax_chart_id);

    my @amount_keys = grep { $pat{amounts}->{$_}->{tax_id} == $tax->id } keys %{ $pat{amounts} };
    push(@{ $self->{taxes} }, { amount    => $pat{taxes}->{$tax_chart_id},
                                netamount => $pat{amounts}->{$amount_keys[0]}->{amount},
                                tax       => $tax });
  }

  pairwise { $a->{linetotal} = $b->{linetotal} } @{$self->order->items}, @{$pat{items}};
}

# get data for saving, printing, ..., that is not changed in the form
#
# Only cvars for now.
sub _get_unalterable_data {
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

# delete the order
#
# And remove related files in the spool directory
sub _delete {
  my ($self) = @_;

  my $errors = [];
  my $db     = $self->order->db;

  $db->with_transaction(
    sub {
      my @spoolfiles = grep { $_ } map { $_->spoolfile } @{ SL::DB::Manager::Status->get_all(where => [ trans_id => $self->order->id ]) };
      $self->order->delete;
      my $spool = $::lx_office_conf{paths}->{spool};
      unlink map { "$spool/$_" } @spoolfiles if $spool;

      1;
  }) || push(@{$errors}, $db->error);

  return $errors;
}

# save the order
#
# And delete items that are deleted in the form.
sub _save {
  my ($self) = @_;

  my $errors = [];
  my $db     = $self->order->db;

  $db->with_transaction(sub {
    SL::DB::OrderItem->new(id => $_)->delete for @{$self->item_ids_to_delete};
    $self->order->save(cascade => 1);

    # link records
    if ($::form->{converted_from_oe_id}) {
      SL::DB::Order->new(id => $::form->{converted_from_oe_id})->load->link_to_record($self->order);

      if (scalar @{ $::form->{converted_from_orderitems_ids} || [] }) {
        my $idx = 0;
        foreach (@{ $self->order->items_sorted }) {
          my $from_id = $::form->{converted_from_orderitems_ids}->[$idx];
          next if !$from_id;
          SL::DB::RecordLink->new(from_table => 'orderitems',
                                  from_id    => $from_id,
                                  to_table   => 'orderitems',
                                  to_id      => $_->id
          )->save;
          $idx++;
        }
      }
    }
    1;
  }) || push(@{$errors}, $db->error);

  return $errors;
}

sub _workflow_sales_or_purchase_order {
  my ($self) = @_;

  my $destination_type = $::form->{type} eq _sales_quotation_type()   ? _sales_order_type()
                       : $::form->{type} eq _request_quotation_type() ? _purchase_order_type()
                       : $::form->{type} eq _purchase_order_type()    ? _sales_order_type()
                       : $::form->{type} eq _sales_order_type()       ? _purchase_order_type()
                       : '';

  $self->order(SL::DB::Order->new_from($self->order, destination_type => $destination_type));
  $self->{converted_from_oe_id} = delete $::form->{id};

  # set item ids to new fake id, to identify them as new items
  foreach my $item (@{$self->order->items_sorted}) {
    $item->{new_fake_id} = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  }

  # change form type
  $::form->{type} = $destination_type;
  $self->type($self->init_type);
  $self->cv  ($self->init_cv);
  $self->_check_auth;

  $self->_recalc();
  $self->_get_unalterable_data();
  $self->_pre_render();

  # trigger rendering values for second row/longdescription as hidden,
  # because they are loaded only on demand. So we need to keep the values
  # from the source.
  $_->{render_second_row}      = 1 for @{ $self->order->items_sorted };
  $_->{render_longdescription} = 1 for @{ $self->order->items_sorted };

  $self->render(
    'order/form',
    title => $self->_get_title_for('edit'),
    %{$self->{template_args}}
  );
}


sub _pre_render {
  my ($self) = @_;

  $self->{all_taxzones}             = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_departments}          = SL::DB::Manager::Department->get_all_sorted();
  $self->{all_employees}            = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->order->employee_id,
                                                                                            deleted => 0 ] ],
                                                                         sort_by => 'name');
  $self->{all_salesmen}             = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->order->salesman_id,
                                                                                            deleted => 0 ] ],
                                                                         sort_by => 'name');
  $self->{all_projects}             = SL::DB::Manager::Project->get_all(where => [ or => [ id => $self->order->globalproject_id,
                                                                                           active => 1 ] ],
                                                                        sort_by => 'projectnumber');
  $self->{all_payment_terms}        = SL::DB::Manager::PaymentTerm->get_all_sorted(where => [ or => [ id => $self->order->payment_id,
                                                                                                      obsolete => 0 ] ]);
  $self->{all_delivery_terms}       = SL::DB::Manager::DeliveryTerm->get_all_sorted();
  $self->{current_employee_id}      = SL::DB::Manager::Employee->current->id;
  $self->{periodic_invoices_status} = $self->_get_periodic_invoices_status($self->order->periodic_invoices_config);
  $self->{order_probabilities}      = [ map { { title => ($_ * 10) . '%', id => $_ * 10 } } (0..10) ];

  my $print_form = Form->new('');
  $print_form->{type}      = $self->type;
  $print_form->{printers}  = SL::DB::Manager::Printer->get_all_sorted;
  $print_form->{languages} = SL::DB::Manager::Language->get_all_sorted;
  $self->{print_options}   = SL::Helper::PrintOptions->get_print_options(
    form => $print_form,
    options => {dialog_name_prefix => 'print_options.',
                show_headers       => 1,
                no_queue           => 1,
                no_postscript      => 1,
                no_opendocument    => 1,
                no_html            => 1},
  );

  foreach my $item (@{$self->order->orderitems}) {
    my $price_source = SL::PriceSource->new(record_item => $item, record => $self->order);
    $item->active_price_source(   $price_source->price_from_source(   $item->active_price_source   ));
    $item->active_discount_source($price_source->discount_from_source($item->active_discount_source));
  }

  if ($self->order->ordnumber && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => $self->type,
      number   => $self->order->ordnumber,
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $self->{template_args}->{WEBDAV} } = map { { name => $_->filename,
                                                    type => t8('File'),
                                                    link => File::Spec->catfile($_->full_filedescriptor),
                                                } } @all_objects;
  }

  $::request->{layout}->use_javascript("${_}.js") for qw(kivi.SalesPurchase kivi.Order kivi.File ckeditor/ckeditor ckeditor/adapters/jquery edit_periodic_invoices_config calculate_qty);
  $self->_setup_edit_action_bar;
}

sub _setup_edit_action_bar {
  my ($self, %params) = @_;

  my $deletion_allowed = (any { $self->type eq $_ } (_sales_quotation_type(), _request_quotation_type()))
                      || (($self->type eq _sales_order_type())    && $::instance_conf->get_sales_order_show_delete)
                      || (($self->type eq _purchase_order_type()) && $::instance_conf->get_purchase_order_show_delete);

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          call      => [ 'kivi.Order.save', 'save', $::instance_conf->get_order_warn_duplicate_parts,
                                                    $::instance_conf->get_order_warn_no_deliverydate,
                                                                                                      ],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices' ],
        ],
        action => [
          t8('Save as new'),
          call      => [ 'kivi.Order.save', 'save_as_new', $::instance_conf->get_order_warn_duplicate_parts ],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices' ],
          disabled  => !$self->order->id ? t8('This object has not been saved yet.') : undef,
        ],
        action => [
          t8('Save and Delivery Order'),
          call      => [ 'kivi.Order.save', 'save_and_delivery_order', $::instance_conf->get_order_warn_duplicate_parts,
                                                                       $::instance_conf->get_order_warn_no_deliverydate,
                                                                                                                        ],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices' ],
          only_if   => (any { $self->type eq $_ } (_sales_order_type(), _purchase_order_type()))
        ],
        action => [
          t8('Save and Invoice'),
          call      => [ 'kivi.Order.save', 'save_and_invoice', $::instance_conf->get_order_warn_duplicate_parts ],
          checks    => [ 'kivi.Order.check_save_active_periodic_invoices' ],
        ],
      ], # end of combobox "Save"

      combobox => [
        action => [
          t8('Workflow'),
        ],
        action => [
          t8('Sales Order'),
          submit   => [ '#order_form', { action => "Order/sales_order" } ],
          only_if  => (any { $self->type eq $_ } (_sales_quotation_type(), _purchase_order_type())),
          disabled => !$self->order->id ? t8('This object has not been saved yet.') : undef,
        ],
        action => [
          t8('Purchase Order'),
          submit   => [ '#order_form', { action => "Order/purchase_order" } ],
          only_if  => (any { $self->type eq $_ } (_sales_order_type(), _request_quotation_type())),
          disabled => !$self->order->id ? t8('This object has not been saved yet.') : undef,
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [
          t8('Export'),
        ],
        action => [
          t8('Print'),
          call => [ 'kivi.Order.show_print_options' ],
        ],
        action => [
          t8('E-mail'),
          call => [ 'kivi.Order.email' ],
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
        disabled => !$self->order->id ? t8('This object has not been saved yet.') : undef,
        only_if  => $deletion_allowed,
      ],
    );
  }
}

sub _create_pdf {
  my ($order, $pdf_ref, $params) = @_;

  my @errors = ();

  my $print_form = Form->new('');
  $print_form->{type}        = $order->type;
  $print_form->{formname}    = $params->{formname} || $order->type;
  $print_form->{format}      = $params->{format}   || 'pdf';
  $print_form->{media}       = $params->{media}    || 'file';
  $print_form->{groupitems}  = $params->{groupitems};
  $print_form->{media}       = 'file'                             if $print_form->{media} eq 'screen';

  $order->language($params->{language});
  $order->flatten_to_form($print_form, format_amounts => 1);

  # search for the template
  my ($template_file, @template_files) = SL::Helper::CreatePDF->find_template(
    name        => $print_form->{formname},
    email       => $print_form->{media} eq 'email',
    language    => $params->{language},
    printer_id  => $print_form->{printer_id},  # todo
  );

  if (!defined $template_file) {
    push @errors, $::locale->text('Cannot find matching template for this print request. Please contact your template maintainer. I tried these: #1.', join ', ', map { "'$_'"} @template_files);
  }

  return @errors if scalar @errors;

  $print_form->throw_on_error(sub {
    eval {
      $print_form->prepare_for_printing;

      $$pdf_ref = SL::Helper::CreatePDF->create_pdf(
        template  => $template_file,
        variables => $print_form,
        variable_content_types => {
          longdescription => 'html',
          partnotes       => 'html',
          notes           => 'html',
        },
      );
      1;
    } || push @errors, ref($EVAL_ERROR) eq 'SL::X::FormError' ? $EVAL_ERROR->getMessage : $EVAL_ERROR;
  });

  return @errors;
}

sub _get_files_for_email_dialog {
  my ($self) = @_;

  my %files = map { ($_ => []) } qw(versions files vc_files part_files);

  return %files if !$::instance_conf->get_doc_storage;

  if ($self->order->id) {
    $files{versions} = [ SL::File->get_all_versions(object_id => $self->order->id,              object_type => $self->order->type, file_type => 'document') ];
    $files{files}    = [ SL::File->get_all(         object_id => $self->order->id,              object_type => $self->order->type, file_type => 'attachment') ];
    $files{vc_files} = [ SL::File->get_all(         object_id => $self->order->{$self->cv}->id, object_type => $self->cv,          file_type => 'attachment') ];
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

sub _make_periodic_invoices_config_from_yaml {
  my ($yaml_config) = @_;

  return if !$yaml_config;
  my $attr = YAML::Load($yaml_config);
  return if 'HASH' ne ref $attr;
  return SL::DB::PeriodicInvoicesConfig->new(%$attr);
}


sub _get_periodic_invoices_status {
  my ($self, $config) = @_;

  return                      if $self->type ne _sales_order_type();
  return t8('not configured') if !$config;

  my $active = ('HASH' eq ref $config)                           ? $config->{active}
             : ('SL::DB::PeriodicInvoicesConfig' eq ref $config) ? $config->active
             :                                                     die "Cannot get status of periodic invoices config";

  return $active ? t8('active') : t8('inactive');
}

sub _get_title_for {
  my ($self, $action) = @_;

  return '' if none { lc($action)} qw(add edit);

  # for locales:
  # $::locale->text("Add Sales Order");
  # $::locale->text("Add Purchase Order");
  # $::locale->text("Add Quotation");
  # $::locale->text("Add Request for Quotation");
  # $::locale->text("Edit Sales Order");
  # $::locale->text("Edit Purchase Order");
  # $::locale->text("Edit Quotation");
  # $::locale->text("Edit Request for Quotation");

  $action = ucfirst(lc($action));
  return $self->type eq _sales_order_type()       ? $::locale->text("$action Sales Order")
       : $self->type eq _purchase_order_type()    ? $::locale->text("$action Purchase Order")
       : $self->type eq _sales_quotation_type()   ? $::locale->text("$action Quotation")
       : $self->type eq _request_quotation_type() ? $::locale->text("$action Request for Quotation")
       : '';
}

sub _sales_order_type {
  'sales_order';
}

sub _purchase_order_type {
  'purchase_order';
}

sub _sales_quotation_type {
  'sales_quotation';
}

sub _request_quotation_type {
  'request_quotation';
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::Order - controller for orders

=head1 SYNOPSIS

This is a new form to enter orders, completely rewritten with the use
of controller and java script techniques.

The aim is to provide the user a better expirience and a faster flow
of work. Also the code should be more readable, more reliable and
better to maintain.

=head2 Key Features

=over 4

=item *

One input row, so that input happens every time at the same place.

=item *

Use of pickers where possible.

=item *

Possibility to enter more than one item at once.

=item *

Save order only on "save" (and "save and delivery order"-workflow). No
hidden save on "print" or "email".

=item *

Item list in a scrollable area, so that the workflow buttons stay at
the bottom.

=item *

Reordering item rows with drag and drop is possible. Sorting item rows is
possible (by partnumber, description, qty, sellprice and discount for now).

=item *

No C<update> is necessary. All entries and calculations are managed
with ajax-calls and the page does only reload on C<save>.

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

=item * C<template/webpages/order/tabs/_multi_items_dialog.html>

Dialog for entering more than one item at once

=item * C<template/webpages/order/tabs/_multi_items_result.html>

Results for the filter in the multi items dialog

=item * C<template/webpages/order/tabs/_price_sources_dialog.html>

Dialog for selecting price and discount sources

=back

=item * C<js/kivi.Order.js>

java script functions

=back

=head1 TODO

=over 4

=item * testing

=item * currency

=item * credit limit

=item * more workflows (save as new, quotation, purchase order)

=item * price sources: little symbols showing better price / better discount

=item * select units in input row?

=item * custom shipto address

=item * check for direct delivery (workflow sales order -> purchase order)

=item * language / part translations

=item * access rights

=item * display weights

=item * history

=item * mtime check

=item * optional client/user behaviour

(transactions has to be set - department has to be set -
 force project if enabled in client config - transport cost reminder)

=back

=head1 KNOWN BUGS AND CAVEATS

=over 4

=item *

Customer discount is not displayed as a valid discount in price source popup
(this might be a bug in price sources)

(I cannot reproduce this (Bernd))

=item *

No indication that <shift>-up/down expands/collapses second row.

=item *

Inline creation of parts is not currently supported

=item *

Table header is not sticky in the scrolling area.

=item *

Sorting does not include C<position>, neither does reordering.

This behavior was implemented intentionally. But we can discuss, which behavior
should be implemented.

=item *

C<show_multi_items_dialog> does not use the currently inserted string for
filtering.

=item *

The language selected in print or email dialog is not saved when the order is saved.

=back

=head1 To discuss / Nice to have

=over 4

=item *

How to expand/collapse second row. Now it can be done clicking the icon or
<shift>-up/down.

=item *

Possibility to change longdescription in input row?

=item *

Possibility to select PriceSources in input row?

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

A warning when leaving the page without saveing unchanged inputs.

=item *

Workflows for delivery order and invoice are in the menu "Save", because the
order is saved before opening the new document form. Nevertheless perhaps these
workflow buttons should be put under "Workflows".


=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
