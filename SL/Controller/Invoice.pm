package SL::Controller::Invoice;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Invoice;
use SL::Helper::Flash qw(flash flash_later);
use SL::HTML::Util;
use SL::Presenter::Tag qw(select_tag hidden_tag div_tag);
use SL::Locale::String qw(t8);
use SL::SessionFile::Random;
use SL::PriceSource;
use SL::File;
use SL::YAML;
use SL::DB::Helper::RecordLink qw(set_record_link_conversions RECORD_ID RECORD_TYPE_REF RECORD_ITEM_ID RECORD_ITEM_TYPE_REF);
use SL::DB::Helper::TypeDataProxy;
use SL::DB::Helper::Record qw(get_object_name_from_type get_class_from_type);
use SL::Model::Record;
use SL::DB::Invoice::TypeData qw(:types);
use SL::DB::Order::TypeData qw(:types);
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::Reclamation::TypeData qw(:types);

use SL::Helper::CreatePDF qw(:all);
use SL::Helper::PrintOptions;
use SL::Helper::ShippedQty;
use SL::Helper::UserPreferences::DisplayPreferences;
use SL::Helper::UserPreferences::PositionsScrollbar;
use SL::Helper::UserPreferences::UpdatePositions;

use SL::Controller::Helper::GetModels;

use List::Util qw(first sum0);
use List::UtilsBy qw(sort_by uniq_by);
use List::MoreUtils qw(uniq any none pairwise first_index);
use File::Spec;
use Sort::Naturally;

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(item_ids_to_delete is_custom_shipto_to_delete) ],
 'scalar --get_set_init' => [ qw(invoice valid_types type cv p all_price_factors
                              search_cvpartnumber show_update_button
                              part_picker_classification_ids
                              type_data) ],
);


# safety
__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('check_auth_for_edit',
                        except => [ qw(edit price_popup load_second_rows) ]);

#
# actions
#

# add a newinvoice
sub action_add {
  my ($self) = @_;

  $self->invoice(SL::Model::Record->update_after_new($self->invoice));

  $self->invoice->gldate($self->invoice->payment_terms ? $self->invoice->payment_terms->calc_date(reference_date => $self->invoice->transdate) : $self->invoice->transdate);

  $self->pre_render();

  if (!$::form->{form_validity_token}) {
    $::form->{form_validity_token} = SL::DB::ValidityToken->create(scope => SL::DB::ValidityToken::SCOPE_SALES_INVOICE_POST())->token;
  }

  $self->render(
    'invoice/form',
    title => $self->type_data->text('add'),
    %{$self->{template_args}}
  );
}



#
# helpers
#

sub init_valid_types {
  $_[0]->type_data->valid_types;
}

sub init_type {
  my ($self) = @_;

  my $type = $self->invoice->record_type;
  if (none { $type eq $_ } @{$self->valid_types}) {
    die "Not a valid type for invoice";
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

sub init_invoice {
  $_[0]->make_invoice;
}

sub init_all_price_factors {
  SL::DB::Manager::PriceFactor->get_all;
}

sub init_part_picker_classification_ids {
  my ($self)    = @_;

  return [ map { $_->id } @{ SL::DB::Manager::PartClassification->get_all(
    where => $self->type_data->part_classification_query()) } ];
}

sub init_type_data {
  my ($self) = @_;
  SL::DB::Helper::TypeDataProxy->new('SL::DB::Invoice', $self->invoice->record_type);
}

sub check_auth {
  my ($self) = @_;
  $::auth->assert($self->type_data->rights('view'));
}

sub check_auth_for_edit {
  my ($self) = @_;
  $::auth->assert($self->type_data->rights('edit'));
}


#
# internal
#


sub pre_render {
  my ($self) = @_;

  $self->{all_taxzones}               = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_currencies}             = SL::DB::Manager::Currency->get_all_sorted();
  $self->{all_departments}            = SL::DB::Manager::Department->get_all_sorted();
  $self->{all_languages}              = SL::DB::Manager::Language->get_all_sorted( query => [ or => [ obsolete => 0, id => $self->invoice->language_id ] ] );
  $self->{all_employees}              = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->invoice->employee_id,
                                                                                              deleted => 0 ] ],
                                                                           sort_by => 'name');
  $self->{all_salesmen}               = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->invoice->salesman_id,
                                                                                              deleted => 0 ] ],
                                                                           sort_by => 'name');
  $self->{all_payment_terms}          = SL::DB::Manager::PaymentTerm->get_all_sorted(where => [ or => [ id => $self->invoice->payment_id,
                                                                                                        obsolete => 0 ] ]);
  $self->{all_delivery_terms}         = SL::DB::Manager::DeliveryTerm->get_valid($self->invoice->delivery_term_id);
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
                no_html            => 0},
  );

  foreach my $item (@{$self->invoice->items}) {
    my $price_source = SL::PriceSource->new(record_item => $item, record => $self->invoice);
    $item->active_price_source(   $price_source->price_from_source(   $item->active_price_source   ));
    $item->active_discount_source($price_source->discount_from_source($item->active_discount_source));
  }


  # ?! TODO: does invoices need stock info?
