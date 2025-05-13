package SL::Controller::Invoice;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash qw(flash flash_later);
use SL::DB::Invoice;
use SL::DB::Invoice::TypeData qw(:types);
use SL::DB::PurchaseInvoice;
use SL::DB::PurchaseInvoice::TypeData qw(:types);
use SL::Model::Record;

use Archive::Zip;
use Params::Validate qw(:all);
use List::MoreUtils qw(any first_index);

use SL::DB::File;
use SL::DB::Invoice;
use SL::DB::Employee;

use SL::Webdav;
use SL::File;
use SL::Locale::String qw(t8);
use SL::MoreCommon qw(listify);
use SL::Presenter::Tag qw(select_tag div_tag);

use SL::Helper::PrintOptions;

__PACKAGE__->run_before('check_auth');

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(item_ids_to_delete is_custom_shipto_to_delete) ],
  'scalar --get_set_init' => [ qw(
    record valid_types cv p all_price_factors search_cvpartnumber
    show_update_button part_picker_classification_ids is_final_version
    type_data
  ) ],
);


sub check_auth {
  my ($self) = @_;

  # TODO: add view, and exceptions for globalproject etc.

  return 1 if  $::auth->assert($self->type_data->rights('edit'), 1); # may edit all invoices
  my @ids = listify($::form->{id});
  $::auth->assert() unless has_rights_through_projects(\@ids);
  return 1;
}

sub has_rights_through_projects {
  my ($ids) = validate_pos(@_, {
    type => ARRAYREF,
  });
  return 0 unless scalar @{$ids}; # creating new invoices isn't allowed without invoice_edit
  my $current_employee = SL::DB::Manager::Employee->current;
  my $id_placeholder = join(', ', ('?') x @{$ids});
  # Count of ids where the use has no access to
  my $query = <<SQL;
  SELECT count(id) FROM ar
  WHERE NOT EXISTS (
    SELECT * from employee_project_invoices WHERE project_id = ar.globalproject_id and employee_id = ?
  ) AND id IN ($id_placeholder)
SQL
  my ($no_access_count) = SL::DB->client->dbh->selectrow_array($query, undef, $current_employee->id, @{$ids});
  return !$no_access_count;
}

# add a new invoice
sub action_add {
  my ($self) = @_;

  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(
      scope => SL::DB::ValidityToken::SCOPE_INVOICE_POST()
    )->token;
  }

  $self->render(
    'invoice/form',
    title => $self->type_data->text('add'),
  );
}

# set form elements in respect to a changed customer or vendor
#
# This action is called on an change of the customer/vendor picker.
sub action_customer_vendor_changed {
  my ($self) = @_;

  $self->record(SL::Model::Record->update_after_customer_vendor_change($self->record));

  $self->recalc();

  if ($self->record->customervendor->contacts && scalar @{ $self->record->customervendor->contacts } > 0) {
    $self->js->show('#cp_row');
  } else {
    $self->js->hide('#cp_row');
  }

  if ($self->record->type_data->properties('is_customer')) {
    if ($self->record->customer->shipto && scalar @{ $self->record->customer->shipto } > 0) {
      $self->js->show('#shipto_selection');
    } else {
      $self->js->hide('#shipto_selection');
    }


    my $show_hide = scalar @{ $self->record->customer->additional_billing_addresses } > 0 ? 'show' : 'hide';
    $self->js
      ->$show_hide('#billing_address_row')
      ->val( '#record_salesman_id', $self->record->salesman_id)
      ->replaceWith('#record_shipto_id',          $self->build_shipto_select)
      ->replaceWith('#shipto_inputs',             $self->build_shipto_inputs)
      ->replaceWith('#record_billing_address_id', $self->build_billing_address_select)
      ;
  }

  $self->js
    ->replaceWith('#record_cp_id',              $self->build_contact_select)
    ->replaceWith('#business_info_row',         $self->build_business_info_row)
    ->val(        '#record_taxzone_id',         $self->record->taxzone_id)
    ->val(        '#record_taxincluded',        $self->record->taxincluded)
    ->val(        '#record_currency_id',        $self->record->currency_id)
    ->val(        '#record_payment_id',         $self->record->payment_id)
    ->val(        '#record_delivery_term_id',   $self->record->delivery_term_id)
    ->val(        '#record_intnotes',           $self->record->intnotes)
    ->val(        '#record_language_id',        $self->record->customervendor->language_id)
    ->focus(      '#record_' . $self->record->type_data->properties('customervendor') . '_id')
    ->run('kivi.Invoice.update_exchangerate');

  $self->js_redisplay_amounts_and_taxes;
  $self->js_redisplay_cvpartnumbers;
  $self->js->render();
}

