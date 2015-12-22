package SL::Controller::Order;

use strict;
use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Presenter;
use SL::Locale::String;
use SL::SessionFile::Random;
use SL::PriceSource;
use SL::Form;
use SL::Webdav;

use SL::DB::Order;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::DB::TaxZone;
use SL::DB::Employee;
use SL::DB::Project;
use SL::DB::Default;
use SL::DB::Unit;
use SL::DB::Price;
use SL::DB::Part;

use SL::Helper::DateTime;
use SL::Helper::CreatePDF qw(:all);

use SL::Controller::Helper::GetModels;

use List::Util qw(max first);
use List::MoreUtils qw(none pairwise first_index);
use English qw(-no_match_vars);
use File::Spec;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(item_ids_to_delete) ],
 'scalar --get_set_init' => [ qw(order valid_types type cv p multi_items_models) ],
);


# safety
__PACKAGE__->run_before('_check_auth');

__PACKAGE__->run_before('_recalc',
                        only => [ qw(update save save_and_delivery_order create_pdf send_email) ]);

__PACKAGE__->run_before('_get_unalterable_data',
                        only => [ qw(save save_and_delivery_order create_pdf send_email) ]);

#
# actions
#

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

sub action_update {
  my ($self) = @_;

  $self->_pre_render();
  $self->render(
    'order/form',
    title => $self->type eq _sales_order_type()    ? $::locale->text('Edit Sales Order')
           : $self->type eq _purchase_order_type() ? $::locale->text('Edit Purchase Order')
           : '',
    %{$self->{template_args}}
  );
}

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

sub action_create_pdf {
  my ($self) = @_;

  my $pdf;
  my @errors = _create_pdf($self->order, \$pdf);
  if (scalar @errors) {
    return $self->js->flash('error', t8('Conversion to PDF failed: #1', $errors[0]))->render($self);
  }

  my $sfile = SL::SessionFile::Random->new(mode => "w");
  $sfile->fh->print($pdf);
  $sfile->fh->close;

  my $key = join('_', Time::HiRes::gettimeofday(), int rand 1000000000000);
  $::auth->set_session_value("Order::create_pdf-${key}" => $sfile->file_name);

  my $form = Form->new;
  $form->{ordnumber} = $self->order->ordnumber;
  $form->{formname}  = $self->type;
  $form->{type}      = $self->type;
  $form->{language}  = 'de';
  $form->{format}    = 'pdf';

  my $pdf_filename = $form->generate_attachment_filename();

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

  $self->js
    ->run('download_pdf', $pdf_filename, $key)
    ->flash('info', t8('The PDF has been created'))->render($self);
}

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
      ->run('show_email_dialog', $dialog_html)
      ->reinit_widgets
      ->render($self);
}

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
      ->run('close_email_dialog')
      ->render($self);
}

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

sub action_unit_changed {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{orderitem_ids} };
  my $item = $self->order->items_sorted->[$idx];

  my $old_unit_obj = SL::DB::Unit->new(name => $::form->{old_unit})->load;
  $item->sellprice($item->unit_obj->convert_to($item->sellprice, $old_unit_obj));

  $self->_recalc();

  $self->js
    ->run('update_sellprice', $::form->{item_id}, $item->sellprice_as_number);
  $self->_js_redisplay_linetotals;
  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

sub action_add_item {
  my ($self) = @_;

  my $form_attr = $::form->{add_item};

  return unless $form_attr->{parts_id};

  my $item = _new_item($self->order, $form_attr);
  $self->order->add_items($item);

  $self->_recalc();

  my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $row_as_html = $self->p->render('order/tabs/_row', ITEM => $item, ID => $item_id);

  $self->js
    ->append('#row_table_id', $row_as_html)
    ->val('.add_item_input', '')
    ->run('row_table_scroll_down')
    ->run('row_set_keyboard_events_by_id', $item_id)
    ->run('set_unit_change_with_oldval_by_id', $item_id)
    ->run('renumber_positions')
    ->on('.recalc', 'change', 'recalc_amounts_and_taxes')
    ->on('.reformat_number', 'change', 'reformat_number')
    ->focus('#add_item_parts_id_name');

  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

sub action_show_multi_items_dialog {
  require SL::DB::PartsGroup;
  $_[0]->render('order/tabs/_multi_items_dialog', { layout => 0 },
                all_partsgroups => SL::DB::Manager::PartsGroup->get_all);
}

sub action_multi_items_update_result {
  my $max_count = 100;
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
    my $row_as_html = $self->p->render('order/tabs/_row', ITEM => $item, ID => $item_id);

    $self->js
        ->append('#row_table_id', $row_as_html)
        ->run('row_set_keyboard_events_by_id', $item_id)
        ->run('set_unit_change_with_oldval_by_id', $item_id);
  }

  $self->js
    ->run('close_multi_items_dialog')
    ->run('row_table_scroll_down')
    ->run('renumber_positions')
    ->on('.recalc', 'change', 'recalc_amounts_and_taxes')
    ->on('.reformat_number', 'change', 'reformat_number')
    ->focus('#add_item_parts_id_name');

  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

sub action_recalc_amounts_and_taxes {
  my ($self) = @_;

  $self->_recalc();

  $self->_js_redisplay_linetotals;
  $self->_js_redisplay_amounts_and_taxes;
  $self->js->render();
}

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
    ->run('redisplay_items', \@to_sort)
    ->render;
}