#   if (any { $self->type eq $_ } (INVOICE_TYPE(), INVOICE_FOR_ADVANCE_PAYMENT_TYPE(), INVOICE_FOR_ADVANCE_PAYMENT_STORNO_TYPE(), FINAL_INVOICE_TYPE(), INVOICE_STORNO_TYPE(), CREDIT_NOTE_TYPE(), CREDIT_NOTE_STORNO_TYPE())) {
#     # Calculate shipped qtys here to prevent calling calculate for every item via the items method.
#     # Do not use write_to_objects to prevent order->delivered to be set, because this should be
#     # the value from db, which can be set manually or is set when linked delivery orders are saved.
#     SL::Helper::ShippedQty->new->calculate($self->record)->write_to(\@{$self->order->items});
#   }

  if ($self->invoice->number && $::instance_conf->get_webdav) {
    my $webdav = SL::Webdav->new(
      type     => $self->type,
      number   => $self->invoice->number,
    );
    my @all_objects = $webdav->get_all_objects;
    @{ $self->{template_args}->{WEBDAV} } = map { { name => $_->filename,
                                                    type => t8('File'),
                                                    link => File::Spec->catfile($_->full_filedescriptor),
                                                } } @all_objects;
  }

#   if (   (any { $self->type eq $_ } (SALES_QUOTATION_TYPE(), SALES_ORDER_INTAKE_TYPE(), SALES_ORDER_TYPE()))
#       && $::instance_conf->get_transport_cost_reminder_article_number_id ) {
#     $self->{template_args}->{transport_cost_reminder_article} = SL::DB::Part->new(id => $::instance_conf->get_transport_cost_reminder_article_number_id)->load;
#   }
  $self->{template_args}->{longdescription_dialog_size_percentage} = SL::Helper::UserPreferences::DisplayPreferences->new()->get_longdescription_dialog_size_percentage();

  $self->get_item_cvpartnumber($_) for @{$self->invoice->items_sorted};

#   $self->{template_args}->{num_phone_notes} = scalar @{ $self->order->phone_notes || [] };

  $::request->{layout}->use_javascript("${_}.js") for qw(kivi.Validator kivi.SalesPurchase kivi.Invoice kivi.File
                                                         calculate_qty follow_up show_history);
  $self->setup_edit_action_bar;
}


