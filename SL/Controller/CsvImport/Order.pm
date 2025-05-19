package SL::Controller::CsvImport::Order;


use strict;

use List::MoreUtils qw(any none);

use SL::Helper::Csv;
use SL::Controller::CsvImport::Helper::Consistency;
use SL::DB::Order;
use SL::DB::Order::TypeData qw(:types);
use SL::DB::OrderItem;
use SL::DB::Part;
use SL::DB::PaymentTerm;
use SL::DB::Contact;
use SL::DB::Department;
use SL::DB::PriceFactor;
use SL::DB::Project;
use SL::DB::Shipto;
use SL::DB::TaxZone;
use SL::DB::Unit;
use SL::PriceSource;

use parent qw(SL::Controller::CsvImport::BaseMulti);


use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(settings languages_by all_parts parts_by part_counts_by contacts_by ct_shiptos_by price_factors_by units_by) ],
);


sub init_class {
  my ($self) = @_;
  $self->class(['SL::DB::Order', 'SL::DB::OrderItem']);
}

sub set_profile_defaults {
  my ($self) = @_;

  $self->controller->profile->_set_defaults(
                       order_column    => $::locale->text('Order'),
                       item_column     => $::locale->text('OrderItem'),
                       max_amount_diff => 0.02,
                      );
};


sub init_settings {
  my ($self) = @_;

  return { map { ( $_ => $self->controller->profile->get($_) ) } qw(order_column item_column max_amount_diff) };
}


sub init_cvar_configs_by {
  my ($self) = @_;

  my $item_cvar_configs = SL::DB::Manager::CustomVariableConfig->get_all(where => [ module => 'IC' ]);
  $item_cvar_configs = [grep { $_->has_flag('editable') } @{ $item_cvar_configs }];

  my $ccb;
  $ccb->{class}->{'SL::DB::Order'}          = [];
  $ccb->{class}->{'SL::DB::OrderItem'}      = $item_cvar_configs;
  $ccb->{row_ident}->{$self->_order_column} = [];
  $ccb->{row_ident}->{$self->_item_column}  = $item_cvar_configs;

  return $ccb;
}


sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;

  # SUPER::init_profile sets row_ident to the translated class name
  # overwrite it with the user specified settings
  foreach my $p (@{ $profile }) {
    if ($p->{class} eq 'SL::DB::Order') {
      $p->{row_ident} = $self->_order_column;
    }
    if ($p->{class} eq 'SL::DB::OrderItem') {
      $p->{row_ident} = $self->_item_column;
    }
  }

  foreach my $p (@{ $profile }) {
    my $prof = $p->{profile};
    if ($p->{row_ident} eq $self->_order_column) {
      # no need to handle
      delete @{$prof}{qw(delivery_customer_id delivery_vendor_id proforma amount netamount)};
    }
    if ($p->{row_ident} eq $self->_item_column) {
      # no need to handle
      delete @{$prof}{qw(trans_id)};
    }
  }

  return $profile;
}


sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns($self->_order_column,
                                 { name => 'datatype',                description => $self->_order_column . ' [1]'                            },
                                 { name => 'closed',                  description => $::locale->text('Closed')                                },
                                 { name => 'currency',                description => $::locale->text('Currency')                              },
                                 { name => 'currency_id',             description => $::locale->text('Currency (database ID)')                },
                                 { name => 'cusordnumber',            description => $::locale->text('Customer Order Number')                 },
                                 { name => 'delivered',               description => $::locale->text('Delivered')                             },
                                 { name => 'delivery_term_id',        description => $::locale->text('Delivery terms (database ID)')          },
                                 { name => 'delivery_term',           description => $::locale->text('Delivery terms (name)')                 },
                                 { name => 'employee_id',             description => $::locale->text('Employee (database ID)')                },
                                 { name => 'intnotes',                description => $::locale->text('Internal Notes')                        },
                                 { name => 'marge_percent',           description => $::locale->text('Margepercent')                          },
                                 { name => 'marge_total',             description => $::locale->text('Margetotal')                            },
                                 { name => 'notes',                   description => $::locale->text('Notes')                                 },
                                 { name => 'ordnumber',               description => $::locale->text('Order Number')                          },
                                 { name => 'quonumber',               description => $::locale->text('Quotation Number')                      },
                                 { name => 'record_type',             description => $::locale->text('Order Type') . ' [3]'                   },
                                 { name => 'reqdate',                 description => $::locale->text('Reqdate')                               },
                                 { name => 'salesman_id',             description => $::locale->text('Salesman (database ID)')                },
                                 { name => 'shippingpoint',           description => $::locale->text('Shipping Point')                        },
                                 { name => 'shipvia',                 description => $::locale->text('Ship via')                              },
                                 { name => 'transaction_description', description => $::locale->text('Transaction description')               },
                                 { name => 'transdate',               description => $::locale->text('Order Date')                            },
                                 { name => 'verify_amount',           description => $::locale->text('Amount (for verification)') . ' [2]'    },
                                 { name => 'verify_netamount',        description => $::locale->text('Net amount (for verification)') . ' [2]'},
                                 { name => 'taxincluded',             description => $::locale->text('Tax Included')                          },
                                 { name => 'customer',                description => $::locale->text('Customer (name)')                       },
                                 { name => 'customernumber',          description => $::locale->text('Customer Number')                       },
                                 { name => 'customer_gln',            description => $::locale->text('Customer GLN')                          },
                                 { name => 'customer_id',             description => $::locale->text('Customer (database ID)')                },
                                 { name => 'vendor',                  description => $::locale->text('Vendor (name)')                         },
                                 { name => 'vendornumber',            description => $::locale->text('Vendor Number')                         },
                                 { name => 'vendor_gln',              description => $::locale->text('Vendor GLN')                            },
                                 { name => 'vendor_id',               description => $::locale->text('Vendor (database ID)')                  },
                                 { name => 'language_id',             description => $::locale->text('Language (database ID)')                },
                                 { name => 'language',                description => $::locale->text('Language (name)')                       },
                                 { name => 'payment_id',              description => $::locale->text('Payment terms (database ID)')           },
                                 { name => 'payment',                 description => $::locale->text('Payment terms (name)')                  },
                                 { name => 'taxzone_id',              description => $::locale->text('Tax zone (database ID)')                },
                                 { name => 'taxzone',                 description => $::locale->text('Tax zone (description)')                },
                                 { name => 'cp_id',                   description => $::locale->text('Contact Person (database ID)')          },
                                 { name => 'contact',                 description => $::locale->text('Contact Person (name)')                 },
                                 { name => 'department_id',           description => $::locale->text('Department (database ID)')              },
                                 { name => 'department',              description => $::locale->text('Department (description)')              },
                                 { name => 'globalproject_id',        description => $::locale->text('Document Project (database ID)')        },
                                 { name => 'globalprojectnumber',     description => $::locale->text('Document Project (number)')             },
                                 { name => 'globalproject',           description => $::locale->text('Document Project (description)')        },
                                 { name => 'shipto_id',               description => $::locale->text('Ship to (database ID)')                 },
                                );

  $self->add_cvar_columns_to_displayable_columns($self->_item_column);

  $self->add_displayable_columns($self->_item_column,
                                 { name => 'datatype',        description => $self->_item_column . ' [1]'                  },
                                 { name => 'cusordnumber',    description => $::locale->text('Customer Order Number')      },
                                 { name => 'description',     description => $::locale->text('Description')                },
                                 { name => 'discount',        description => $::locale->text('Discount')                   },
                                 { name => 'ean',             description => $::locale->text('EAN')                        },
                                 { name => 'lastcost',        description => $::locale->text('Lastcost')                   },
                                 { name => 'longdescription', description => $::locale->text('Long Description')           },
                                 { name => 'marge_percent',   description => $::locale->text('Margepercent')               },
                                 { name => 'marge_total',     description => $::locale->text('Margetotal')                 },
                                 { name => 'ordnumber',       description => $::locale->text('Order Number')               },
                                 { name => 'parts_id',        description => $::locale->text('Part (database ID)')         },
                                 { name => 'partnumber',      description => $::locale->text('Part Number')                },
                                 { name => 'position',        description => $::locale->text('position')                   },
                                 { name => 'project_id',      description => $::locale->text('Project (database ID)')      },
                                 { name => 'projectnumber',   description => $::locale->text('Project (number)')           },
                                 { name => 'project',         description => $::locale->text('Project (description)')      },
                                 { name => 'price_factor_id', description => $::locale->text('Price factor (database ID)') },
                                 { name => 'price_factor',    description => $::locale->text('Price factor (name)')        },
                                 { name => 'pricegroup_id',   description => $::locale->text('Price group (database ID)')  },
                                 { name => 'pricegroup',      description => $::locale->text('Price group (name)')         },
                                 { name => 'qty',             description => $::locale->text('Quantity')                   },
                                 { name => 'reqdate',         description => $::locale->text('Reqdate')                    },
                                 { name => 'sellprice',       description => $::locale->text('Sellprice')                  },
                                 { name => 'serialnumber',    description => $::locale->text('Serial No.')                 },
                                 { name => 'subtotal',        description => $::locale->text('Subtotal')                   },
                                 { name => 'unit',            description => $::locale->text('Unit')                       },
                                );
}


