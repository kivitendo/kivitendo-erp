package SL::Controller::Invoice;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Invoice;
use SL::DB::Invoice::TypeData qw(:types);
use SL::DB::PurchaseInvoice;
use SL::DB::PurchaseInvoice::TypeData qw(:types);
use SL::Model::Record;

use Archive::Zip;
use Params::Validate qw(:all);
use List::MoreUtils qw(any);

use SL::DB::File;
use SL::DB::Invoice;
use SL::DB::Employee;

use SL::Webdav;
use SL::File;
use SL::Locale::String qw(t8);
use SL::MoreCommon qw(listify);

use SL::Helper::PrintOptions;

__PACKAGE__->run_before('check_auth');

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(item_ids_to_delete is_custom_shipto_to_delete) ],
  'scalar --get_set_init' => [ qw(
    record valid_types type cv p all_price_factors search_cvpartnumber
    show_update_button part_picker_classification_ids is_final_version
    type_data
  ) ],
);


sub check_auth {
  my ($self) = validate_pos(@_, { isa => 'SL::Controller::Invoice' }, 1);

  return 1 if  $::auth->assert('ar_transactions', 1); # may edit all invoices
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

sub pre_render {
  my ($self) = @_;

  $self->{all_taxzones}               = SL::DB::Manager::TaxZone->get_all_sorted();
  $self->{all_currencies}             = SL::DB::Manager::Currency->get_all_sorted();
  $self->{all_departments}            = SL::DB::Manager::Department->get_all_sorted();
  $self->{all_languages}              = SL::DB::Manager::Language->get_all_sorted( query => [ or => [ obsolete => 0, id => $self->record->language_id ] ] );
  $self->{all_employees}              = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->record->employee_id,
                                                                                              deleted => 0 ] ],
                                                                           sort_by => 'name');
  $self->{all_salesmen}               = SL::DB::Manager::Employee->get_all(where => [ or => [ id => $self->record->salesman_id,
                                                                                              deleted => 0 ] ],
                                                                           sort_by => 'name');
  $self->{all_payment_terms}          = SL::DB::Manager::PaymentTerm->get_all_sorted(where => [ or => [ id => $self->record->payment_id,
                                                                                                        obsolete => 0 ] ]);
  $self->{all_delivery_terms}         = SL::DB::Manager::DeliveryTerm->get_valid($self->record->delivery_term_id);
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

sub setup_action_bar {
  my ($self, %params) = @_;

  # TODO
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
    $record   = $db_class->new(
      id => $::form->{id}
    )->load(
      with => [
        'invoiceitems',
        'invoiceitems.part',
      ]
    );
  } else {
    $record = $db_class->new(
      invoiceitems  => [],
      currency_id => $::instance_conf->get_currency_id(),
    );
    # $record = SL::Model::Record->update_after_new($record)
  }

  # my $cv_id_method = $record->type_data->properties('customervendor'). '_id';
  # if (!$::form->{id} && $::form->{$cv_id_method}) {
  #   $record->$cv_id_method($::form->{$cv_id_method});
  #   $record = SL::Model::Record->update_after_customer_vendor_change($record);
  # }

  # don't assign hashes as objects
  my $form_record_items = delete $::form->{record}->{items};

  $record->assign_attributes(%{$::form->{record}});

  # restore form values
  $::form->{record}->{items} = $form_record_items;

  # if ($record->type_data->properties('is_customer')) {
  #   $self->setup_custom_shipto_from_form($record, $::form);
  # }

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

  # add_custom_variables adds cvars to an orderitem with no cvars for saving, but
  # they cannot be retrieved via custom_variables until the order/orderitem is
  # saved. Adding empty custom_variables to new orderitem here solves this problem.
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

sub init_type_data {
  my ($self) = @_;
  SL::DB::Helper::TypeDataProxy->new(ref $self->record, $self->record->record_type);
}



1;