sub setup_edit_action_bar {
  my ($self, %params) = @_;

  my $change_never            = $::instance_conf->get_is_changeable == 0;
  my $change_on_same_day_only = $::instance_conf->get_is_changeable == 2 && $self->invoice->gldate->clone->truncate(to => 'day') != DateTime->today;
  my $payments_balanced       = 0; #($::form->{oldtotalpaid} == 0); # TODO: don't rely on form
  my $has_storno              = 0; # $self->invoice->linked_record('storno'); # TODO: linked record?
  my $may_edit_create         = $::auth->assert($self->type_data->rights('edit'), 'may fail');
  my $factur_x_enabled        = $self->invoice->customer && $self->invoice->customer->create_zugferd_invoices_for_this_customer;
  my ($is_linked_bank_transaction, $warn_unlinked_delivery_order);
    if ($::form->{id}
        && SL::DB::Default->get->payments_changeable != 0
        && SL::DB::Manager::BankTransactionAccTrans->find_by(ar_id => $::form->{id})) {

      $is_linked_bank_transaction = 1;
    }
  if ($::instance_conf->get_warn_no_delivery_order_for_invoice && !$self->invoice->id) {
    $warn_unlinked_delivery_order = 1 unless $::form->{convert_from_do_ids};
  }

  my $has_further_invoice_for_advance_payment;
  if ($self->invoice->id && $self->invoice->is_type(INVOICE_FOR_ADVANCE_PAYMENT_TYPE())) {
    my $lr = $self->invoice->linked_records(direction => 'to', to => ['Invoice']);
    $has_further_invoice_for_advance_payment = any {'SL::DB::Invoice' eq ref $_ && "invoice_for_advance_payment" eq $_->type} @$lr;
  }

  my $has_final_invoice;
  if ($self->invoice->id && $self->invoice->is_type(INVOICE_FOR_ADVANCE_PAYMENT_TYPE())) {
    my $lr = $self->invoice->linked_records(direction => 'to', to => ['Invoice']);
    $has_final_invoice = any {'SL::DB::Invoice' eq ref $_ && "final_invoice" eq $_->invoice_type} @$lr;
  }

  my $is_invoice_for_advance_payment_from_order;
  if ($self->invoice->id && $self->invoice->is_type(INVOICE_FOR_ADVANCE_PAYMENT_TYPE())) {
    my $lr = $self->invoice->linked_records(direction => 'from', from => ['Order']);
    $is_invoice_for_advance_payment_from_order = scalar @$lr >= 1;
  }

  my $locked = 0; # TODO: get from... somewhere

  # add readonly state in tmpl_vars
#   $tmpl_var->{readonly} = !$may_edit_create                     ? 1
#                     : $form->{locked}                           ? 1
#                     : $form->{storno}                           ? 1
#                     : ($form->{id} && $change_never)            ? 1
#                     : ($form->{id} && $change_on_same_day_only) ? 1
#                     : $is_linked_bank_transaction               ? 1
#                     : 0;



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
                    : $self->invoice->storno                    ? t8('A canceled invoice cannot be posted.')
                    : $self->invoice->id && $change_never       ? t8('Changing invoices has been disabled in the configuration.')
                    : $self->invoice->id && $change_on_same_day_only ? t8('Invoices can only be changed on the day they are posted.')
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
                    : $self->invoice->storno                    ? t8('A canceled invoice cannot be posted.')
                    : $self->invoice->id && $change_never       ? t8('Changing invoices has been disabled in the configuration.')
                    : $self->invoice->id && $change_on_same_day_only ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [
          t8('Post Payment'),
          submit   => [ '#form', { action => "post_payment" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create           ? t8('You must not change this invoice.')
                    : !$self->invoice->id         ? t8('This invoice has not been posted yet.')
                    : $is_linked_bank_transaction ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                               undef,
            only_if  => $self->invoice->record_type ne "invoice_for_advance_payment",
        ],
        action => [ t8('Mark as paid'),
          submit   => [ '#form', { action => "mark_as_paid" } ],
          confirm  => t8('This will remove the invoice from showing as unpaid even if the unpaid amount does not match the amount. Proceed?'),
          disabled => !$may_edit_create ? t8('You must not change this invoice.')
                    : !$self->invoice->id ? t8('This invoice has not been posted yet.')
                    :                     undef,
          only_if  => ($::instance_conf->get_is_show_mark_as_paid && $self->invoice->record_type ne "invoice_for_advance_payment")
                   || $self->invoice->record_type eq 'final_invoice',
        ],
      ], # end of combobox "Post"

      combobox => [
        action => [ t8('Storno'),
          submit   => [ '#form', { action => "storno" } ],
          confirm  => t8('Do you really want to cancel this invoice?'),
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create   ? t8('You must not change this invoice.')
                    : $locked             ? t8('The billing period has already been locked.')
                    : !$self->invoice->id ? t8('This invoice has not been posted yet.')
                    : $self->invoice->storno ? t8('Cannot storno storno invoice!')
                    : !$payments_balanced ? t8('Cancelling is disallowed. Either undo or balance the current payments until the open amount matches the invoice amount')
                    : undef,
        ],
        action => [ t8('Delete'),
          submit   => [ '#form', { action => "delete" } ],
          confirm  => t8('Do you really want to delete this object?'),
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create        ? t8('You must not change this invoice.')
                    : !$self->invoice->id      ? t8('This invoice has not been posted yet.')
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
                    : !$self->invoice->id ? t8('This invoice has not been posted yet.')
                    :                     undef,
        ],
        action => [
          t8('Further Invoice for Advance Payment'),
          submit   => [ '#form', { action => "further_invoice_for_advance_payment" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create                          ? t8('You must not change this invoice.')
                    : !$self->invoice->id                        ? t8('This invoice has not been posted yet.')
                    : $has_further_invoice_for_advance_payment   ? t8('This invoice has already a further invoice for advanced payment.')
                    : $has_final_invoice                         ? t8('This invoice has already a final invoice.')
                    : $is_invoice_for_advance_payment_from_order ? t8('This invoice was added from an order. See there.')
                    :                                              undef,
          only_if  => $self->invoice->record_type eq "invoice_for_advance_payment",
        ],
        action => [
          t8('Final Invoice'),
          submit   => [ '#form', { action => "final_invoice" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create                          ? t8('You must not change this invoice.')
                    : !$self->invoice->id                        ? t8('This invoice has not been posted yet.')
                    : $has_further_invoice_for_advance_payment   ? t8('This invoice has a further invoice for advanced payment.')
                    : $has_final_invoice                         ? t8('This invoice has already a final invoice.')
                    : $is_invoice_for_advance_payment_from_order ? t8('This invoice was added from an order. See there.')
                    :                                              undef,
          only_if  => $self->invoice->is_type("invoice_for_advance_payment"),
        ],
        action => [
          t8('Credit Note'),
          submit   => [ '#form', { action => "credit_note" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create              ? t8('You must not change this invoice.')
                    : $self->invoice->is_type("credit_note") ? t8('Credit notes cannot be converted into other credit notes.')
                    : !$self->invoice->id                   ? t8('This invoice has not been posted yet.')
                    : $self>invocie->storno                ? t8('A canceled invoice cannot be used. Please undo the cancellation first.')
                    :                                  undef,
        ],
        action => [
          t8('Sales Order'),
          submit   => [ '#form', { action => "order" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$self->invoice->id ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Reclamation'),
          submit   => ['#form', { action => "sales_reclamation" }], # can't call Reclamation directly
          disabled => !$self->invoice->id ? t8('This invoice has not been posted yet.') : undef,
          only_if   => ($self->invoice->is_type('invoice') && !$::form->{storno}),
        ],
      ], # end of combobox "Workflow"

      combobox => [
        action => [ t8('Export') ],
        action => [
          ($self->invoice->id ? t8('Print') : t8('Preview')),
          call     => [ 'kivi.SalesPurchase.show_print_dialog', $self->invoice->id ? 'print' : 'preview' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create               ? t8('You must not print this invoice.')
                    : !$self->invoice->id && $locked ? t8('The billing period has already been locked.')
                    :                                   undef,
        ],
        action => [ t8('Print and Post'),
          call     => [ 'kivi.SalesPurchase.show_print_dialog', 'print_and_post' ],
          checks   => [ 'kivi.validate_form' ],
          confirm  => t8('The invoice is not linked with a sales delivery order. Post anyway?') x !!$warn_unlinked_delivery_order,
          disabled => !$may_edit_create                         ? t8('You must not change this invoice.')
                    : $locked                                   ? t8('The billing period has already been locked.')
                    : $self->invoice->storno                    ? t8('A canceled invoice cannot be posted.')
                    : ($self->invoice->id && $change_never)            ? t8('Changing invoices has been disabled in the configuration.')
                    : ($self->invoice->id && $change_on_same_day_only) ? t8('Invoices can only be changed on the day they are posted.')
                    : $is_linked_bank_transaction               ? t8('This transaction is linked with a bank transaction. Please undo and redo the bank transaction booking if needed.')
                    :                                             undef,
        ],
        action => [ t8('E Mail'),
          call     => [ 'kivi.SalesPurchase.show_email_dialog' ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create       ? t8('You must not print this invoice.')
                    : !$self->invoice->id     ? t8('This invoice has not been posted yet.')
                    : $self->invoice->customer->postal_invoice ? t8('This customer wants a postal invoices.')
                    :                     undef,
        ],
        action => [ t8('Factur-X/ZUGFeRD'),
          submit   => [ '#form', { action => "download_factur_x_xml" } ],
          checks   => [ 'kivi.validate_form' ],
          disabled => !$may_edit_create   ? t8('You must not print this invoice.')
                    : !$self->invoice->id ? t8('This invoice has not been posted yet.')
                    : !$factur_x_enabled  ? t8('Creating Factur-X/ZUGFeRD invoices is not enabled for this customer.')
                    :                      undef,
        ],
      ], # end of combobox "Export"

      combobox => [
        action => [ t8('more') ],
        action => [
          t8('History'),
          call     => [ 'set_history_window', $self->invoice->id * 1, 'glid' ],
          disabled => !$self->invoice->id ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Follow-Up'),
          call     => [ 'follow_up_window' ],
          disabled => !$self->invoice->id ? t8('This invoice has not been posted yet.') : undef,
        ],
        action => [
          t8('Drafts'),
          call     => [ 'kivi.Draft.popup', 'is', 'invoice', $::form->{draft_id}, $::form->{draft_description} ],
          disabled => !$may_edit_create   ? t8('You must not change this invoice.')
                    : $self->invoice->id  ? t8('This invoice has already been posted.')
                    : $locked             ? t8('The billing period has already been locked.')
                    :                     undef,
        ],
      ], # end of combobox "more"
    );
  }
}

# load or create a new order object
#
# And assign changes from the form to this object.
# If the order is loaded from db, check if items are deleted in the form,
# remove them form the object and collect them for removing from db on saving.
# Then create/update items from form (via make_item) and add them.
sub make_invoice {
  my ($self) = @_;

  # add_items adds items to an order with no items for saving, but they cannot
  # be retrieved via items until the order is saved. Adding empty items to new
  # order here solves this problem.
  my $invoice;
  $invoice   = SL::DB::Invoice->new(id => $::form->{id})->load(with => [ 'invoiceitems', 'invoiceitems.part' ]) if $::form->{id};
  $invoice ||= SL::DB::Invoice->new(invoiceitems  => [],
                                record_type => $::form->{type},
                                currency_id => $::instance_conf->get_currency_id(),);

  my $cv_id_method = $invoice->type_data->properties('customervendor'). '_id';
  if (!$::form->{id} && $::form->{$cv_id_method}) {
    $invoice->$cv_id_method($::form->{$cv_id_method});
    $invoice = SL::Model::Record->update_after_customer_vendor_change($invoice);
  }

  my $form_invoiceitems                = delete $::form->{invoice}->{invoiceitems};

  $invoice->assign_attributes(%{$::form->{invoice}});

  $self->setup_custom_shipto_from_form($invoice, $::form);

  # remove deleted items
  $self->item_ids_to_delete([]);
  foreach my $idx (reverse 0..$#{$invoice->invoiceitems}) {
    my $item = $invoice->invoiceitems->[$idx];
    if (none { $item->id == $_->{id} } @{$form_invoiceitems}) {
      splice @{$invoice->invoiceitems}, $idx, 1;
      push @{$self->item_ids_to_delete}, $item->id;
    }
  }

  my @items;
  my $pos = 1;
  foreach my $form_attr (@{$form_invoiceitems}) {
    my $item = make_item($invoice, $form_attr);
    $item->position($pos);
    push @items, $item;
    $pos++;
  }
  $invoice->add_items(grep {!$_->id} @items);

  return $invoice;
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

# setup custom shipto from form
#
# The dialog returns form variables starting with 'shipto' and cvars starting
# with 'shiptocvar_'.
# Mark it to be deleted if a shipto from master data is selected
# (i.e. order has a shipto).
# Else, update or create a new custom shipto. If the fields are empty, it
# will not be saved on save.
sub setup_custom_shipto_from_form {
  my ($self, $record, $form) = @_;

  if ($record->shipto) {
    $self->is_custom_shipto_to_delete(1);
  } else {
    my $custom_shipto = $record->custom_shipto || $record->custom_shipto(SL::DB::Shipto->new(module => 'AR', custom_variables => []));

    my $shipto_cvars  = {map { my ($key) = m{^shiptocvar_(.+)}; $key => delete $form->{$_}} grep { m{^shiptocvar_} } keys %$form};
    my $shipto_attrs  = {map {                                  $_   => delete $form->{$_}} grep { m{^shipto}      } keys %$form};

    $custom_shipto->assign_attributes(%$shipto_attrs);
    $custom_shipto->cvar_by_name($_)->value($shipto_cvars->{$_}) for keys %$shipto_cvars;
  }
}

1;