sub action_price_popup {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{orderitem_ids} };
  my $item = $self->order->items_sorted->[$idx];

  $self->render_price_dialog($item);
}

sub _js_redisplay_linetotals {
  my ($self) = @_;

  my @data = map {$::form->format_amount(\%::myconfig, $_->{linetotal}, 2, 0)} @{ $self->order->items_sorted };
  $self->js
    ->run('redisplay_linetotals', \@data);
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

sub _check_auth {
  my ($self) = @_;

  my $right_for = { map { $_ => $_.'_edit' } @{$self->valid_types} };

  my $right   = $right_for->{ $self->type };
  $right    ||= 'DOES_NOT_EXIST';

  $::auth->assert($right);
}

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


# Make item objects from form values. For items already existing read from db.
# Create a new item else. And assign attributes.
sub _make_item {
  my ($record, $attr) = @_;

  my $item;
  $item = first { $_->id == $attr->{id} } @{$record->items} if $attr->{id};

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $item ||= SL::DB::OrderItem->new(custom_variables => []);
  $item->assign_attributes(%$attr);

  return $item;
}

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
  $new_attr{description}            = $part->description if ! $item->description;
  $new_attr{qty}                    = 1.0                if ! $item->qty;
  $new_attr{sellprice}              = $price_src->price;
  $new_attr{discount}               = $discount_src->discount;
  $new_attr{active_price_source}    = $price_src;
  $new_attr{active_discount_source} = $discount_src;

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
  $new_attr{custom_variables} = [];

  $item->assign_attributes(%new_attr);

  return $item;
}

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


sub _get_unalterable_data {
  my ($self) = @_;

  foreach my $item (@{ $self->order->items }) {
    if ($item->id) {
      # load data from orderitems (db)
      my $db_item = SL::DB::OrderItem->new(id => $item->id)->load;
      $item->$_($db_item->$_) for qw(longdescription);
    } else {
      # set data from part (or other sources)
      $item->longdescription($item->part->notes);
    }

    # autovivify all cvars that are not in the form (cvars_by_config can do it).
    # workaround to pre-parse number-cvars (parse_custom_variable_values does not parse number values).
    foreach my $var (@{ $item->cvars_by_config }) {
      $var->unparsed_value($::form->parse_amount(\%::myconfig, $var->{__unparsed_value})) if ($var->config->type eq 'number' && exists($var->{__unparsed_value}));
    }
    $item->parse_custom_variable_values;
  }
}


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

  $::request->{layout}->use_javascript("${_}.js")  for qw(ckeditor/ckeditor ckeditor/adapters/jquery);
}

sub _create_pdf {
  my ($order, $pdf_ref, $params) = @_;

  my $print_form = Form->new('');
  $print_form->{type}     = $order->type;
  $print_form->{formname} = $order->type;
  $print_form->{format}   = $params->{format} || 'pdf',
  $print_form->{media}    = $params->{media}  || 'file';

  $order->flatten_to_form($print_form, format_amounts => 1);
  # flatten_to_form sets payment_terms from customer/vendor - we do not want that here
  delete $print_form->{payment_terms} if !$print_form->{payment_id};

  my @errors = ();
  $print_form->throw_on_error(sub {
    eval {
      $print_form->prepare_for_printing;

      $$pdf_ref = SL::Helper::CreatePDF->create_pdf(
        template  => SL::Helper::CreatePDF->find_template(name => $print_form->{formname}),
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
