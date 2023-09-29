package SL::Controller::DeliveryOrder;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash_later);
use SL::Helper::Number qw(_format_number _parse_number);
use SL::Presenter::Tag qw(select_tag hidden_tag div_tag);
use SL::Presenter::DeliveryOrder qw(delivery_order_status_line);
use SL::Locale::String qw(t8);
use SL::SessionFile::Random;
use SL::PriceSource;
use SL::Webdav;
use SL::File;
use SL::MIME;
use SL::YAML;
use SL::DB::History;
use SL::DB::Order;
use SL::DB::Default;
use SL::DB::Unit;
use SL::DB::Order;
use SL::DB::Part;
use SL::DB::PartClassification;
use SL::DB::PartsGroup;
use SL::DB::Printer;
use SL::DB::Language;
use SL::DB::Reclamation;
use SL::DB::RecordLink;
use SL::DB::Shipto;
use SL::DB::Translation;
use SL::DB::TransferType;
use SL::DB::ValidityToken;
use SL::DB::Warehouse;
use SL::DB::Helper::RecordLink qw(set_record_link_conversions RECORD_ID RECORD_ITEM_ID);
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Helper::Record qw(get_object_name_from_type get_class_from_type);
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Order::TypeData qw(:types);
use SL::DB::Manager::DeliveryOrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::Model::Record;

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;
use SL::Helper::ShippedQty;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Helper::UserPreferences::PositionsScrollbar;
use SL::Helper::UserPreferences::UpdatePositions;

use SL::Controller::Helper::GetModels;