sub init_languages_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $self->all_languages } } ) } qw(id description article_code) };
}

sub init_all_parts {
  my ($self) = @_;

  return SL::DB::Manager::Part->get_all;
}

sub init_parts_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $self->all_parts } } ) } qw(id partnumber ean description) };
}

sub init_part_counts_by {
  my ($self) = @_;

  my $part_counts_by;

  $part_counts_by->{ean}->        {$_->ean}++         for @{ $self->all_parts };
  $part_counts_by->{description}->{$_->description}++ for @{ $self->all_parts };

  return $part_counts_by;
}

sub init_contacts_by {
  my ($self) = @_;

  my $all_contacts = SL::DB::Manager::Contact->get_all;

  my $cby;
  # by customer/vendor id  _and_  contact person id
  $cby->{'cp_cv_id+cp_id'}   = { map { ( $_->cp_cv_id . '+' . $_->cp_id   => $_ ) } @{ $all_contacts } };
  # by customer/vendor id  _and_  contact person name
  $cby->{'cp_cv_id+cp_name'} = { map { ( $_->cp_cv_id . '+' . $_->cp_name => $_ ) } @{ $all_contacts } };

  return $cby;
}

sub init_ct_shiptos_by {
  my ($self) = @_;

  my $all_ct_shiptos = SL::DB::Manager::Shipto->get_all(query => [module => 'CT']);

  my $sby;
  # by trans_id  _and_  shipto_id
  $sby->{'trans_id+shipto_id'} = { map { ( $_->trans_id . '+' . $_->shipto_id => $_ ) } @{ $all_ct_shiptos } };

  return $sby;
}

sub init_price_factors_by {
  my ($self) = @_;

  my $all_price_factors = SL::DB::Manager::PriceFactor->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_price_factors } } ) } qw(id description) };
}

sub init_units_by {
  my ($self) = @_;

  my $all_units = SL::DB::Manager::Unit->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_units } } ) } qw(name) };
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  my $order_entry;
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $entry->{info_data}->{datatype} = $entry->{raw_data}->{datatype};

    if ($entry->{raw_data}->{datatype} eq $self->_order_column) {
      $self->handle_order($entry);
      $order_entry = $entry;
    } elsif ($entry->{raw_data}->{datatype} eq $self->_item_column && $entry->{object}->can('part')) {
      $self->handle_item($entry, $order_entry);
    } else {
      $order_entry = undef;
    }

    $self->handle_cvars($entry, sub_module => 'orderitems');

  } continue {
    $i++;
  }

  $self->add_info_columns($self->_order_column,
                          { header => $::locale->text('Data type'), method => 'datatype' });
  $self->add_info_columns($self->_item_column,
                          { header => $::locale->text('Data type'), method => 'datatype' });

  $self->add_info_columns($self->_order_column,
                          { header => $::locale->text('Customer/Vendor'), method => 'vc_name'     },
                          { header => $::locale->text('Record Type'),     method => 'record_type' });

  # Todo: access via ->[0] ok? Better: search first order column and use this
  $self->add_columns($self->_order_column,
                     map { "${_}_id" } grep { exists $self->controller->data->[0]->{raw_data}->{$_} } qw(payment delivery_term language department globalproject taxzone cp currency));
  $self->add_columns($self->_order_column, 'globalproject_id') if exists $self->controller->data->[0]->{raw_data}->{globalprojectnumber};
  $self->add_columns($self->_order_column, 'cp_id')            if exists $self->controller->data->[0]->{raw_data}->{contact};

  $self->add_info_columns($self->_item_column,
                          { header => $::locale->text('Part Number'), method => 'partnumber' });
  # Todo: access via ->[1] ok? Better: search first item column and use this
  $self->add_columns($self->_item_column,
                     map { "${_}_id" } grep { exists $self->controller->data->[1]->{raw_data}->{$_} } qw(project price_factor pricegroup));
  $self->add_columns($self->_item_column, 'project_id') if exists $self->controller->data->[1]->{raw_data}->{projectnumber};

  $self->add_cvar_raw_data_columns();

  $self->add_items_to_order();
  $self->handle_prices_and_taxes();
}

