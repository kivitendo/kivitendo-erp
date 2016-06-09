package SL::Controller::Order;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash_later);
use SL::Presenter;
use SL::Locale::String qw(t8);
use SL::SessionFile::Random;
use SL::PriceSource;
use SL::Webdav;

use SL::DB::Order;
use SL::DB::Default;
use SL::DB::Unit;
use SL::DB::Part;
use SL::DB::Printer;
use SL::DB::Language;

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;

use SL::Controller::Helper::GetModels;

use List::Util qw(first);
use List::MoreUtils qw(none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(item_ids_to_delete) ],
 'scalar --get_set_init' => [ qw(order valid_types type cv p multi_items_models all_price_factors) ],
);


# safety
__PACKAGE__->run_before('_check_auth');

__PACKAGE__->run_before('_recalc',
                        only => [ qw(save save_and_delivery_order print create_pdf send_email) ]);

__PACKAGE__->run_before('_get_unalterable_data',
                        only => [ qw(save save_and_delivery_order print create_pdf send_email) ]);

#
# actions
#

# add a new order
sub action_add {
  my ($self) = @_;

  $self->order->transdate(DateTime->now_local());
  $self->order->reqdate(DateTime->today_local->next_workday) if !$self->order->reqdate;

  $self->_pre_render();
  $self->render(
    'order/form',
    title => $self->type eq _sales_order_type()    ? $::locale->text('Add Sales Order')
           : $self->type eq _purchase_order_type() ? $::locale->text('Add Purchase Order')
           : '',
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
    title => $self->type eq _sales_order_type()    ? $::locale->text('Edit Sales Order')
           : $self->type eq _purchase_order_type() ? $::locale->text('Edit Purchase Order')
           : '',
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

  flash_later('info', $::locale->text('The order has been deleted'));
  my @redirect_params = (
    action => 'edit',
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

  flash_later('info', $::locale->text('The order has been saved'));
  my @redirect_params = (
    action => 'edit',
    type   => $self->type,
    id     => $self->order->id,
  );

  $self->redirect_to(@redirect_params);
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

  $self->{email}->{to}   = $self->order->contact->cp_email if $self->order->contact;
  $self->{email}->{to} ||= $self->order->$cv_method->email;
  $self->{email}->{cc}   = $self->order->$cv_method->cc;
  $self->{email}->{bcc}  = join ', ', grep $_, $self->order->$cv_method->bcc, SL::DB::Default->get->global_bcc;
  # Todo: get addresses from shipto, if any

  my $form = Form->new;
  $form->{ordnumber} = $self->order->ordnumber;
  $form->{formname}  = $self->type;
  $form->{type}      = $self->type;
  $form->{language} = 'de';
  $form->{format}   = 'pdf';

  $self->{email}->{subject}             = $form->generate_email_subject();
  $self->{email}->{attachment_filename} = $form->generate_attachment_filename();
  $self->{email}->{message}             = $form->create_email_signature();

  my $dialog_html = $self->render('order/tabs/_email_dialog', { output => 0 });
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

  my $mail      = Mailer->new;
  $mail->{from} = qq|"$::myconfig{name}" <$::myconfig{email}>|;
  $mail->{$_}   = $::form->{email}->{$_} for qw(to cc bcc subject message);

  my $pdf;
  my @errors = _create_pdf($self->order, \$pdf, {media => 'email'});
  if (scalar @errors) {
    return $self->js->flash('error', t8('Conversion to PDF failed: #1', $errors[0]))->render($self);
  }

  $mail->{attachments} = [{ "content" => $pdf,
                            "name"    => $::form->{email}->{attachment_filename} }];

  if (my $err = $mail->send) {
    return $self->js->flash('error', t8('Sending E-mail: ') . $err)
                    ->render($self);
  }

  # internal notes
  my $intnotes = $self->order->intnotes;
  $intnotes   .= "\n\n" if $self->order->intnotes;
  $intnotes   .= t8('[email]')                                                                                        . "\n";
  $intnotes   .= t8('Date')       . ": " . $::locale->format_date_object(DateTime->now_local, precision => 'seconds') . "\n";
  $intnotes   .= t8('To (email)') . ": " . $mail->{to}                                                                . "\n";
  $intnotes   .= t8('Cc')         . ": " . $mail->{cc}                                                                . "\n"    if $mail->{cc};
  $intnotes   .= t8('Bcc')        . ": " . $mail->{bcc}                                                               . "\n"    if $mail->{bcc};
  $intnotes   .= t8('Subject')    . ": " . $mail->{subject}                                                           . "\n\n";
  $intnotes   .= t8('Message')    . ": " . $mail->{message};

  $self->js
      ->val('#order_intnotes', $intnotes)
      ->run('kivi.Order.close_email_dialog')
      ->render($self);
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
  flash_later('info', $::locale->text('The order has been saved'));

  my @redirect_params = (
    controller => 'oe.pl',
    action     => 'oe_delivery_order_from_order',
    id         => $self->order->id,
  );

  $self->redirect_to(@redirect_params);
}

# set form elements in respect of a changed customer or vendor
#
# This action is called on an change of the customer/vendor picker.
sub action_customer_vendor_changed {
  my ($self) = @_;

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

  $self->order->taxzone_id($self->order->$cv_method->taxzone_id);

  if ($self->order->is_sales) {
    $self->order->taxincluded(defined($self->order->$cv_method->taxincluded_checked)
                              ? $self->order->$cv_method->taxincluded_checked
                              : $::myconfig{taxincluded_checked});
  }

  $self->order->payment_id($self->order->$cv_method->payment_id);
  $self->order->delivery_term_id($self->order->$cv_method->delivery_term_id);

  $self->_recalc();

  $self->js
    ->replaceWith('#order_cp_id',            $self->build_contact_select)
    ->replaceWith('#order_shipto_id',        $self->build_shipto_select)
    ->val(        '#order_taxzone_id',       $self->order->taxzone_id)
    ->val(        '#order_taxincluded',      $self->order->taxincluded)
    ->val(        '#order_payment_id',       $self->order->payment_id)
    ->val(        '#order_delivery_term_id', $self->order->delivery_term_id)
    ->val(        '#order_intnotes',         $self->order->$cv_method->notes)
    ->focus(      '#order_' . $self->cv . '_id');

  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
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
  $self->_js_redisplay_linetotals;
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
                                     ALL_PRICE_FACTORS => $self->all_price_factors
  );

  $self->js
    ->append('#row_table_id', $row_as_html)
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

# add item rows for multiple items add once
sub action_add_multi_items {
  my ($self) = @_;

  my @form_attr = grep { $_->{qty_as_number} } @{ $::form->{add_multi_items} };
  return $self->js->render() unless scalar @form_attr;

  my @items;
  foreach my $attr (@form_attr) {
    push @items, _new_item($self->order, $attr);
  }
  $self->order->add_items(@items);

  $self->_recalc();

  foreach my $item (@items) {
    my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
    my $row_as_html = $self->p->render('order/tabs/_row',
                                       ITEM              => $item,
                                       ID                => $item_id,
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

  $self->_js_redisplay_linetotals;
  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# redisplay item rows if the are sorted by an attribute
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
# Get it from OrderItem else.
sub action_get_item_longdescription {
  my $longdescription;

  if ($::form->{item_id}) {
    $longdescription = SL::DB::OrderItem->new(id => $::form->{item_id})->load->longdescription;
  } elsif ($::form->{parts_id}) {
    $longdescription = SL::DB::Part->new(id => $::form->{parts_id})->load->notes;
  }
  $_[0]->render(\ $longdescription, { type => 'text' });
}

sub _js_redisplay_linetotals {
  my ($self) = @_;

  my @data = map {$::form->format_amount(\%::myconfig, $_->{linetotal}, 2, 0)} @{ $self->order->items_sorted };
  $self->js
    ->run('kivi.Order.redisplay_linetotals', \@data);
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
  [ _sales_order_type(), _purchase_order_type() ];
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

  my $cv = $self->type eq _sales_order_type()    ? 'customer'
         : $self->type eq _purchase_order_type() ? 'vendor'
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

  $self->p->select_tag('order.cp_id', [ $self->order->{$self->cv}->contacts ],
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

  $self->p->select_tag('order.shipto_id', [ $self->order->{$self->cv}->shipto ],
                       value_key  => 'shipto_id',
                       title_key  => 'displayable_id',
                       default    => $self->order->shipto_id,
                       with_empty => 1,
                       style      => 'width: 300px',
  );
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
# And assign changes from the for to this object.
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
  $order ||= SL::DB::Order->new(orderitems => []);

  my $form_orderitems = delete $::form->{order}->{orderitems};
  $order->assign_attributes(%{$::form->{order}});

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
  $item->longdescription($item->part->notes) if $is_new && !defined $attr->{longdescription};

  return $item;
}

# create a new item
#
# This is used to add one (or more) items
sub _new_item {
  my ($record, $attr) = @_;

  my $item = SL::DB::OrderItem->new;
  $item->assign_attributes(%$attr);

  my $part         = SL::DB::Part->new(id => $attr->{parts_id})->load;
  my $price_source = SL::PriceSource->new(record_item => $item, record => $record);

  $item->unit($part->unit) if !$item->unit;

  my $price_src;
  if ($item->sellprice) {
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

  $new_attr{longdescription}        = $part->notes if ! defined $attr->{longdescription};

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $new_attr{custom_variables} = [];

  $item->assign_attributes(%new_attr);

  return $item;
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
  my $db = $self->order->db;

  $db->do_transaction(
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
  my $db = $self->order->db;

  $db->do_transaction(
    sub {
      SL::DB::OrderItem->new(id => $_)->delete for @{$self->item_ids_to_delete};
      $self->order->save(cascade => 1);
  }) || push(@{$errors}, $db->error);

  return $errors;
}


sub _pre_render {
  my ($self) = @_;

  $self->{all_taxzones}        = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_departments}     = SL::DB::Manager::Department->get_all_sorted();
  $self->{all_employees}       = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->order->employee_id,
                                                                                       deleted => 0 ] ],
                                                                    sort_by => 'name');
  $self->{all_salesmen}        = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->order->salesman_id,
                                                                                       deleted => 0 ] ],
                                                                    sort_by => 'name');
  $self->{all_projects}        = SL::DB::Manager::Project->get_all(where => [ or => [ id => $self->order->globalproject_id,
                                                                                      active => 1 ] ],
                                                                   sort_by => 'projectnumber');
  $self->{all_payment_terms}   = SL::DB::Manager::PaymentTerm->get_all_sorted();
  $self->{all_delivery_terms}  = SL::DB::Manager::DeliveryTerm->get_all_sorted();

  $self->{current_employee_id} = SL::DB::Manager::Employee->current->id;

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
    my $webdav_path = $webdav->webdav_path;
    my @all_objects = $webdav->get_all_objects;
    @{ $self->{template_args}->{WEBDAV} } = map { { name => $_->filename,
                                                    type => t8('File'),
                                                    link => File::Spec->catdir($webdav_path, $_->filename),
                                                } } @all_objects;
  }

  $::request->{layout}->use_javascript("${_}.js")  for qw(kivi.SalesPurchase kivi.Order ckeditor/ckeditor ckeditor/adapters/jquery);
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
  $print_form->{language}    = $params->{language}->template_code if $print_form->{language};
  $print_form->{language_id} = $params->{language}->id            if $print_form->{language};

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

sub _sales_order_type {
  'sales_order';
}

sub _purchase_order_type {
  'purchase_order';
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

=item * C<template/webpages/order/tabs/_email_dialog.html>

Email dialog

=back

=item *

js/kivi.Order.js: java script functions

=back

=head1 TODO

=over 4

=item * testing

=item * currency

=item * customer/vendor details ('D'-button)

=item * credit limit

=item * more workflows (save as new / invoice)

=item * price sources: little symbols showing better price / better discount

=item * custom shipto address

=item * periodic invoices

=item * more details on second row (marge, ...)

=item * language / part translations

=item * access rights

=item * preset salesman from customer

=item * display weights

=item * force project if enabled in client config

=back

=head1 KNOWN BUGS AND CAVEATS

=over 4

=item *

C<position> is not displayed until an order is saved

=item *

Customer discount is not displayed as a valid discount in price source popup
(this might be a bug in price sources)

=item *

No indication that double click expands second row, no exand all button

=item *

Implementation of second row with a tbody for every item is not supported by
our css.

=item *

As a consequence row striping does not currently work

=item *

Inline creation of parts is not currently supported

=item *

Table header is not sticky in the scrolling area.

=item *

Sorting does not include C<position>, neither does reordering.

=item *

C<show_smulti_items_dialog> does not use the currently inserted string for filtering.

=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