# update item input row when a part ist picked
sub action_update_item_input_row {
  my ($self) = @_;

  delete $::form->{add_item}->{$_} for qw(create_part_type sellprice_as_number discount_as_percent);

  my $form_attr = $::form->{add_item};

  return unless $form_attr->{parts_id};

  my $record       = $self->record;
  my $item         = SL::DB::InvoiceItem->new(%$form_attr);
  $item->qty(1) if !$item->qty;
  $item->unit($item->part->unit);

  my ($price_src, $discount_src) = SL::Model::Record->get_best_price_and_discount_source($record, $item, ignore_given => 0);

  $self->js
    ->val     ('#add_item_unit',                $item->unit)
    ->val     ('#add_item_description',         $item->part->description)
    ->val     ('#add_item_sellprice_as_number', '')
    ->attr    ('#add_item_sellprice_as_number', 'placeholder', $price_src->price_as_number)
    ->attr    ('#add_item_sellprice_as_number', 'title',       $price_src->source_description)
    ->val     ('#add_item_discount_as_percent', '')
    ->attr    ('#add_item_discount_as_percent', 'placeholder', $discount_src->discount_as_percent)
    ->attr    ('#add_item_discount_as_percent', 'title',       $discount_src->source_description)
    ->render;
}

sub action_update_exchangerate {
  my ($self) = @_;

  my $data = {
    is_standard   => $self->record->currency_id == $::instance_conf->get_currency_id,
    currency_name => $self->record->currency->name,
    exchangerate  => $self->record->daily_exchangerate_as_null_number,
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

  $self->get_item_cvpartnumber($_) for @{$self->record->items_sorted};

  my $method = $sort_keys{$::form->{order_by}};
  my @to_sort = map { { old_pos => $_->position, order_by => $method->($_) } } @{ $self->record->items_sorted };
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
    ->run('kivi.Invoice.redisplay_items', \@to_sort)
    ->render;
}

# save the order in a session variable and redirect to the part controller
sub action_create_part {
  my ($self) = @_;

  my $previousform = $::auth->save_form_in_session(non_scalars => 1);

  my $callback     = $self->url_for(
    action       => 'return_from_create_part',
    type         => $self->record->record_type, # type is needed for check_auth on return
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

# show the popup to choose a price/discount source
sub action_price_popup {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{item_ids} };
  my $item = $self->record->items_sorted->[$idx];

  $self->render_price_dialog($item);
}

sub action_return_from_create_part {
  my ($self) = @_;

  $self->{created_part} = SL::DB::Part->new(
    id => delete $::form->{new_parts_id}
  )->load if $::form->{new_parts_id};

  $::auth->restore_form_from_session(delete $::form->{previousform});

  $self->record($self->init_record);
  $self->reinit_after_new_invoice();

  if ($self->record->id) {
    $self->pre_render();
    $self->render(
      'invoice/form',
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

  $self->recalc();

  foreach my $item_id (@{ $::form->{item_ids} }) {
    my $idx  = first_index { $_ eq $item_id } @{ $::form->{items} };
    my $item = $self->record->items_sorted->[$idx];

    $self->js_load_second_row($item, $item_id);
  }

  $self->js->run('kivi.Invoice.init_row_handlers');
  $self->js->render();
}

# add an item row for a new item entered in the input row
sub action_add_item {
  my ($self) = @_;

  delete $::form->{add_item}->{create_part_type};

  my $form_attr = $::form->{add_item};

  return unless $form_attr->{parts_id};

  my $item = new_item($self->record, $form_attr);

  $self->record->add_items($item);

  $self->recalc();

  $self->get_item_cvpartnumber($item);

  my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
  my $row_as_html = $self->p->render('invoice/tabs/_row',
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
      my $item = new_item($self->record, $attr);

      # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
      $item->discount(1) unless $assortment_item->charge;

      $self->record->add_items( $item );
      $self->recalc();
      $self->get_item_cvpartnumber($item);
      my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
      my $row_as_html = $self->p->render('record/tabs/_row',
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
    ->attr('.add_item_input', 'placeholder', '')
    ->attr('.add_item_input', 'title', '')
    ->attr('#add_item_qty_as_number', 'placeholder', '1')
    ->run('kivi.Invoice.init_row_handlers')
    ->run('kivi.Invoice.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.Invoice.row_table_scroll_down') if !$::form->{insert_before_item_id};

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
    my $item = new_item($self->record, $attr);
    push @items, $item;
    if ( $item->part->is_assortment ) {
      foreach my $assortment_item ( @{$item->part->assortment_items} ) {
        my $attr = { parts_id => $assortment_item->parts_id,
                     qty      => $assortment_item->qty * $item->qty, # TODO $form_attr->{unit}
                     unit     => $assortment_item->unit,
                     description => $assortment_item->part->description,
                   };
        my $item = new_item($self->record, $attr);

        # set discount to 100% if item isn't supposed to be charged, overwriting any customer discount
        $item->discount(1) unless $assortment_item->charge;
        push @items, $item;
      }
    }
  }
  $self->record->add_items(@items);

  $self->recalc();

  foreach my $item (@items) {
    $self->get_item_cvpartnumber($item);
    my $item_id = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);
    my $row_as_html = $self->p->render('invoice/tabs/_row',
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
    ->run('kivi.Invoice.init_row_handlers')
    ->run('kivi.Invoice.renumber_positions')
    ->focus('#add_item_parts_id_name');

  $self->js->run('kivi.Invoice.row_table_scroll_down') if !$::form->{insert_before_item_id};

  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

# called if a unit in an existing item row is changed
sub action_unit_changed {
  my ($self) = @_;

  my $idx  = first_index { $_ eq $::form->{item_id} } @{ $::form->{item_ids} };
  my $item = $self->record->items_sorted->[$idx];

  my $old_unit_obj = SL::DB::Unit->new(name => $::form->{old_unit})->load;
  $item->sellprice($item->unit_obj->convert_to($item->sellprice, $old_unit_obj));

  $self->recalc();

  $self->js
    ->run('kivi.Invoice.update_sellprice', $::form->{item_id}, $item->sellprice_as_number);
  $self->js_redisplay_line_values;
  $self->js_redisplay_amounts_and_taxes;
  $self->js->render();
}

sub action_webdav_pdf_export {
  my ($self) = @_;
  my $ids  = $::form->{id};

  my $invoices = SL::DB::Manager::Invoice->get_all(where => [ id => $ids ]);

  my @file_names_and_file_paths;
  my @errors;
  foreach my $invoice (@{$invoices}) {
    my $record_type = $invoice->record_type;
    $record_type = 'invoice' if $record_type eq 'ar_transaction';
    $record_type = 'invoice' if $record_type eq 'invoice_storno';
    my $webdav = SL::Webdav->new(
      type     => $record_type,
      number   => $invoice->record_number,
    );
    my @latest_object = $webdav->get_all_latest();
    unless (scalar @latest_object) {
      push @errors, t8(
        "No Dokument found for record '#1'. Please deselect it or create a document it.",
        $invoice->displayable_name()
      );
      next;
    }
    push @file_names_and_file_paths, {
      file_name => $latest_object[0]->basename . "." . $latest_object[0]->extension,
      file_path => $latest_object[0]->full_filedescriptor(),
    }
  }

  if (scalar @errors) {
    die join("\n", @errors);
  }
  $self->_create_and_send_zip(\@file_names_and_file_paths);
}

sub action_files_pdf_export {
  my ($self) = @_;

  my $ids  = $::form->{id};

  my $invoices = SL::DB::Manager::Invoice->get_all(where => [ id => $ids ]);

  my @file_names_and_file_paths;
  my @errors;
  foreach my $invoice (@{$invoices}) {
    my $record_type = $invoice->record_type;
    $record_type = 'invoice' if $record_type eq 'ar_transaction';
    $record_type = 'invoice' if $record_type eq 'invoice_storno';
    my @file_objects = SL::File->get_all(
      object_type => $record_type,
      object_id   => $invoice->id,
      file_type   => 'document',
      source      => 'created',
    );

    unless (scalar @file_objects) {
      push @errors, t8(
        "No Dokument found for record '#1'. Please deselect it or create a document it.",
        $invoice->displayable_name()
      );
      next;
    }
    foreach my $file_object (@file_objects) {
      eval {
        push @file_names_and_file_paths, {
          file_name => $file_object->file_name,
          file_path => $file_object->get_file(),
        };
      } or do {
        push @errors, $@,
      };
    }
  }

  if (scalar @errors) {
    die join("\n", @errors);
  }
  $self->_create_and_send_zip(\@file_names_and_file_paths);
}

sub reinit_after_new_invoice {
  my ($self) = @_;

  # change form type
  $::form->{type} = $self->record->type;
  $self->type_data($self->init_type_data);
  $self->cv($self->init_cv);
  $self->check_auth;

  $self->setup_custom_shipto_from_form($self->record, $::form);

  foreach my $item (@{$self->record->items_sorted}) {
    # set item ids to new fake id, to identify them as new items
    $item->{new_fake_id} = join('_', 'new', Time::HiRes::gettimeofday(), int rand 1000000000000);

    # trigger rendering values for second row as hidden, because they
    # are loaded only on demand. So we need to keep the values from the
    # source.
    $item->{render_second_row} = 1;
  }

  $self->recalc();
}


sub pre_render {
  my ($self) = @_;

  $self->{all_taxzones}               = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_currencies}             = SL::DB::Manager::Currency->get_all_sorted();
  $self->{all_departments}            = SL::DB::Manager::Department->get_all_sorted();
  $self->{all_languages}              = SL::DB::Manager::Language->get_all_sorted(
    query => [ or => [ obsolete => 0, id => $self->record->language_id ] ]
  );
  $self->{all_employees}              = SL::DB::Manager::Employee->get_all(
    where => [ or => [ id => $self->record->employee_id, deleted => 0 ] ],
    sort_by => 'name'
  );
  if ($self->record->type_data->properties('is_customer')) {
    $self->{all_salesmen} = SL::DB::Manager::Employee->get_all(
      where => [ or => [ id => $self->record->salesman_id, deleted => 0 ] ],
      sort_by => 'name'
    );
  }
  $self->{all_payment_terms}          = SL::DB::Manager::PaymentTerm->get_all_sorted(
    where => [ or => [ id => $self->record->payment_id, obsolete => 0 ] ]
  );
  $self->{all_delivery_terms}         = SL::DB::Manager::DeliveryTerm->get_valid(
    $self->record->delivery_term_id
  );
  $self->{current_employee_id}        = SL::DB::Manager::Employee->current->id;
  $self->{positions_scrollbar_height} = SL::Helper::UserPreferences::PositionsScrollbar->new()->get_height();

  my $print_form = Form->new('');
  $print_form->{type}        = $self->record->record_type;
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

  foreach my $item (@{$self->record->items}) {
    my $price_source = SL::PriceSource->new(record_item => $item, record => $self->record);
    $item->active_price_source(   $price_source->price_from_source(   $item->active_price_source   ));
    $item->active_discount_source($price_source->discount_from_source($item->active_discount_source));
  }

  if ($self->record->record_number && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => $self->type,
      number   => $self->record->record_number,
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $self->{template_args}->{WEBDAV} } = map { { name => $_->filename,
                                                    type => t8('File'),
                                                    link => File::Spec->catfile($_->full_filedescriptor),
                                                } } @all_objects;
  }

  $self->{template_args}->{longdescription_dialog_size_percentage} =
    SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();

  $self->get_item_cvpartnumber($_) for @{$self->record->items_sorted};

  $::request->{layout}->use_javascript("${_}.js") for qw(
      kivi.Validator kivi.SalesPurchase kivi.Invoice kivi.File
      calculate_qty show_history
    );
  $self->setup_action_bar;
}

# build the selection box for contacts
#
# Needed, if customer/vendor changed.
sub build_contact_select {
  my ($self) = @_;

  select_tag('record.cp_id', [ $self->record->customervendor->contacts ],
    value_key  => 'cp_id',
    title_key  => 'full_name_dep',
    default    => $self->record->cp_id,
    with_empty => 1,
    style      => 'width: 300px',
  );
}

# build the selection box for shiptos
#
# Needed, if customer/vendor changed.
sub build_shipto_select {
  my ($self) = @_;

  select_tag('record.shipto_id',
             [ {displayable_id => t8("No/individual shipping address"), shipto_id => ''}, $self->record->customer->shipto ],
             value_key  => 'shipto_id',
             title_key  => 'displayable_id',
             default    => $self->record->shipto_id,
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
                                 vc_obj      => $self->record->customervendor,
                                 cs_obj      => $self->record->custom_shipto,
                                 cvars       => $self->record->custom_shipto->cvars_by_config,
                                 id_selector => '#record_shipto_id');

  div_tag($content, id => 'shipto_inputs');
}

# build the selection box for the additional billing address
#
# Needed, if customer/vendor changed.
sub build_billing_address_select {
  my ($self) = @_;

  select_tag('record.billing_address_id',
             [ {displayable_id => '', id => ''}, $self->record->customervendor->additional_billing_addresses ],
             value_key  => 'id',
             title_key  => 'displayable_id',
             default    => $self->record->billing_address_id,
             with_empty => 0,
             style      => 'width: 300px',
  );
}

# render the info line for business
#
# Needed, if customer/vendor changed.
sub build_business_info_row {
  $_[0]->p->render('invoice/tabs/_business_info_row', SELF => $_[0]);
}

# build the rows for displaying taxes
#
# Called if amounts where recalculated and redisplayed.
sub build_tax_rows {
  my ($self) = @_;

  my $rows_as_html;
  foreach my $tax (sort { $a->{tax}->rate cmp $b->{tax}->rate } @{ $self->{taxes} }) {
    $rows_as_html .= $self->p->render(
      'invoice/tabs/_tax_row',
      SELF => $self,
      TAX => $tax,
      TAXINCLUDED => $self->record->taxincluded,
    );
  }
  return $rows_as_html;
}

sub js_load_second_row {
  my ($self, $item, $item_id) = @_;

  my $row_as_html = $self->p->render('invoice/tabs/_second_row', ITEM => $item, TYPE => $self->record->record_type);

  $self->js
    ->html('#second_row_' . $item_id, $row_as_html)
    ->data('#second_row_' . $item_id, 'loaded', 1);
}

sub js_redisplay_line_values {
  my ($self) = @_;

  my $has_marge = $self->record->type_data->properties('has_marge');

  my @data;
  if ($has_marge) {
    @data = map {
      [
       $::form->format_amount(\%::myconfig, $_->{linetotal},     2, 0),
       $::form->format_amount(\%::myconfig, $_->{marge_total},   2, 0),
       $::form->format_amount(\%::myconfig, $_->{marge_percent}, 2, 0),
      ]} @{ $self->record->items_sorted };
  } else {
    @data = map {
      [
       $::form->format_amount(\%::myconfig, $_->{linetotal},     2, 0),
      ]} @{ $self->record->items_sorted };
  }

  $self->js
    ->run('kivi.Invoice.redisplay_line_values', $has_marge, \@data);
}

sub js_redisplay_amounts_and_taxes {
  my ($self) = @_;

  if (scalar @{ $self->{taxes} }) {
    $self->js->show('#taxincluded_row_id');
  } else {
    $self->js->hide('#taxincluded_row_id');
  }

  if ($self->record->taxincluded) {
    $self->js->hide('#subtotal_row_id');
  } else {
    $self->js->show('#subtotal_row_id');
  }

  if ($self->record->type_data->properties('has_marge')) {
    my $is_neg = $self->record->marge_total < 0;
    $self->js
      ->html('#marge_total_id',   $::form->format_amount(\%::myconfig, $self->record->marge_total,   2))
      ->html('#marge_percent_id', $::form->format_amount(\%::myconfig, $self->record->marge_percent, 2))
      ->action_if( $is_neg, 'addClass',    '#marge_total_id',        'plus0')
      ->action_if( $is_neg, 'addClass',    '#marge_percent_id',      'plus0')
      ->action_if( $is_neg, 'addClass',    '#marge_percent_sign_id', 'plus0')
      ->action_if(!$is_neg, 'removeClass', '#marge_total_id',        'plus0')
      ->action_if(!$is_neg, 'removeClass', '#marge_percent_id',      'plus0')
      ->action_if(!$is_neg, 'removeClass', '#marge_percent_sign_id', 'plus0');
  }

  $self->js
    ->html('#netamount_id', $::form->format_amount(\%::myconfig, $self->record->netamount, -2))
    ->html('#amount_id',    $::form->format_amount(\%::myconfig, $self->record->amount,    -2))
    ->remove('.tax_row')
    ->insertBefore($self->build_tax_rows, '#amount_row_id');
}

sub js_redisplay_cvpartnumbers {
  my ($self) = @_;

  $self->get_item_cvpartnumber($_) for @{$self->record->items_sorted};

  my @data = map {[$_->{cvpartnumber}]} @{ $self->record->items_sorted };

  $self->js
    ->run('kivi.Invoice.redisplay_cvpartnumbers', \@data);
}

sub recalc {
  my ($self) = @_;

  $self->{taxes} = [];
  # TODO: calculate see 'sub form_footer' in is/ir.pl
}

sub setup_action_bar {
  my ($self, %params) = @_;

  my $change_never            = $::instance_conf->get_is_changeable == 0;
  my $change_on_same_day_only = $::instance_conf->get_is_changeable == 2 && DateTime->today_local ne $self->record->gldate;
  my $payments_balanced       = ($::form->{oldtotalpaid} == 0); # TODO not implemented yet
  my $has_storno              = $self->record->storno && !$self->record->storno_id; # TODO: move to SL::DB::*
  my $may_edit_create         = $::auth->assert('invoice_edit', 1);
  my $factur_x_enabled        = $self->record && $self->type_data->properties('is_customer') && $self->record->customer
                             && $self->record->customer->create_zugferd_invoices_for_this_customer;
  my $locked                  = $self->record->transdate && $self->record->transdate <= $::instance_conf->get_closedto;

  my $is_linked_bank_transaction = $self->record->id
      && SL::DB::Default->get->payments_changeable != 0
      && SL::DB::Manager::BankTransactionAccTrans->find_by(ar_id => $self->record->id);

  my $warn_unlinked_delivery_order = $::instance_conf->get_warn_no_delivery_order_for_invoice
      && !$self->record->id && $::form->{convert_from_record_type_ref} ne 'SL::DB::DeliveryOrder';  # TODO make this more robust

  my $has_further_invoice_for_advance_payment;
  if ($self->record->id && $self->type eq "invoice_for_advance_payment") {
    my $lr          = $self->record->linked_records(direction => 'to', to => ['Invoice']);
    $has_further_invoice_for_advance_payment = any {'SL::DB::Invoice' eq ref $_ && "invoice_for_advance_payment" eq $_->type} @$lr;
  }

  my $has_final_invoice;
  if ($self->record->id && $self->type eq "invoice_for_advance_payment") {
    my $lr          = $self->record->linked_records(direction => 'to', to => ['Invoice']);
    $has_final_invoice = any {'SL::DB::Invoice' eq ref $_ && "final_invoice" eq $_->invoice_type} @$lr;
  }

  my $is_invoice_for_advance_payment_from_order;
  if ($self->record->id && $self->type eq "invoice_for_advance_payment") {
    my $lr          = $self->record->linked_records(direction => 'from', from => ['Order']);
    $is_invoice_for_advance_payment_from_order = scalar @$lr >= 1;
  }


  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => "update" } ],
        disabled  => !$may_edit_create ? t8('You must not change this invoice.')
                   : $locked           ? t8('The billing period has already been locked.')
                   :                     undef,
        id        => 'update_button',
        accesskey => 'enter',
      ],

      combobox => [
        action => [
          t8('Post'),
          submit   => [ '#form', { action => "post" } ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('The invoice is not linked with a sales delivery order. Post anyway?') x !!$warn_unlinked_delivery_order,
          disabled => !$may_edit_create                         ? t8('You must not change this invoice.')
                    : $locked                                   ? t8('The billing period has already been locked.')
                    : $self->record->storno                     ? t8('A canceled invoice cannot be posted.')
                    : ($self->record->id && $change_never)      ? t8('Changing invoices has been disabled in the configuration.')
                    : ($self->record->id && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [
          t8('Post and Close'),
          submit   => [ '#form', { action => "post_and_close" } ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('The invoice is not linked with a sales delivery order. Post anyway?') x !!$warn_unlinked_delivery_order,
          disabled => !$may_edit_create                         ? t8('You must not change this invoice.')
                    : $locked                                   ? t8('The billing period has already been locked.')
                    : $self->record->storno                     ? t8('A canceled invoice cannot be posted.')
                    : ($self->record->id && $change_never)      ? t8('Changing invoices has been disabled in the configuration.')
                    : ($self->record->id && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [
          t8('Post Payment'),
          submit   => [ '#form', { action => "post_payment" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create           ? t8('You must not change this invoice.')
                    : !$self->record->id          ? t8('This invoice has not been posted yet.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                               undef,
          only_if  => $self->type_data->show_menu('post_payment'),
        ],
        action => [ t8('Mark as paid'),
          submit   => [ '#form', { action => "mark_as_paid" } ],
          confirm  => t8('This will remove the invoice from showing as unpaid even if the unpaid amount does not match the amount. Proceed?'),
          disabled => !$may_edit_create ? t8('You must not change this invoice.')
                    : !$self->record->id ? t8('This invoice has not been posted yet.')
                    :                     undef,
          only_if  => $self->type_data->show_menu('mark_as_paid'),
        ],
      ], # end of combobox "Post"

      combobox => [
        action => [ t8('Storno'),
          submit   => [ '#form', { action => "storno" } ],
          confirm  => t8('Do you really want to cancel this invoice?'),
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create   ? t8('You must not change this invoice.')
                    : !$self->record->id  ? t8('This invoice has not been posted yet.')
                    : $self->record->storno ? t8('Cannot storno storno invoice!')
                    : $locked             ? t8('The billing period has already been locked.')
                    : !$payments_balanced ? t8('Cancelling is disallowed. Either undo or balance the current payments until the open amount matches the invoice amount')
                    : undef,
        ],
        action => [ t8('Delete'),
          submit   => [ '#form', { action => "delete" } ],
          confirm  => t8('Do you really want to delete this object?'),
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create        ? t8('You must not change this invoice.')
                    : !$self->record->id       ? t8('This invoice has not been posted yet.')
                    : $locked                  ? t8('The billing period has already been locked.')
                    : $change_never            ? t8('Changing invoices has been disabled in the configuration.')
                    : $change_on_same_day_only ? t8('Invoices can only be changed on the day they are posted.')
                    : $has_storno              ? t8('Can only delete the "Storno zu" part of the cancellation pair.')
                    :                            undef,
        ],
      ], # end of combobox "Storno"

      'separator',

      combobox => [
        action => [ t8('Workflow') ],
        action => [
          t8('Use As New'),
          submit   => [ '#form', { action => "use_as_new" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create ? t8('You must not change this invoice.')
                    : !$self->record->id ? t8('This invoice has not been posted yet.')
                    :                     undef,
        ],
        action => [
          t8('Further Invoice for Advance Payment'),
          submit   => [ '#form', { action => "further_invoice_for_advance_payment" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create                          ? t8('You must not change this invoice.')
                    : !$self->record->id                         ? t8('This invoice has not been posted yet.')
                    : $has_further_invoice_for_advance_payment   ? t8('This invoice has already a further invoice for advanced payment.')
                    : $has_final_invoice                         ? t8('This invoice has already a final invoice.')
                    : $is_invoice_for_advance_payment_from_order ? t8('This invoice was added from an order. See there.')
                    :                                              undef,
          only_if  => $self->type_data->show_menu('advance_payment'),
        ],
        action => [
          t8('Final Invoice'),
          submit   => [ '#form', { action => "final_invoice" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create                          ? t8('You must not change this invoice.')
                    : !$self->record->id                               ? t8('This invoice has not been posted yet.')
                    : $has_further_invoice_for_advance_payment   ? t8('This invoice has a further invoice for advanced payment.')
                    : $has_final_invoice                         ? t8('This invoice has already a final invoice.')
                    : $is_invoice_for_advance_payment_from_order ? t8('This invoice was added from an order. See there.')
                    :                                              undef,
          only_if  => $self->type_data->show_menu('advance_payment'),
        ],
        action => [
          t8('Credit Note'),
          submit   => [ '#form', { action => "credit_note" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create              ? t8('You must not change this invoice.')
                    : $self->type_data->properties('is_credit_note') ? t8('Credit notes cannot be converted into other credit notes.')
                    : !$self->record->id             ? t8('This invoice has not been posted yet.')
                    : $self->record->storno          ? t8('A canceled invoice cannot be used. Please undo the cancellation first.')
                    :                                  undef,
        ],
        action => [
          t8('Sales Order'),
          submit   => [ '#form', { action => "order" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$self->record->id ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Reclamation'),
          submit   => ['#form', { action => "sales_reclamation" }], # can't call Reclamation directly
          disabled => !$self->record->id ? t8('This invoice has not been posted yet.') : undef,
          only_if  => $self->type_data->show_menu('reclamation') && !$self->record->storno,
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [ t8('Export') ],
        action => [
          ($self->record->id ? t8('Print') : t8('Preview')),
          call     => [ 'kivi.SalesPurchase.show_print_dialog', $self->record->id ? 'print' : 'preview' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create               ? t8('You must not print this invoice.')
                    : !$self->record->id && $locked   ? t8('The billing period has already been locked.')
                    :                                   undef,
        ],
        action => [ t8('Print and Post'),
          call     => [ 'kivi.SalesPurchase.show_print_dialog', 'print_and_post' ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('The invoice is not linked with a sales delivery order. Post anyway?') x !!$warn_unlinked_delivery_order,
          disabled => !$may_edit_create                         ? t8('You must not change this invoice.')
                    : $locked                                   ? t8('The billing period has already been locked.')
                    : $self->record->storno                     ? t8('A canceled invoice cannot be posted.')
                    : ($self->record->id && $change_never)      ? t8('Changing invoices has been disabled in the configuration.')
                    : ($self->record->id && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [ t8('E Mail'),
          call     => [ 'kivi.SalesPurchase.show_email_dialog' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create       ? t8('You must not print this invoice.')
                    : !$self->record->id      ? t8('This invoice has not been posted yet.')
                    : $self->type_data->properties('is_customer') && $self->customer && $self->customer->postal_invoice ? t8('This customer wants a postal invoices.')
                    :                     undef,
        ],
        action => [ t8('Factur-X/ZUGFeRD'),
          submit   => [ '#form', { action => "download_factur_x_xml" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create  ? t8('You must not print this invoice.')
                    : !$self->record->id ? t8('This invoice has not been posted yet.')
                    : !$factur_x_enabled ? t8('Creating Factur-X/ZUGFeRD invoices is not enabled for this customer.')
                    :                      undef,
        ],
      ], # end of combobox "Export"

      combobox => [
        action => [ t8('more') ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $self->record->id * 1, 'glid' ],
          disabled => !$self->record->id ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'follow_up_window' ],
          disabled => !$self->record->id ? t8('This invoice has not been posted yet.') : undef,
        ],
#         action => [  # TODO
#           t8('Drafts'),
#           call     => [ 'kivi.Draft.popup', 'is', 'invoice', $form->{draft_id}, $form->{draft_description} ],
#           disabled => !$may_edit_create  ? t8('You must not change this invoice.')
#                     :  $self->record->id ? t8('This invoice has already been posted.')
#                     : $locked            ? t8('The billing period has already been locked.')
#                     :                     undef,
#         ],
      ], # end of combobox "more"
    );
  }

}

sub get_item_cvpartnumber {
  my ($self, $item) = @_;

  return if !$self->search_cvpartnumber;
  return if !$self->record->customervendor;

  if ($self->cv eq 'vendor') {
    my @mms = grep { $_->make eq $self->record->customervendor->id } @{$item->part->makemodels};
    $item->{cvpartnumber} = $mms[0]->model if scalar @mms;
  } elsif ($self->cv eq 'customer') {
    my @cps = grep { $_->customer_id eq $self->record->customervendor->id } @{$item->part->customerprices};
    $item->{cvpartnumber} = $cps[0]->customer_partnumber if scalar @cps;
  }
}

sub _create_and_send_zip {
  my ($self, $file_names_and_file_paths) = validate_pos(@_,
    { isa => 'SL::Controller::Invoice' },
    {
      type => ARRAYREF,
      callbacks => {
        "has 'file_name' and 'file_path'" => sub {
          foreach my $file_entry (@{$_[0]}) {
            return 0 unless defined $file_entry->{file_name}
                         && defined $file_entry->{file_path};
          }
          return 1;
        }
      }
    });

  my ($fh, $zipfile) = File::Temp::tempfile();
  my $zip = Archive::Zip->new();
  foreach my $file (@{$file_names_and_file_paths}) {
    $zip->addFile($file->{file_path}, $file->{file_name});
  }
  $zip->writeToFileHandle($fh) == Archive::Zip::AZ_OK() or die 'error writing zip file';
  close($fh);

  $self->send_file(
    $zipfile,
    name => t8('pdf_records.zip'), unlink => 1,
    type => 'application/zip',
  );
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

sub render_price_dialog {
  my ($self, $record_item) = @_;

  my $price_source = SL::PriceSource->new(record_item => $record_item, record => $self->record);

  $self->js
    ->run(
      'kivi.io.price_chooser_dialog',
      t8('Available Prices'),
      $self->render('invoice/tabs/_price_sources_dialog', { output => 0 }, price_source => $price_source)
    )
    ->reinit_widgets;

  $self->js->render;
}

# load or create a new record object
#
# And assign changes from the form to this object.
# If the record is loaded from db, check if items are deleted in the form,
# remove them form the object and collect them for removing from db on saving.
# Then create/update items from form (via make_item) and add them.
sub make_record {
  my ($self) = @_;

  die "type needed" unless $::form->{type};
  my $record_type = $::form->{type};
  my $db_class;
  if      (any { $record_type eq $_ } (@{SL::DB::Invoice::TypeData->valid_types})) {
    $db_class = 'SL::DB::Invoice';
  } elsif (any { $record_type eq $_ } (@{SL::DB::PurchaseInvoice::TypeData->valid_types})) {
    $db_class = 'SL::DB::PurchaseInvoice';
  } else {
    die "type has invalid value '$record_type'";
  }

  # add_items adds items to an record with no items for saving, but they cannot
  # be retrieved via items until the record is saved. Adding empty items to new
  # record here solves this problem.
  my $record;
  if ($::form->{id}) {
    $record = $db_class->new(
      id => $::form->{id}
    )->load(
      with => [
        'invoiceitems',
        'invoiceitems.part',
      ]
    );
  } else {
    $record = $db_class->new(
      invoiceitems => [],
      record_type  => $record_type,
      currency_id  => $::instance_conf->get_currency_id(),
    );
    # $record = SL::Model::Record->update_after_new($record)
  }

  my $cv_id_method = $record->type_data->properties('customervendor'). '_id';
  if (!$::form->{id} && $::form->{$cv_id_method}) {
    $record->$cv_id_method($::form->{$cv_id_method});
    $record = SL::Model::Record->update_after_customer_vendor_change($record);
  }

  # don't assign hashes as objects
  my $form_record_items = delete $::form->{record}->{items};

  $record->assign_attributes(%{$::form->{record}});

  # restore form values
  $::form->{record}->{items} = $form_record_items;

  if ($record->type_data->properties('is_customer')) {
    $self->setup_custom_shipto_from_form($record, $::form);
  }

  # remove deleted items
  $self->item_ids_to_delete([]);
  foreach my $idx (reverse 0..$#{$record->items}) {
    my $item = $record->items->[$idx];
    if (none { $item->id == $_->{id} } @{$form_record_items}) {
      splice @{$record->items}, $idx, 1;
      push @{$self->item_ids_to_delete}, $item->id;
    }
  }

  my @items;
  my $pos = 1;
  foreach my $form_attr (@{$form_record_items}) {
    my $item = make_item($record, $form_attr);
    $item->position($pos);
    push @items, $item;
    $pos++;
  }
  $record->add_items(grep {!$_->id} @items);

  return $record;
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

  # add_custom_variables adds cvars to an invoiceitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the record/invoiceitem is
  # saved. Adding empty custom_variables to new invoiceitem here solves this problem.
  $item ||= SL::DB::InvoiceItem->new(custom_variables => []);

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

  my $item = SL::DB::InvoiceItem->new;

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

  my %new_attr;
  $new_attr{description}            = $item->part->description     if ! $item->description;
  $new_attr{qty}                    = 1.0                          if ! $item->qty;
  $new_attr{price_factor_id}        = $item->part->price_factor_id if ! $item->price_factor_id;
  $new_attr{sellprice}              = $price_src->price;
  $new_attr{discount}               = $discount_src->discount;
  $new_attr{active_price_source}    = $price_src;
  $new_attr{active_discount_source} = $discount_src;
  $new_attr{longdescription}        = $item->part->notes           if ! defined $attr->{longdescription};
  $new_attr{project_id}             = $record->globalproject_id;
  $new_attr{lastcost}               = $record->is_sales ? $item->part->lastcost : 0;

  # add_custom_variables adds cvars to an invoiceitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the record/invoiceitem is
  # saved. Adding empty custom_variables to new invoiceitem here solves this problem.
  $new_attr{custom_variables} = [];

  my $texts = get_part_texts($item->part, $record->language_id, description => $new_attr{description}, longdescription => $new_attr{longdescription});

  $item->assign_attributes(%new_attr, %{ $texts });

  return $item;
}

# setup custom shipto from form
#
# The dialog returns form variables starting with 'shipto' and cvars starting
# with 'shiptocvar_'.
# Mark it to be deleted if a shipto from master data is selected
# (i.e. invoice has a shipto).
# Else, update or create a new custom shipto. If the fields are empty, it
# will not be saved on save.
sub setup_custom_shipto_from_form {
  my ($self, $record, $form) = @_;

  if ($record->shipto) {
    $self->is_custom_shipto_to_delete(1);
  } else {
    my $custom_shipto =
       $record->custom_shipto
    || $record->custom_shipto(
         SL::DB::Shipto->new(module => 'CT', custom_variables => [])
       );

    my $shipto_cvars  = {map { my ($key) = m{^shiptocvar_(.+)}; $key => delete $form->{$_}} grep { m{^shiptocvar_} } keys %$form};
    my $shipto_attrs  = {map {                                  $_   => delete $form->{$_}} grep { m{^shipto}      } keys %$form};

    $custom_shipto->assign_attributes(%$shipto_attrs);
    $custom_shipto->cvar_by_name($_)->value($shipto_cvars->{$_}) for keys %$shipto_cvars;
  }
}


sub init_record {
  $_[0]->make_record;
}

sub init_search_cvpartnumber {
  my ($self) = @_;

  my $user_prefs = SL::Helper::UserPreferences::PartPickerSearch->new();
  my $search_cvpartnumber = $self->type_data->properties('is_customer')
   ? !!$user_prefs->get_sales_search_customer_partnumber()
   : !!$user_prefs->get_purchase_search_makemodel();

  return $search_cvpartnumber;
}

sub init_part_picker_classification_ids {
  my ($self)    = @_;

  return [ map { $_->id } @{ SL::DB::Manager::PartClassification->get_all(
    where => $self->type_data->part_classification_query()) } ];
}

sub init_p {
  SL::Presenter->get;
}

sub init_all_price_factors {
  SL::DB::Manager::PriceFactor->get_all;
}

sub init_show_update_button {
  my ($self) = @_;

  !!SL::Helper::UserPreferences::UpdatePositions->new()->get_show_update_button();
}

sub init_cv {
  my ($self) = @_;

  return $self->type_data->properties('customervendor');
}

sub init_type_data {
  my ($self) = @_;
  SL::DB::Helper::TypeDataProxy->new(ref $self->record, $self->record->record_type);
}



1;