sub handle_order {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $vc_obj;
  if (any { $entry->{raw_data}->{$_} } qw(customer customernumber customer_gln customer_id)) {
    $self->check_vc($entry, 'customer_id');
    $vc_obj = SL::DB::Customer->new(id => $object->customer_id)->load if $object->customer_id;
  } elsif (any { $entry->{raw_data}->{$_} } qw(vendor vendornumber vendor_gln vendor_id)) {
    $self->check_vc($entry, 'vendor_id');
    $vc_obj = SL::DB::Vendor->new(id => $object->vendor_id)->load if $object->vendor_id;
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Customer/vendor missing');
  }

  $self->handle_type($entry);
  $self->check_contact($entry);
  $self->check_language($entry);
  $self->check_payment($entry);
  $self->check_delivery_term($entry);
  $self->check_department($entry);
  $self->check_project($entry, global => 1);
  $self->check_ct_shipto($entry);
  $self->check_taxzone($entry);
  $self->check_currency($entry, take_default => 0);

  if ($vc_obj) {
    # copy from customer if not given
    foreach (qw(payment_id delivery_term_id language_id taxzone_id currency_id)) {
      $object->$_($vc_obj->$_) unless $object->$_;
    }
    $object->intnotes($vc_obj->notes) unless $object->intnotes;
  }

  $self->handle_salesman($entry);
  $self->handle_employee($entry);
}

sub check_language {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not language ID is valid.
  if ($object->language_id && !$self->languages_by->{id}->{ $object->language_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid language');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->language_id && $entry->{raw_data}->{language}) {
    my $language = $self->languages_by->{description}->{  $entry->{raw_data}->{language} }
                || $self->languages_by->{article_code}->{ $entry->{raw_data}->{language} };

    if (!$language) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid language');
      return 0;
    }

    $object->language_id($language->id);
  }

  if ($object->language_id) {
    $entry->{info_data}->{language} = $self->languages_by->{id}->{ $object->language_id }->description;
  }

  return 1;
}

sub handle_type {
  my ($self, $entry) = @_;

  if (!exists $entry->{raw_data}->{record_type}) {
    # if no type is present - set to sales order or purchase
    # order depending on customer/vendor

    $entry->{object}->record_type(
      $entry->{object}->customer_id ? SALES_ORDER_TYPE :
      $entry->{object}->vendor_id   ? PURCHASE_ORDER_TYPE
                                    : undef
    );
  }

  $entry->{info_data}->{record_type} = $::locale->text($entry->{object}->record_type);
}

sub handle_item {
  my ($self, $entry, $order_entry) = @_;

  return unless $order_entry;

  my $object = $entry->{object};

  return unless $self->check_part($entry);

  my $part_obj = SL::DB::Part->new(id => $object->parts_id)->load;

  $self->handle_unit($entry);

  # copy from part if not given
  $object->description($part_obj->description) unless $object->description;
  $object->longdescription($part_obj->notes)   unless $object->longdescription;
  $object->lastcost($part_obj->lastcost)       unless defined $object->lastcost;

  # set to 0 if not given
  $object->ship(0)     unless $object->ship;

  $self->check_project($entry, global => 0);
  $self->check_price_factor($entry);
  $self->check_pricegroup($entry);

  $self->handle_sellprice($entry, $order_entry);
  $self->handle_discount($entry, $order_entry);
}

sub handle_unit {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Set unit from part if not given.
  if (!$object->unit) {
    $object->unit($object->part->unit);
    return 1;
  }

  # Check whether or not unit is valid.
  if ($object->unit && !$self->units_by->{name}->{ $object->unit }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid unit');
    return 0;
  }

  # Check whether unit is convertible to parts unit
  if (none { $object->unit eq $_ } map { $_->name } @{ $object->part->unit_obj->convertible_units }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid unit');
    return 0;
  }

  return 1;
}

sub handle_sellprice {
  my ($self, $entry, $record_entry) = @_;

  my $item   = $entry->{object};
  my $record = $record_entry->{object};

  return if !$record->customervendor;

  # If sellprice is given, set price source to pricegroup if given or to none.
  if (exists $entry->{raw_data}->{sellprice}) {
    my $price_source      = SL::PriceSource->new(record_item => $item, record => $record);
    my $price_source_spec = $item->pricegroup_id ? 'pricegroup' . '/' . $item->pricegroup_id : '';
    my $price             = $price_source->price_from_source($price_source_spec);
    $item->active_price_source($price->source);

  } else {
    # Set sellprice the best price of price source
    my $price_source = SL::PriceSource->new(record_item => $item, record => $record);
    my $price        = $price_source->best_price;
    if ($price) {
      $item->sellprice($price->price);
      $item->active_price_source($price->source);
    } else {
      $item->sellprice(0);
      $item->active_price_source($price_source->price_from_source('')->source);
    }
  }
}