use List::Util qw(first sum0);
use List::UtilsBy qw(sort_by uniq_by);
use List::MoreUtils qw(any none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;
use Cwd;
use Sort::Naturally;

use Rose::Object::MakeMethods::Generic (
    scalar => [qw(item_ids_to_delete is_custom_shipto_to_delete)],
    'scalar --get_set_init' => [ qw(
      order valid_types type cv p all_price_factors search_cvpartnumber
      show_update_button part_picker_classification_ids type_data
      ) ],
);


# safety
__PACKAGE__->run_before('check_auth',
  except => [ qw(
    update_stock_information
    ) ]);

__PACKAGE__->run_before('check_auth_for_edit',
  except => [ qw(
    update_stock_information edit show_customer_vendor_details_dialog
    price_popup stock_in_out_dialog load_second_rows
    ) ]);

__PACKAGE__->run_before('get_unalterable_data',
  only => [ qw(
    save save_as_new save_and_new_record save_and_invoice
    save_and_ap_transaction print send_email
    ) ]);

#
# actions
#

# add a new order
sub action_add {
  my ($self) = @_;

  $self->order(SL::Model::Record->update_after_new($self->order));

  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(
      scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE()
    )->token;
  }

  $self->render(
    'delivery_order/form',
    title => $self->get_title_for('add'),
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
  my $delivery_order = SL::Model::Record->new_from_workflow($record, $self->type, %flags);
  $self->order($delivery_order);

  if (ref($record) eq 'SL::DB::Reclamation') {
    $self->{converted_from_reclamation_id}       = $delivery_order->{ RECORD_ID()      };
    $_   ->{converted_from_reclamation_items_id} = $_             ->{ RECORD_ITEM_ID() } for @{ $delivery_order->items_sorted };
  }
  if (ref($record) eq 'SL::DB::Order') {
    $self->{converted_from_oe_id}       = $delivery_order->{ RECORD_ID()      };
    $_   ->{converted_from_oe_items_id} = $_             ->{ RECORD_ITEM_ID() } for @{ $delivery_order->items_sorted };
  }

  $self->action_add;
}

# edit an existing order
sub action_edit {
  my ($self) = @_;

  if ($::form->{id}) {
    $self->load_order;

  } else {
    # this is to edit an order from an unsaved order object

    # set item ids to new fake id, to identify them as new items
    foreach my $item (@{$self->order->items_sorted}) {
      $item->{new_fake_id} =
        join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
    }
    # trigger rendering values for second row as hidden, because they
    # are loaded only on demand. So we need to keep the values from
    # the source.
    $_->{render_second_row} = 1 for @{ $self->order->items_sorted };

    if (!$::form->{form_validity_token}) {
      $::form->{form_validity_token} = SL::DB::ValidityToken->create(
        scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE()
      )->token;
    }
  }

  $self->pre_render();
  $self->render(
    'delivery_order/form',
    title => $self->get_title_for('edit'),
    %{$self->{template_args}}
  );
}

# delete the order
sub action_delete {
  my ($self) = @_;

  SL::Model::Record->delete($self->order);
  flash_later('info', $self->type_data->text("delete"));

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

  flash_later('info', $self->type_data->text("saved"));

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

  my $saved_order = SL::DB::DeliveryOrder->new(id => $order->id)->load;

  # Create new record from current one
  my $new_order = SL::Model::Record->clone_for_save_as_new($saved_order, $order);
  $self->order($new_order);

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(
      scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE()
    )->token;
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

  if ( !$self->order->delivered ) {
    $self->save();
    $self->js_reset_order_and_item_ids_after_save;
  }

  my $format      = $::form->{print_options}->{format};
  my $media       = $::form->{print_options}->{media};
  my $formname    = $::form->{print_options}->{formname};
  my $copies      = $::form->{print_options}->{copies};
  my $groupitems  = $::form->{print_options}->{groupitems};
  my $printer_id  = $::form->{print_options}->{printer_id};

  # only pdf and opendocument by now
  if (none { $format eq $_ } qw(pdf opendocument opendocument_pdf)) {
    return $self->js->flash('error',
      t8('Format \'#1\' is not supported yet/anymore.', $format)
    )->render;
  }

  # only screen or printer by now
  if (none { $media eq $_ } qw(screen printer)) {
    return $self->js->flash('error',
      t8('Media \'#1\' is not supported yet/anymore.', $media)
    )->render;
  }

  # create a form for generate_attachment_filename
  my $form   = Form->new;
  $form->{$self->nr_key()}  = $self->order->number;
  $form->{type}             = $self->type;
  $form->{format}           = $format;
  $form->{formname}         = $formname;
  $form->{language}         =
    '_' . $self->order->language->template_code if $self->order->language;
  my $pdf_filename          = $form->generate_attachment_filename();
  $main::lxdebug->dump(0, 'WH: FoRM ', $form);
  $main::lxdebug->dump(0, 'WH: PDF ', $pdf_filename);
  my $pdf;
  my @errors = generate_pdf($self->order, \$pdf, {
      format     => $format,
      formname   => $formname,
      language   => $self->order->language,
      printer_id => $printer_id,
      groupitems => $groupitems
    });
  if (scalar @errors) {
    return $self->js->flash('error',
      t8('Conversion to PDF failed: #1', $errors[0])
    )->render;
  }

  if ($media eq 'screen') {
    # screen/download
    $self->js->flash('info', t8('The PDF has been created'));
    $self->send_file(
      \$pdf,
      type         => SL::MIME->mime_type_from_ext($pdf_filename),
      name         => $pdf_filename,
      js_no_render => 1,
    );

  } elsif ($media eq 'printer') {
    # printer
    my $printer_id = $::form->{print_options}->{printer_id};
    SL::DB::Printer->new(id => $printer_id)->load->print_document(
      copies  => $copies,
      content => $pdf,
    );

    $self->js->flash('info', t8('The PDF has been printed'));
  }

  my @warnings = store_pdf_to_webdav_and_filemanagement(
    $self->order, $pdf, $pdf_filename
  );
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

  if ( !$self->order->delivered ) {
    $self->save();
    $self->js_reset_order_and_item_ids_after_save;
  }

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
  $form->{language}         =
    '_' . $self->order->language->template_code if $self->order->language;
  my $pdf_filename          = $form->generate_attachment_filename();

  my $pdf;
  my @errors = generate_pdf($self->order, \$pdf, {
      format     => $format,
      formname   => $formname,
      language   => $self->order->language,
    });
  if (scalar @errors) {
    return $self->js->flash('error',
      t8('Conversion to PDF failed: #1', $errors[0])
    )->render;
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

  if ( !$self->order->delivered ) {
    $self->save();
  }

  my $cv_method = $self->cv;

  if (!$self->order->$cv_method) {
    return $self->js->flash('error',
      $self->cv eq 'customer' ?
           t8('Cannot send E-mail without customer given')
         : t8('Cannot send E-mail without vendor given')
    )->render($self);
  }

  my $email_form;
  $email_form->{to}   = $self->order->contact->cp_email if $self->order->contact;
  $email_form->{to} ||= $self->order->$cv_method->email;
  $email_form->{cc}   = $self->order->$cv_method->cc;
  $email_form->{bcc}  = join ', ', grep $_, $self->order->$cv_method->bcc;
  # Todo: get addresses from shipto, if any

  my $form = Form->new;
  $form->{$self->nr_key()}  = $self->order->number;
  $form->{cusordnumber}     = $self->order->cusordnumber;
  $form->{formname}         = $self->type;
  $form->{type}             = $self->type;
  $form->{language}         =
    '_' . $self->order->language->template_code if $self->order->language;
  $form->{language_id}      =
    $self->order->language->id                  if $self->order->language;
  $form->{format}           = 'pdf';
  $form->{cp_id}            =
    $self->order->contact->cp_id if $self->order->contact;

  $email_form->{subject}             = $form->generate_email_subject();
  $email_form->{attachment_filename} = $form->generate_attachment_filename();
  $email_form->{message}             = $form->generate_email_body();
  $email_form->{js_send_function}    = 'kivi.DeliveryOrder.send_email()';

  my %files = $self->get_files_for_email_dialog();
  $self->{all_employees} = SL::DB::Manager::Employee->get_all(
    query => [ deleted => 0 ]
  );
  my $dialog_html = $self->render(
    'common/_send_email_dialog', { output => 0 },
    email_form  => $email_form,
    show_bcc    => $::auth->assert('email_bcc', 'may fail'),
    FILES       => \%files,
    is_customer => $self->type_data->properties("is_customer"),
    ALL_EMPLOYEES => $self->{all_employees},
  );

  $self->js
      ->run('kivi.DeliveryOrder.show_email_dialog', $dialog_html)
      ->reinit_widgets
      ->render($self);
}

# send email
#
# Todo: handling error messages: flash is not displayed in dialog, but in the main form
sub action_send_email {
  my ($self) = @_;

  if ( !$self->order->delivered ) {
    $self->save();
    $self->js_reset_order_and_item_ids_after_save;
  }

  my $email_form  = delete $::form->{email_form};
  my %field_names = (to => 'email');

  $::form->{ $field_names{$_} // $_ } = $email_form->{$_} for keys %{ $email_form };

  # for Form::cleanup which may be called in Form::send_email
  $::form->{cwd}    = getcwd();
  $::form->{tmpdir} = $::lx_office_conf{paths}->{userspath};

  $::form->{$_}     = $::form->{print_options}->{$_} for keys %{ $::form->{print_options} };
  $::form->{media}  = 'email';

  if (($::form->{attachment_policy} // '') !~ m{^(?:old_file|no_file)$}) {
    my $pdf;
    my @errors = generate_pdf($self->order, \$pdf, {
        media      => $::form->{media},
        format     => $::form->{print_options}->{format},
        formname   => $::form->{print_options}->{formname},
        language   => $self->order->language,
        printer_id => $::form->{print_options}->{printer_id},
        groupitems => $::form->{print_options}->{groupitems}},
    );
    if (scalar @errors) {
      return $self->js->flash('error',
        t8('Conversion to PDF failed: #1', $errors[0])
      )->render($self);
    }

    my @warnings = store_pdf_to_webdav_and_filemanagement(
      $self->order, $pdf, $::form->{attachment_filename}
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

  $::form->{id} = $self->order->id; # this is used in SL::Mailer to create a
                                    # linked record to the mail
  $::form->send_email(\%::myconfig, 'pdf');

  # internal notes unless no email journal
  unless ($::instance_conf->get_email_journal) {

    my $intnotes = $self->order->intnotes;
    $intnotes   .= "\n\n" if $self->order->intnotes;
    $intnotes   .= t8('[email]')                                . "\n";
    $intnotes   .= t8('Date')       . ": " .
      $::locale->format_date_object(
        DateTime->now_local, precision => 'seconds'
      ) . "\n";
    $intnotes   .= t8('To (email)') . ": " . $::form->{email}   . "\n";
    $intnotes   .= t8('Cc')         . ": " . $::form->{cc}      . "\n"    if $::form->{cc};
    $intnotes   .= t8('Bcc')        . ": " . $::form->{bcc}     . "\n"    if $::form->{bcc};
    $intnotes   .= t8('Subject')    . ": " . $::form->{subject} . "\n\n";
    $intnotes   .= t8('Message')    . ": " . $::form->{message};

    $self->order->update_attributes(intnotes => $intnotes);
  }

  $self->save_history('MAILED');

  flash_later('info', t8('The email has been sent.'));

  my @redirect_params = (
    action => 'edit',
    type   => $self->type,
    id     => $self->order->id,
  );

  $self->redirect_to(@redirect_params);
}

sub action_save_and_new_record {
  my ($self) = @_;
  my $to_type = $::form->{to_type};
  my $to_controller = get_object_name_from_type($to_type);

  $self->save();

  my %additional_params = ();
  if ($::form->{only_selected_item_positions}) { # ids can be unset before save
    my $item_positions = $::form->{selected_item_positions} || [];
    my @from_item_ids = map { $self->order->items_sorted->[$_]->id } @$item_positions;
    $additional_params{from_item_ids} = \@from_item_ids;
  }

  flash_later('info', $self->type_data->text('saved'));

  $self->redirect_to(
    controller => $to_controller,
    action     => 'add_from_record',
    type       => $to_type,
    from_id    => $self->order->id,
    from_type  => $self->order->type,
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
  );
}

# workflow from purchase order to ap transaction
sub action_save_and_ap_transaction {
  my ($self) = @_;

  $self->save_and_redirect_to(
    controller => 'ap.pl',
    action     => 'add_from_purchase_order',
  );
}

# set form elements in respect to a changed customer or vendor
#
# This action is called on an change of the customer/vendor picker.
sub action_customer_vendor_changed {
  my ($self) = @_;

  $self->order(
    SL::Model::Record->update_after_customer_vendor_change($self->order)
  );

  my $cv_method = $self->cv;

  if ( $self->order->$cv_method->contacts
    && scalar @{ $self->order->$cv_method->contacts } > 0) {
    $self->js->show('#cp_row');
  } else {
    $self->js->hide('#cp_row');
  }

  if ($self->order->$cv_method->shipto && scalar @{ $self->order->$cv_method->shipto } > 0) {
    $self->js->show('#shipto_selection');
  } else {
    $self->js->hide('#shipto_selection');
  }

  $self->js->val( '#order_salesman_id',      $self->order->salesman_id)        if $self->order->is_sales;

  $self->js
    ->replaceWith('#order_cp_id',            $self->build_contact_select)
    ->replaceWith('#order_shipto_id',        $self->build_shipto_select)
    ->replaceWith('#shipto_inputs  ',        $self->build_shipto_inputs)
    ->replaceWith('#business_info_row',      $self->build_business_info_row)
    ->val(        '#order_taxzone_id',       $self->order->taxzone_id)
    ->val(        '#order_taxincluded',      $self->order->taxincluded)
    ->val(        '#order_currency_id',      $self->order->currency_id)
    ->val(        '#order_payment_id',       $self->order->payment_id)
    ->val(        '#order_delivery_term_id', $self->order->delivery_term_id)
    ->val(        '#order_intnotes',         $self->order->intnotes)
    ->val(        '#order_language_id',      $self->order->$cv_method->language_id)
    ->focus(      '#order_' . $self->cv . '_id')
    ->run('kivi.DeliveryOrder.update_exchangerate');

  $self->js_redisplay_cvpartnumbers;
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

  $self->js->run(
    'kivi.DeliveryOrder.update_sellprice',
    $::form->{item_id},
    $item->sellprice_as_number
  );
  $self->js_redisplay_line_values;
  $self->js->render();
}

# add an item row for a new item entered in the input row
sub action_add_item {
  my ($self) = @_;

  delete $::form->{add_item}->{create_part_type};

  my $form_attr = $::form->{add_item};

  return unless $form_attr->{parts_id};

  my $item = new_item($self->order, $form_attr);

  $self->order->add_items($item);

  $self->get_item_cvpartnumber($item);

  my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $row_as_html = $self->p->render('delivery_order/tabs/_row',
                                     ITEM => $item,
                                     ID   => $item_id,
                                     SELF => $self,
                                     in_out => $self->type_data->properties("transfer"),
  );

  if ($::form->{insert_before_item_id}) {
    $self->js
      ->before(
        '.row_entry:has(#item_' . $::form->{insert_before_item_id} . ')',
        $row_as_html
      );
  } else {
    $self->js
      ->append('#row_table_id', $row_as_html);
  }

  if ( $item->part->is_assortment ) {
    $form_attr->{qty_as_number} = 1 unless $form_attr->{qty_as_number};
    foreach my $assortment_item ( @{$item->part->assortment_items} ) {
      my $attr = {
        parts_id => $assortment_item->parts_id,
        qty      => $assortment_item->qty *
          $::form->parse_amount(\%::myconfig, $form_attr->{qty_as_number}), # TODO $form_attr->{unit}
        unit     => $assortment_item->unit,
        description => $assortment_item->part->description,
      };
      my $item = new_item($self->order, $attr);

      # set discount to 100% if item isn't supposed to be charged, overwriting
      # any customer discount
      $item->discount(1) unless $assortment_item->charge;

      $self->order->add_items( $item );
      $self->get_item_cvpartnumber($item);
      my $item_id = join('_',
        'new',
        Time::HiRes::gettimeofday(),
        int rand 1000000000000
      );
      my $row_as_html = $self->p->render('delivery_order/tabs/_row',
                                         ITEM => $item,
                                         ID   => $item_id,
                                         SELF => $self,
      );
      if ($::form->{insert_before_item_id}) {
        $self->js
          ->before(
            '.row_entry:has(#item_' . $::form->{insert_before_item_id} . ')',
            $row_as_html
          );
      } else {
        $self->js
          ->append('#row_table_id', $row_as_html);
      }
    };
  };

  $self->js
    ->val('.add_item_input', '')
    ->run('kivi.DeliveryOrder.init_row_handlers')
    ->run('kivi.DeliveryOrder.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.DeliveryOrder.row_table_scroll_down') if !$::form->{insert_before_item_id};

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
        my $attr = {
          parts_id => $assortment_item->parts_id,
          qty      => $assortment_item->qty * $item->qty, # TODO $form_attr->{unit}
          unit     => $assortment_item->unit,
          description => $assortment_item->part->description,
        };
        my $item = new_item($self->order, $attr);

        # set discount to 100% if item isn't supposed to be charged, overwriting
        # any customer discount
        $item->discount(1) unless $assortment_item->charge;
        push @items, $item;
      }
    }
  }
  $self->order->add_items(@items);

  foreach my $item (@items) {
    $self->get_item_cvpartnumber($item);
    my $item_id = join('_',
      'new',
      Time::HiRes::gettimeofday(),
      int rand 1000000000000
    );
    my $row_as_html = $self->p->render('delivery_order/tabs/_row',
      ITEM => $item,
      ID   => $item_id,
      SELF => $self,
      in_out => $self->type_data->properties("transfer"),
    );

    if ($::form->{insert_before_item_id}) {
      $self->js
        ->before(
          '.row_entry:has(#item_' . $::form->{insert_before_item_id} . ')',
          $row_as_html
        );
    } else {
      $self->js
        ->append('#row_table_id', $row_as_html);
    }
  }

  $self->js
    ->run('kivi.Part.close_picker_dialogs')
    ->run('kivi.DeliveryOrder.init_row_handlers')
    ->run('kivi.DeliveryOrder.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.DeliveryOrder.row_table_scroll_down') if !$::form->{insert_before_item_id};

  $self->js->render();
}

sub action_update_exchangerate {
  my ($self) = @_;

  my $data = {
    is_standard   => $self->order->currency_id == $::instance_conf->get_currency_id,
    currency_name => $self->order->currency->name,
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
  my @to_sort =
    map { { old_pos => $_->position, order_by => $method->($_) } }
    @{ $self->order->items_sorted };
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
    ->run('kivi.DeliveryOrder.redisplay_items', \@to_sort)
    ->render;
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

  flash_later('info',
    t8('You are adding a new part while you are editing another document. You will be redirected to your document when saving the new part or aborting this form.')
  );

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

  $self->{created_part} =
    SL::DB::Part->new(id => delete $::form->{new_parts_id})->load
    if $::form->{new_parts_id};

  $::auth->restore_form_from_session(delete $::form->{previousform});

  # set item ids to new fake id, to identify them as new items
  foreach my $item (@{$self->order->items_sorted}) {
    $item->{new_fake_id} = join('_',
      'new',
      Time::HiRes::gettimeofday(),
      int rand 1000000000000
    );
  }

  $self->get_unalterable_data();
  $self->pre_render();

  # trigger rendering values for second row/longdescription as hidden,
  # because they are loaded only on demand. So we need to keep the values
  # from the source.
  $_->{render_second_row}      = 1 for @{ $self->order->items_sorted };
  $_->{render_longdescription} = 1 for @{ $self->order->items_sorted };

  $self->render(
    'delivery_order/form',
    title => $self->get_title_for('edit'),
    %{$self->{template_args}}
  );
}

sub action_stock_in_out_dialog {
  my ($self) = @_;

  my $part    = SL::DB::Part->load_cached($::form->{parts_id}) or die "need parts_id";
  my $unit    = SL::DB::Unit->load_cached($::form->{unit}) or die "need unit";
  my $stock   = $::form->{stock};
  my $row     = $::form->{row};
  my $item_id = $::form->{item_id};
  my $qty     = _parse_number($::form->{qty_as_number});

  my $inout = $self->type_data->properties("transfer");

  my @contents   = DO->get_item_availability(parts_id => $part->id);
  my $stock_info = DO->unpack_stock_information(packed => $stock);

  $self->merge_stock_data($stock_info, \@contents, $part, $unit);

  $self->render("delivery_order/stock_dialog", { layout => 0 },
    WHCONTENTS => \@contents,
    STOCK_INFO => $stock_info,
    WAREHOUSES => SL::DB::Manager::Warehouse->get_all(with_objects=> ["bins",]),
    part       => $part,
    do_qty     => $qty,
    do_unit    => $unit->unit,
    delivered  => $self->order->delivered,
    row        => $row,
    item_id    => $item_id,
    in_out     => $inout,
  );
}

sub action_add_stock_in_line_to_dialog {
  my ($self) = @_;

  my $do_qty       = _parse_number($::form->{do_qty});
  my $qty_sum   = $::form->{qty_sum};
  my $row_count = $::form->{row_count};
  my $part      = SL::DB::Part->load_cached($::form->{parts_id}) or die "need parts_id";

  my $row_as_html = $self->p->render('delivery_order/stock_dialog/_stock_in_new_row',
    WAREHOUSES => SL::DB::Manager::Warehouse->get_all(with_objects=> ["bins",]),
    PART => $part,
    pos  => $row_count + 1,
    remaining_qty => $do_qty - $qty_sum,
  );

  $self->js->append('#stock-in-out-table', $row_as_html)->render();
}

sub action_update_stock_information {
  my ($self) = @_;

  my $stock_info = $::form->{stock_info};
  my $unit = $::form->{unit};
  my $yaml = SL::YAML::Dump($stock_info);
  my $stock_qty = $self->calculate_stock_in_out_from_stock_info($unit, $stock_info);

  my $response = {
    stock_info => $yaml,
    stock_qty => $stock_qty,
  };
  $self->render(
    \ SL::JSON::to_json($response),
    { layout => 0, type => 'json', process => 0 }
  );
}

sub merge_stock_data {
  my ($self, $stock_info, $contents, $part, $unit) = @_;
  # TODO rewrite to mapping

  if (!$self->order->delivered) {
    for my $row (@$contents) {
      # row here is in parts units. stock is in item units
      $row->{available_qty} = _format_number(
        $part->unit_obj->convert_to($row->{qty}, $unit)
      );

      for my $sinfo (@{ $stock_info }) {
        next if $row->{bin_id}       != $sinfo->{bin_id} ||
                $row->{warehouse_id} != $sinfo->{warehouse_id} ||
                $row->{chargenumber} ne $sinfo->{chargenumber} ||
                $row->{bestbefore}   ne $sinfo->{bestbefore};

        $row->{"stock_$_"} = $sinfo->{$_}
          for qw(qty unit error delivery_order_items_stock_id);
      }
    }

  } else {
    for my $sinfo (@{ $stock_info }) {
      my $bin = SL::DB::Bin->load_cached($sinfo->{bin_id});
      $sinfo->{warehousedescription} = $bin->warehouse->description;
      $sinfo->{bindescription}       = $bin->description;
      map { $sinfo->{"stock_$_"}      = $sinfo->{$_} } qw(qty unit);
    }
  }
}

# load the second row for one or more items
#
# This action gets the html code for all items second rows by rendering a template for
# the second row and sets the html code via client js.
sub action_load_second_rows {
  my ($self) = @_;

  foreach my $item_id (@{ $::form->{item_ids} }) {
    my $idx  = first_index { $_ eq $item_id } @{ $::form->{orderitem_ids} };
    my $item = $self->order->items_sorted->[$idx];

    $self->js_load_second_row($item, $item_id, 0);
  }

  # for lastcosts change-callback
  $self->js->run('kivi.DeliveryOrder.init_row_handlers') if $self->order->is_sales;

  $self->js->render();
}

# update description, notes and sellprice from master data
sub action_update_row_from_master_data {
  my ($self) = @_;

  foreach my $item_id (@{ $::form->{item_ids} }) {
    my $idx   = first_index { $_ eq $item_id } @{ $::form->{orderitem_ids} };
    my $item  = $self->order->items_sorted->[$idx];
    my $texts = get_part_texts($item->part, $self->order->language_id);

    $item->description($texts->{description});
    $item->longdescription($texts->{longdescription});

    my $price_source = SL::PriceSource->new(record_item => $item, record => $self->order);

    my $price_src;
    if ($item->part->is_assortment) {
    # add assortment items with price 0, as the components carry the price
      $price_src = $price_source->price_from_source("");
      $price_src->price(0);
    } else {
      $price_src = $price_source->best_price
                 ? $price_source->best_price
                 : $price_source->price_from_source("");
      $price_src->price(
        $::form->round_amount($price_src->price / $self->order->exchangerate, 5)
      ) if $self->order->exchangerate;
      $price_src->price(0) if !$price_source->best_price;
    }

    $item->sellprice($price_src->price);
    $item->active_price_source($price_src);

    $self->js
      ->run('kivi.DeliveryOrder.update_sellprice', $item_id, $item->sellprice_as_number)
      ->html('.row_entry:has(#item_' . $item_id . ') [name = "partnumber"] a', $item->part->partnumber)
      ->val ('.row_entry:has(#item_' . $item_id . ') [name = "order.orderitems[].description"]', $item->description)
      ->val ('.row_entry:has(#item_' . $item_id . ') [name = "order.orderitems[].longdescription"]', $item->longdescription);

    if ($self->search_cvpartnumber) {
      $self->get_item_cvpartnumber($item);
      $self->js->html('.row_entry:has(#item_' . $item_id . ') [name = "cvpartnumber"]', $item->{cvpartnumber});
    }
  }

  $self->js_redisplay_line_values;

  $self->js->render();
}

sub action_transfer_stock {
  my ($self) = @_;

  if ($self->order->delivered) {
    return $self->js->flash("error",
      t8('The parts for this order have already been transferred')
    )->render;
  }

  my $inout = $self->type_data->properties('transfer');

  $self->save;

  my $order = $self->order;

  # TODO move to type data
  my $trans_type = $inout eq 'in'
    ? SL::DB::Manager::TransferType->find_by(
        direction => "in", description => "stock")
    : SL::DB::Manager::TransferType->find_by(
        direction => "out", description => "shipped");


  my @transfer_requests;

  for my $item (@{ $order->items_sorted }) {
    for my $stock (@{ $item->delivery_order_stock_entries }) {
      my $transfer = SL::DB::Inventory->new_from($stock);
      $transfer->trans_type($trans_type);
      $transfer->oe_id($order->id);
      $transfer->qty($transfer->qty * -1) if $inout eq 'out';
      $transfer->qty($transfer->qty * 1) if $inout eq 'in';

      push @transfer_requests, $transfer if defined $transfer->qty && $transfer->qty != 0;
    };
  }

  if (!@transfer_requests) {
    return $self->js->flash("error", t8("No stock to transfer"))->render;
  }

  SL::DB->client->with_transaction(sub {
    $_->save for @transfer_requests;
    $self->order->update_attributes(delivered => 1, closed => 1);
  });

  $self->js
    ->flash("info", t8("Stock transfered"))
    ->run('kivi.ActionBar.setDisabled', '#transfer_out_action',
          t8('The parts for this order have already been transferred'))
    ->run('kivi.ActionBar.setDisabled', '#transfer_in_action',
          t8('The parts for this order have already been transferred'))
    ->run('kivi.ActionBar.setDisabled', '#delete_action',
          t8('The parts for this order have already been transferred'))
    ->run('kivi.ActionBar.setEnabled', '#undo_transfer_action',
          t8('The parts for this order have already been transferred'))
    ->replaceWith('#data-status-line', delivery_order_status_line($self->order))
    ->render;
}

sub action_undo_transfers {
  my ( $self ) = @_;

  SL::DB->client->with_transaction(sub {
    foreach my $item (@{$self->order->orderitems}) {
      foreach my $inv_item (@{ $item->delivery_order_stock_entries}) {
        $inv_item->inventory->delete;
        $inv_item->delete;
      }
    }
    $self->order->update_attributes(delivered => 0);
    $self->order->update_attributes(closed => 0);
  });

  flash_later('info', t8("Transfer undone"));
  my @redirect_params = (
    action => 'edit',
    type   => $self->type,
    id     => $self->order->id,
  );

  $self->redirect_to(@redirect_params);
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

  my $row_as_html = $self->p->render('delivery_order/tabs/_second_row', ITEM => $item, TYPE => $self->type);

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
    ->run('kivi.DeliveryOrder.redisplay_line_values', $is_sales, \@data);
}

sub js_redisplay_cvpartnumbers {
  my ($self) = @_;

  $self->get_item_cvpartnumber($_) for @{$self->order->items_sorted};

  my @data = map {[$_->{cvpartnumber}]} @{ $self->order->items_sorted };

  $self->js
    ->run('kivi.DeliveryOrder.redisplay_cvpartnumbers', \@data);
}

sub js_reset_order_and_item_ids_after_save {
  my ($self) = @_;

  $self->js
    ->val('#id', $self->order->id)
    ->val('#converted_from_oe_id', '')
    ->val('#converted_from_reclamation_id', '')
    ->val('#order_' . $self->nr_key(), $self->order->number);

  my $idx = 0;
  foreach my $form_item_id (@{ $::form->{orderitem_ids} }) {
    next if !$self->order->items_sorted->[$idx]->id;
    next if $form_item_id !~ m{^new};
    $self->js
      ->val (
        '[name="orderitem_ids[+]"][value="' . $form_item_id . '"]',
        $self->order->items_sorted->[$idx]->id)
      ->val ('#item_' . $form_item_id, $self->order->items_sorted->[$idx]->id)
      ->attr('#item_' . $form_item_id, "id",
        'item_' . $self->order->items_sorted->[$idx]->id);
  } continue {
    $idx++;
  }
  $self->js->val('[name="converted_from_orderitems_ids[+]"]', '');
  $self->js->val('[name="converted_from_reclamation_items_ids[+]"]', '');
}

#
# helpers
#

sub init_type {
  my ($self) = @_;

  if (none { $::form->{type} eq $_ } @{$self->valid_types}) {
    die "Not a valid type for delivery order";
  }

  $self->type($::form->{type});
}

sub init_cv {
  my ($self) = @_;

  return $self->type_data->properties("customervendor");
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

sub init_part_picker_classification_ids {
  my ($self)    = @_;

  return [ map { $_->id } @{ SL::DB::Manager::PartClassification->get_all(
    where => $self->type_data->part_classification_query
    ) } ];
}

sub check_auth {
  my ($self) = @_;

  $::auth->assert($self->type_data->rights('view') || 'DOES_NOT_EXIST');
}

sub check_auth_for_edit {
  my ($self) = @_;

  $::auth->assert($self->type_data->rights('edit') || 'DOES_NOT_EXIST');
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

  select_tag('order.shipto_id',
             [ {
                 displayable_id => t8("No/individual shipping address"),
                 shipto_id => ''
               },
               $self->order->{$self->cv}->shipto ],
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
  $_[0]->p->render('delivery_order/tabs/_business_info_row', SELF => $_[0]);
}


sub load_order {
  my ($self) = @_;

  return if !$::form->{id};

  $self->order(SL::DB::DeliveryOrder->new(id => $::form->{id})->load);

  # Add an empty custom shipto to the order, so that the dialog can render the cvar inputs.
  # You need a custom shipto object to call cvars_by_config to get the cvars.
  $self->order->custom_shipto(SL::DB::Shipto->new(module => 'OE', custom_variables => [])) if !$self->order->custom_shipto;

  $self->order->prepare_stock_info($_) for $self->order->items;

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
    $order = SL::DB::DeliveryOrder->new(
      id => $::form->{id}
    )->load(with => [ 'orderitems', 'orderitems.part' ]);
  } else {
    $order = SL::DB::DeliveryOrder->new(
      orderitems  => [],
      currency_id => $::instance_conf->get_currency_id(),
      record_type => $self->type
    );
  }

  my $cv_id_method = $self->cv . '_id';
  if (!$::form->{id} && $::form->{$cv_id_method}) {
    $order->$cv_id_method($::form->{$cv_id_method});
    $order = SL::Model::Record->update_after_customer_vendor_change($order);
  }

  my $form_orderitems = delete $::form->{order}->{orderitems};

  $order->assign_attributes(%{$::form->{order}});

  $self->setup_custom_shipto_from_form($order, $::form);

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
  $item ||= SL::DB::DeliveryOrderItem->new(custom_variables => []);

  # handle stock info
  if (my $stock_info = delete $attr->{stock_info}) {
    my %existing = map { $_->id => $_ } $item->delivery_order_stock_entries;
    my @save;

    for my $line (@{ DO->unpack_stock_information(packed => $stock_info) }) {
      # lookup existing or make new
      my $obj = delete $existing{$line->{delivery_order_items_stock_id}}
             // SL::DB::DeliveryOrderItemsStock->new;

      # assign attributes
      $obj->$_($line->{$_}) for qw(bin_id warehouse_id chargenumber qty unit);
      $obj->bestbefore_as_date($line->{bestfbefore})
        if $line->{bestbefore} && $::instance_conf->get_show_bestbefore;
      push @save, $obj if $obj->qty;
    }

    $item->delivery_order_stock_entries(@save);
  }

  $item->assign_attributes(%$attr);

  if ($is_new) {
    my $texts = get_part_texts($item->part, $record->language_id);
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

  my $item = SL::DB::DeliveryOrderItem->new;

  # Remove attributes where the user left or set the inputs empty.
  # So these attributes will be undefined and we can distinguish them
  # from zero later on.
  for (qw(qty_as_number sellprice_as_number discount_as_percent)) {
    delete $attr->{$_} if $attr->{$_} eq '';
  }

  $item->assign_attributes(%$attr);

  my $part         = SL::DB::Part->new(id => $attr->{parts_id})->load;
  my $price_source = SL::PriceSource->new(
    record_item => $item,
    record => $record,
  );

  $item->unit($part->unit) if !$item->unit;

  my $price_src;
  if ( $part->is_assortment ) {
    # add assortment items with price 0, as the components carry the price
    $price_src = $price_source->price_from_source("");
    $price_src->price(0);
  } elsif (defined $item->sellprice) {
    $price_src = $price_source->price_from_source("");
    $price_src->price($item->sellprice);
  } else {
    $price_src = $price_source->best_price
               ? $price_source->best_price
               : $price_source->price_from_source("");
    $price_src->price(0) if !$price_source->best_price;
  }

  my $discount_src;
  if (defined $item->discount) {
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

  my $texts = get_part_texts(
    $part, $record->language_id,
    description => $new_attr{description},
    longdescription => $new_attr{longdescription}
  );

  $item->assign_attributes(%new_attr, %{ $texts });

  return $item;
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
    my $custom_shipto = $order->custom_shipto ?
        $order->custom_shipto
      : $order->custom_shipto(
          SL::DB::Shipto->new(module => 'OE', custom_variables => [])
        );

    my $shipto_cvars  = {
      map { my ($key) = m{^shiptocvar_(.+)}; $key => delete $form->{$_}}
      grep { m{^shiptocvar_} }
      keys %$form
    };
    my $shipto_attrs  = {
      map { $_ => delete $form->{$_}}
      grep { m{^shipto} }
      keys %$form
    };

    $custom_shipto->assign_attributes(%$shipto_attrs);
    $custom_shipto->cvar_by_name($_)->value($shipto_cvars->{$_}) for keys %$shipto_cvars;
  }
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

# save the order
#
# And delete items that are deleted in the form.
sub save {
  my ($self) = @_;

  # link records
  if ($::form->{converted_from_oe_id}) {
    my @converted_from_oe_ids = split ' ', $::form->{converted_from_oe_id};
    set_record_link_conversions(
      $self->order,
      'SL::DB::Order'     => \@converted_from_oe_ids,
      'SL::DB::OrderItem' => $::form->{converted_from_orderitems_ids},
    );
  }
  if ($::form->{converted_from_reclamation_id}) {
    my @converted_from_reclamation_ids =
      split ' ', $::form->{converted_from_reclamation_id};
    set_record_link_conversions(
      $self->order,
      'SL::DB::Reclamation'     => \@converted_from_reclamation_ids,
      'SL::DB::ReclamationItem' => $::form->{converted_from_reclamation_items_ids},
    );
  }

  my $items_to_delete  = scalar @{ $self->item_ids_to_delete || [] }
                       ? SL::DB::Manager::DeliveryOrderItem->get_all(where => [id => $self->item_ids_to_delete])
                       : undef;

  SL::Model::Record->save($self->order,
    with_validity_token        => {
      scope => SL::DB::ValidityToken::SCOPE_DELIVERY_ORDER_SAVE(),
      token => $::form->{form_validity_token}
    },
    delete_custom_shipto       => $self->is_custom_shipto_to_delete || $self->order->custom_shipto->is_empty,
    items_to_delete            => $items_to_delete,
  );

  delete $::form->{form_validity_token};
}

sub workflow_sales_or_request_for_quotation {
  my ($self, $destination_type) = @_;

  # always save
  $self->save();

  my $delivery_order = SL::Model::Record->new_from_workflow(
    $self->order, $destination_type
  );
  $self->order($delivery_order);
  $self->{converted_from_oe_id} = delete $::form->{id};

  # set item ids to new fake id, to identify them as new items
  foreach my $item (@{$self->order->items_sorted}) {
    $item->{new_fake_id} = join('_',
      'new',
      Time::HiRes::gettimeofday(),
      int rand 1000000000000
    );
  }

  # change form type
  $::form->{type} = $destination_type;
  $self->type($self->init_type);
  $self->cv  ($self->init_cv);
  $self->check_auth;

  $self->get_unalterable_data();
  $self->pre_render();

  # trigger rendering values for second row as hidden, because they
  # are loaded only on demand. So we need to keep the values from the
  # source.
  $_->{render_second_row} = 1 for @{ $self->order->items_sorted };

  $self->render(
    'delivery_order/form',
    title => $self->get_title_for('edit'),
    %{$self->{template_args}}
  );
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
  $self->{all_delivery_terms}         = SL::DB::Manager::DeliveryTerm->get_all_sorted();
  $self->{current_employee_id}        = SL::DB::Manager::Employee->current->id;
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
                no_html            => 1},
  );

  foreach my $item (@{$self->order->orderitems}) {
    my $price_source = SL::PriceSource->new(record_item => $item, record => $self->order);
    $item->active_price_source(   $price_source->price_from_source(   $item->active_price_source   ));
    $item->active_discount_source($price_source->discount_from_source($item->active_discount_source));
  }

  if ($self->order->${\ $self->type_data->properties("nr_key") } && $::instance_conf->get_webdav) {
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

  $self->{template_args}{in_out}                                 = $self->type_data->properties("transfer");
  $self->{template_args}{longdescription_dialog_size_percentage} = SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();

  $self->get_item_cvpartnumber($_) for @{$self->order->items_sorted};

  $::request->{layout}->use_javascript("${_}.js") for qw(
    kivi.SalesPurchase kivi.DeliveryOrder kivi.File calculate_qty kivi.Validator
    follow_up show_history
    );
  $self->setup_edit_action_bar;
}

sub setup_edit_action_bar {
  my ($self, %params) = @_;

  my $deletion_allowed = $self->type_data->show_menu("delete");
  my $may_edit_create  = $::auth->assert(
    $self->type_data->rights('edit') || 'DOES_NOT_EXIST', 1
  );

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          id       => 'save_action',
          call     => [ 'kivi.DeliveryOrder.save', {
              action             => 'save',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
            }],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : $self->order->delivered ? t8('This record has already been delivered.')
                    :                        undef,
        ],
        action => [
          t8('Save as new'),
          call     => [ 'kivi.DeliveryOrder.save', {
              action             => 'save_as_new',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
            }],
          disabled => !$may_edit_create                        ? t8('You do not have the permissions to access this function.')
                    : $self->type eq 'supplier_delivery_order' ? t8('Need a workflow for Supplier Delivery Order')
                    : $self->type eq 'rma_delivery_order'      ? t8('Need a workflow for RMA Delivery Order.')
                    : !$self->order->id                        ? t8('This object has not been saved yet.')
                    :                                            undef,
        ],
      ], # end of combobox "Save"

      combobox => [
        action => [
          t8('Workflow'),
        ],
        action => [
          t8('Save and Invoice'),
          call     => [ 'kivi.DeliveryOrder.save', {
              action             => 'save_and_invoice',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
            }],
          only_if  => $self->type_data->show_menu("save_and_invoice"),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and AP Transaction'),
          call     => [ 'kivi.DeliveryOrder.save', {
              action             => 'save_and_ap_transaction',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
            }],
          only_if  => $self->type_data->show_menu("save_and_ap_transaction"),
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],

      ], # end of combobox "Workflow"

      combobox => [
        action => [
          t8('Export'),
        ],
        action => [
          t8('Save and preview PDF'),
           call    => [ 'kivi.DeliveryOrder.save', {
               action             => 'preview_pdf',
               warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
               warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
             }],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and print'),
          call     => [ 'kivi.DeliveryOrder.show_print_options', {
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate },
          ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.') : undef,
        ],
        action => [
          t8('Save and E-mail'),
          id       => 'save_and_email_action',
          call     => [ 'kivi.DeliveryOrder.save', {
              action             => 'save_and_show_email_dialog',
              warn_on_duplicates => $::instance_conf->get_order_warn_duplicate_parts,
              warn_on_reqdate    => $::instance_conf->get_order_warn_no_deliverydate,
            }],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : !$self->order->id ? t8('This object has not been saved yet.')
                    :                     undef,
        ],
        action => [
          t8('Download attachments of all parts'),
          call     => [ 'kivi.File.downloadOrderitemsFiles', $::form->{type}, $::form->{id} ],
          disabled => !$may_edit_create ? t8('You do not have the permissions to access this function.')
                    : !$self->order->id ? t8('This object has not been saved yet.')
                    :                     undef,
          only_if  => $::instance_conf->get_doc_storage,
        ],
      ], # end of combobox "Export"

      action => [
        t8('Delete'),
        id       => 'delete_action',
        call     => [ 'kivi.DeliveryOrder.delete_order' ],
        confirm  => $::locale->text('Do you really want to delete this object?'),
        disabled => !$may_edit_create       ? t8('You do not have the permissions to access this function.')
                  : !$self->order->id       ? t8('This object has not been saved yet.')
                  : $self->order->delivered ? t8('The parts for this order have already been transferred')
                  :                           undef,
        only_if  => $self->type_data->show_menu("delete"),
      ],

      combobox => [
        action => [
          t8('Transfer out'),
          id       => 'transfer_out_action',
          call     => [ 'kivi.DeliveryOrder.save', {
              action => 'transfer_stock',
            }],
          disabled => !$may_edit_create       ? t8('You do not have the permissions to access this function.')
                    : !$self->order->id       ? t8('This object has not been saved yet.')
                    : $self->order->delivered ? t8('The parts for this order have already been transferred')
                    :                           undef,
          only_if  => $self->type_data->properties('transfer') eq 'out',
          confirm  => t8('Do you really want to transfer the stock and set this order to delivered?'),
        ],
        action => [
          t8('Transfer in'),
          id       => 'transfer_in_action',
          call     => [ 'kivi.DeliveryOrder.save', {
              action => 'transfer_stock',
            }],
          disabled => !$may_edit_create       ? t8('You do not have the permissions to access this function.')
                    : !$self->order->id       ? t8('This object has not been saved yet.')
                    : $self->order->delivered ? t8('The parts for this order have already been transferred')
                    :                           undef,
          only_if  => $self->type_data->properties('transfer') eq 'in',
          confirm  => t8('Do you really want to transfer the stock and set this order to delivered?'),
        ],
        action => [
          t8('Undo Transfer'),
          id       => 'undo_transfer_action',
          call     => [ 'kivi.DeliveryOrder.save', {
              action => 'undo_transfers',
            }],
          disabled => !$may_edit_create       ? t8('You do not have the permissions to access this function.')
                    : !$self->order->id       ? t8('This object has not been saved yet.')
                    : undef,
          disabled => !$self->order->delivered,
          confirm => t8('Do you really want undo transfers the stock and set this order to undelivered?'),
        ],
      ],

      combobox => [
        action => [
          t8('more')
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'kivi.DeliveryOrder.follow_up_window' ],
          disabled => !$self->order->id ? t8('This object has not been saved yet.') : undef,
          only_if  => $::auth->assert('productivity', 1),
        ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $self->order->id, 'id' ],
          disabled => !$self->order->id ? t8('This record has not been saved yet.') : undef,
        ],
      ], # end of combobox "more"
    );
  }
}

sub generate_pdf {
  my ($order, $pdf_ref, $params) = @_;

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
    push @errors, $::locale->text(
      'Cannot find matching template for this print request. Please contact your template maintainer. I tried these: #1.',
      join ', ', map { "'$_'"} @template_files
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
        variable_content_types => {
          longdescription => 'html',
          partnotes       => 'html',
          notes           => 'html',
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

sub get_title_for {
  my ($self, $action) = @_;

  return '' if none { lc($action)} qw(add edit);
  return $self->type_data->text($action);
}

sub get_item_cvpartnumber {
  my ($self, $item) = @_;

  return if !$self->search_cvpartnumber;
  return if !$self->order->customervendor;

  if ($self->cv eq 'vendor') {
    my @mms =
      grep { $_->make eq $self->order->customervendor->id }
      @{$item->part->makemodels};
    $item->{cvpartnumber} = $mms[0]->model if scalar @mms;
  } elsif ($self->cv eq 'customer') {
    my @cps =
      grep { $_->customer_id eq $self->order->customervendor->id }
      @{$item->part->customerprices};
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

sub nr_key {
  return $_[0]->type_data->properties("nr_key");
}

sub save_and_redirect_to {
  my ($self, %params) = @_;

  $self->save();

  flash_later('info', $self->type_data->text("saved"));

  $self->redirect_to(%params, id => $self->order->id);
}

sub save_history {
  my ($self, $addition) = @_;

  my $number_type = $self->nr_key;
  my $snumbers    = $number_type . '_' . $self->order->$number_type;

  SL::DB::History->new(
    trans_id    => $self->order->id,
    employee_id => SL::DB::Manager::Employee->current->id,
    what_done   => $self->order->type,
    snumbers    => $snumbers,
    addition    => $addition,
  )->save;
}

sub store_pdf_to_webdav_and_filemanagement {
  my($order, $content, $filename) = @_;

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
      push @errors, t8('Storing PDF to webdav folder failed: #1', $@);
    };
  }
  if ($order->id && $::instance_conf->get_doc_storage) {
    eval {
      SL::File->save(object_id     => $order->id,
                     object_type   => $order->type,
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

sub calculate_stock_in_out_from_stock_info {
  my ($self, $unit, $stock_info) = @_;

  return "" if !$unit;

  my %units_by_name = map { $_->name => $_ } @{ SL::DB::Manager::Unit->get_all };

  my $sum      = sum0 map {
    $units_by_name{$_->{unit}}->convert_to($_->{qty}, $units_by_name{$unit})
  } @$stock_info;

  my $content  = _format_number($sum, 2) . ' ' . $unit;

  return $content;
}

sub calculate_stock_in_out {
  my ($self, $item, $stock_info) = @_;

  return "" if !$item->part || !$item->part->unit || !$item->unit;

  my $sum      = sum0 map {
    $_->unit_obj->convert_to($_->qty, $item->unit_obj)
  } $item->delivery_order_stock_entries;

  my $content  = _format_number($sum, 2);

  return $content;
}

sub init_type_data {
  SL::DB::Helper::TypeDataProxy->new('SL::DB::DeliveryOrder', $::form->{type});
}

sub init_valid_types {
  $_[0]->type_data->valid_types;
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

=item * C<template/webpages/delivery_order/form.html>

main form

=item * C<template/webpages/delivery_order/tabs/basic_data.html>

Main tab for basic_data.

This is the only tab here for now. "linked records" and "webdav" tabs are
reused from generic code.

=over 4

=item * C<template/webpages/delivery_order/tabs/_business_info_row.html>

For displaying information on business type

=item * C<template/webpages/delivery_order/tabs/_item_input.html>

The input line for items

=item * C<template/webpages/delivery_order/tabs/_row.html>

One row for already entered items

=item * C<template/webpages/delivery_order/tabs/_tax_row.html>

Displaying tax information

=back

=item * C<js/kivi.DeliveryOrder.js>

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

=back

=head1 To discuss / Nice to have

=over 4

=item *

How to expand/collapse second row. Now it can be done clicking the icon or
<shift>-up/down.

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

A warning when leaving the page without saving unchanged inputs.


=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