sub handle_discount {
  my ($self, $entry, $record_entry) = @_;

  my $item   = $entry->{object};
  my $record = $record_entry->{object};

  return if !$record->customervendor;

  # If discount is given, set discount source to none.
  if (exists $entry->{raw_data}->{discount}) {
    $item->discount($item->discount/100.0)      if $item->discount;
    $item->discount(0)                      unless $item->discount;

    my $price_source = SL::PriceSource->new(record_item => $item, record => $record);
    my $discount     = $price_source->price_from_source('');
    $item->active_discount_source($discount->source);

  } else {
    # Set discount the best discount of price source
    my $price_source = SL::PriceSource->new(record_item => $item, record => $record);
    my $discount     = $price_source->best_discount;
    if ($discount) {
      $item->discount($discount->discount);
      $item->active_discount_source($discount->source);
    } else {
      $item->discount(0);
      $item->active_discount_source($price_source->discount_from_source('')->source);
    }
  }
}

sub check_part {
  my ($self, $entry) = @_;

  my $object = $entry->{object};
  my $is_ambiguous;

  # Check whether or not part ID is valid.
  if ($object->parts_id && !$self->parts_by->{id}->{ $object->parts_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid part');
    return 0;
  }

  # Map number to ID if given.
  if (!$object->parts_id && $entry->{raw_data}->{partnumber}) {
    my $part = $self->parts_by->{partnumber}->{ $entry->{raw_data}->{partnumber} };
    if (!$part) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid part');
      return 0;
    }

    $object->parts_id($part->id);
  }

  # Map description to ID if given.
  if (!$object->parts_id && $entry->{raw_data}->{description}) {
    my $part = $self->parts_by->{description}->{ $entry->{raw_data}->{description} };
    if (!$part) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid part');
      return 0;
    }

    if ($self->part_counts_by->{description}->{ $entry->{raw_data}->{description} } > 1) {
      $is_ambiguous = 1;
    } else {
      $object->parts_id($part->id);
    }
  }

  # Map ean to ID if given.
  if (!$object->parts_id && $entry->{raw_data}->{ean}) {
    my $part = $self->parts_by->{ean}->{ $entry->{raw_data}->{ean} };
    if (!$part) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid part');
      return 0;
    }

    if ($self->part_counts_by->{ean}->{ $entry->{raw_data}->{ean} } > 1) {
      $is_ambiguous = 1;
    } else {
      $object->parts_id($part->id);
    }
  }

  if ($object->parts_id) {
    $entry->{info_data}->{partnumber} = $self->parts_by->{id}->{ $object->parts_id }->partnumber;
  } else {
    if ($is_ambiguous) {
      push @{ $entry->{errors} }, $::locale->text('Error: Part is ambiguous');
    } else {
      push @{ $entry->{errors} }, $::locale->text('Error: Part not found');
    }
    return 0;
  }

  if ($self->parts_by->{id}->{ $object->parts_id }->obsolete) {
    push @{ $entry->{errors} }, $::locale->text('Error: Part is obsolete');
    return 0;
  }

  return 1;
}

sub check_contact {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $cp_cv_id = $object->customer_id || $object->vendor_id;
  return 0 unless $cp_cv_id;

  # Check whether or not contact ID is valid.
  if ($object->cp_id && !$self->contacts_by->{'cp_cv_id+cp_id'}->{ $cp_cv_id . '+' . $object->cp_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid contact');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->cp_id && $entry->{raw_data}->{contact}) {
    my $cp = $self->contacts_by->{'cp_cv_id+cp_name'}->{ $cp_cv_id . '+' . $entry->{raw_data}->{contact} };
    if (!$cp) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid contact');
      return 0;
    }

    $object->cp_id($cp->cp_id);
  }

  if ($object->cp_id) {
    $entry->{info_data}->{contact} = $self->contacts_by->{'cp_cv_id+cp_id'}->{ $cp_cv_id . '+' . $object->cp_id }->cp_name;
  }

  return 1;
}

sub check_ct_shipto {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $trans_id = $object->customer_id || $object->vendor_id;
  return 0 unless $trans_id;

  # Check whether or not shipto ID is valid.
  if ($object->shipto_id && !$self->ct_shiptos_by->{'trans_id+shipto_id'}->{ $trans_id . '+' . $object->shipto_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid shipto');
    return 0;
  }

  return 1;
}

sub check_price_factor {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not price_factor ID is valid.
  if ($object->price_factor_id && !$self->price_factors_by->{id}->{ $object->price_factor_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid price factor');
    return 0;
  }

  # Map description to ID if given.
  if (!$object->price_factor_id && $entry->{raw_data}->{price_factor}) {
    my $price_factor = $self->price_factors_by->{description}->{ $entry->{raw_data}->{price_factor} };
    if (!$price_factor) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid price factor');
      return 0;
    }

    $object->price_factor_id($price_factor->id);
  }

  return 1;
}

sub add_items_to_order {
  my ($self) = @_;

  # add orderitems to order
  my $order_entry;
  my @orderitems;
  foreach my $entry (@{ $self->controller->data }) {
    # search first/next order
    if ($entry->{raw_data}->{datatype} eq $self->_order_column) {

      # next order entry: add collected orderitems to the previous one
      if (defined $order_entry) {
        $order_entry->{object}->orderitems(@orderitems);
        @orderitems = ();
      }

      $order_entry = $entry;

    } elsif ( defined $order_entry && $entry->{raw_data}->{datatype} eq $self->_item_column ) {
      # collect orderitems to add to order (if they have no errors)
      # ( add_orderitems does not work here if we want to call
      #   calculate_prices_and_taxes afterwards ...
      #   so collect orderitems and add them at once )
      push @orderitems, $entry->{object} if (scalar @{ $entry->{errors} } == 0);
    }
  }
  # add last collected orderitems to last order
  $order_entry->{object}->orderitems(@orderitems) if $order_entry;
}

sub handle_prices_and_taxes() {
  my ($self) = @_;

  # calculate prices and taxes
  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    if ($entry->{raw_data}->{datatype} eq $self->_order_column && $entry->{object}->orderitems) {

      $entry->{object}->calculate_prices_and_taxes;

      $entry->{info_data}->{calc_amount}    = $entry->{object}->amount_as_number;
      $entry->{info_data}->{calc_netamount} = $entry->{object}->netamount_as_number;
    }
  }

  # If amounts are given, show calculated amounts as info and given amounts (verify_xxx).
  # And throw an error if the differences are too big.
  my @to_verify = ( { column      => 'amount',
                      raw_column  => 'verify_amount',
                      info_header => 'Calc. Amount',
                      info_method => 'calc_amount',
                      err_msg     => 'Amounts differ too much',
                    },
                    { column      => 'netamount',
                      raw_column  => 'verify_netamount',
                      info_header => 'Calc. Net amount',
                      info_method => 'calc_netamount',
                      err_msg     => 'Net amounts differ too much',
                    } );

  foreach my $tv (@to_verify) {
    # Todo: access via ->[0] ok? Better: search first order column and use this
    if (exists $self->controller->data->[0]->{raw_data}->{ $tv->{raw_column} }) {
      $self->add_raw_data_columns($self->_order_column, $tv->{raw_column});
      $self->add_info_columns($self->_order_column,
                              { header => $::locale->text($tv->{info_header}), method => $tv->{info_method} });
    }

    # check differences
    foreach my $entry (@{ $self->controller->data }) {
      next if @{ $entry->{errors} };
      if ($entry->{raw_data}->{datatype} eq $self->_order_column) {
        next if !$entry->{raw_data}->{ $tv->{raw_column} };
        my $parsed_value = $::form->parse_amount(\%::myconfig, $entry->{raw_data}->{ $tv->{raw_column} });
        if (abs($entry->{object}->${ \$tv->{column} } - $parsed_value) > $self->settings->{'max_amount_diff'}) {
          push @{ $entry->{errors} }, $::locale->text($tv->{err_msg});
        }
      }
    }
  }

}

sub save_objects {
  my ($self, %params) = @_;

  # Collect orders without errors to save.
  my $entries_to_save = [];
  foreach my $entry (@{ $self->controller->data }) {
    next if $entry->{raw_data}->{datatype} ne $self->_order_column;
    next if @{ $entry->{errors} };

    push @{ $entries_to_save }, $entry;
  }

  $self->SUPER::save_objects(data => $entries_to_save);
}

sub _order_column {
  $_[0]->settings->{'order_column'}
}

sub _item_column {
  $_[0]->settings->{'item_column'}
}

1;
