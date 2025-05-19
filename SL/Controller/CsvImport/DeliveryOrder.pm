package SL::Controller::CsvImport::DeliveryOrder;


use strict;

use List::Util qw(first);
use List::MoreUtils qw(any none uniq);
use DateTime;

use SL::Controller::CsvImport::Helper::Consistency;
use SL::DB::DeliveryOrder;
use SL::DB::DeliveryOrder::TypeData qw(:types);
use SL::DB::DeliveryOrderItem;
use SL::DB::DeliveryOrderItemsStock;
use SL::DB::Part;
use SL::DB::PaymentTerm;
use SL::DB::Contact;
use SL::DB::PriceFactor;
use SL::DB::Shipto;
use SL::DB::Unit;
use SL::DB::Inventory;
use SL::DB::TransferType;
use SL::DBUtils;
use SL::Helper::ShippedQty;
use SL::PriceSource;
use SL::TransNumber;
use SL::Util qw(trim);

use parent qw(SL::Controller::CsvImport::BaseMulti);


use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(settings languages_by all_parts parts_by part_counts_by
                                 contacts_by ct_shiptos_by
                                 price_factors_by units_by
                                 warehouses_by bins_by transfer_types_by) ],
);


sub init_class {
  my ($self) = @_;
  $self->class(['SL::DB::DeliveryOrder', 'SL::DB::DeliveryOrderItem', 'SL::DB::DeliveryOrderItemsStock']);
}

sub set_profile_defaults {
  my ($self) = @_;

  $self->controller->profile->_set_defaults(
    order_column         => $::locale->text('DeliveryOrder'),
    item_column          => $::locale->text('OrderItem'),
    stock_column         => $::locale->text('StockInfo'),
    ignore_faulty_positions => 0,
  );
};

sub init_settings {
  my ($self) = @_;

  return { map { ( $_ => $self->controller->profile->get($_) ) } qw(order_column item_column stock_column ignore_faulty_positions) };
}

sub init_cvar_configs_by {
  my ($self) = @_;

  my $item_cvar_configs = SL::DB::Manager::CustomVariableConfig->get_all(where => [ module => 'IC' ]);
  $item_cvar_configs = [grep { $_->has_flag('editable') } @{ $item_cvar_configs }];

  my $ccb;
  $ccb->{class}->{$self->class->[0]}        = [];
  $ccb->{class}->{$self->class->[1]}        = $item_cvar_configs;
  $ccb->{class}->{$self->class->[2]}        = [];
  $ccb->{row_ident}->{$self->_order_column} = [];
  $ccb->{row_ident}->{$self->_item_column}  = $item_cvar_configs;
  $ccb->{row_ident}->{$self->_stock_column} = [];

  return $ccb;
}

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;

  # SUPER::init_profile sets row_ident to the translated class name
  # overwrite it with the user specified settings
  foreach my $p (@{ $profile }) {
    $p->{row_ident} = $self->_order_column if $p->{class} eq $self->class->[0];
    $p->{row_ident} = $self->_item_column  if $p->{class} eq $self->class->[1];
    $p->{row_ident} = $self->_stock_column if $p->{class} eq $self->class->[2];
  }

  foreach my $p (@{ $profile }) {
    my $prof = $p->{profile};
    if ($p->{row_ident} eq $self->_order_column) {
      # no need to handle
      delete @{$prof}{qw(oreqnumber)};
    }
    if ($p->{row_ident} eq $self->_item_column) {
      # no need to handle
      delete @{$prof}{qw(delivery_order_id)};
    }
    if ($p->{row_ident} eq $self->_stock_column) {
      # no need to handle
      delete @{$prof}{qw(delivery_order_item_id)};
      delete @{$prof}{qw(bestbefore)} if !$::instance_conf->get_show_bestbefore;
    }
  }

  return $profile;
}

sub init_existing_objects {
  my ($self) = @_;

  # only use objects of main class (the first one)
  eval "require " . $self->class->[0];
  $self->existing_objects($self->manager_class->[0]->get_all);
}

sub get_duplicate_check_fields {
  return {
    donumber => {
      label     => $::locale->text('Delivery Order Number'),
      default   => 1,
      std_check => 1,
      maker     => sub {
        my ($object, $worker) = @_;
        return if ref $object ne $worker->class->[0];
        return $object->donumber;
      },
    },
  };
}

sub check_std_duplicates {
  my $self = shift;

  my $duplicates = {};

  my $all_fields = $self->get_duplicate_check_fields();

  foreach my $key (keys(%{ $all_fields })) {
    if ( $self->controller->profile->get('duplicates_'. $key) && (!exists($all_fields->{$key}->{std_check}) || $all_fields->{$key}->{std_check} )  ) {
      $duplicates->{$key} = {};
    }
  }

  my @duplicates_keys = keys(%{ $duplicates });

  if ( !scalar(@duplicates_keys) ) {
    return;
  }

  if ( $self->controller->profile->get('duplicates') eq 'check_db' ) {
    foreach my $object (@{ $self->existing_objects }) {
      foreach my $key (@duplicates_keys) {
        my $value = exists($all_fields->{$key}->{maker}) ? $all_fields->{$key}->{maker}->($object, $self) : $object->$key;
        $duplicates->{$key}->{$value} = 'db';
      }
    }
  }

  # only check order rows
  foreach my $entry (@{ $self->controller->data }) {
    if ($entry->{raw_data}->{datatype} ne $self->_order_column) {
      next;
    }
    if ( @{ $entry->{errors} } ) {
      next;
    }

    my $object = $entry->{object};

    foreach my $key (@duplicates_keys) {
      my $value = exists($all_fields->{$key}->{maker}) ? $all_fields->{$key}->{maker}->($object, $self) : $object->$key;

      if ( exists($duplicates->{$key}->{$value}) ) {
        push(@{ $entry->{errors} }, $duplicates->{$key}->{$value} eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file'));
        last;
      } else {
        $duplicates->{$key}->{$value} = 'csv';
      }

    }
  }
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_cvar_columns_to_displayable_columns($self->_order_column);

  $self->add_displayable_columns($self->_order_column,
                                 { name => 'datatype',                description => $self->_order_column . ' [1]'                            },
                                 { name => 'closed',                  description => $::locale->text('Closed')                                },
                                 { name => 'contact',                 description => $::locale->text('Contact Person (name)')                 },
                                 { name => 'cp_id',                   description => $::locale->text('Contact Person (database ID)')          },
                                 { name => 'currency',                description => $::locale->text('Currency')                              },
                                 { name => 'currency_id',             description => $::locale->text('Currency (database ID)')                },
                                 { name => 'customer',                description => $::locale->text('Customer (name)')                       },
                                 { name => 'customernumber',          description => $::locale->text('Customer Number')                       },
                                 { name => 'customer_id',             description => $::locale->text('Customer (database ID)')                },
                                 { name => 'cusordnumber',            description => $::locale->text('Customer Order Number')                 },
                                 { name => 'delivered',               description => $::locale->text('Delivered')                             },
                                 { name => 'delivery_term',           description => $::locale->text('Delivery terms (name)')                 },
                                 { name => 'delivery_term_id',        description => $::locale->text('Delivery terms (database ID)')          },
                                 { name => 'department_id',           description => $::locale->text('Department (database ID)')              },
                                 { name => 'department',              description => $::locale->text('Department (description)')              },
                                 { name => 'donumber',                description => $::locale->text('Delivery Order Number')                 },
                                 { name => 'employee_id',             description => $::locale->text('Employee (database ID)')                },
                                 { name => 'globalproject',           description => $::locale->text('Document Project (description)')        },
                                 { name => 'globalprojectnumber',     description => $::locale->text('Document Project (number)')             },
                                 { name => 'globalproject_id',        description => $::locale->text('Document Project (database ID)')        },
                                 { name => 'intnotes',                description => $::locale->text('Internal Notes')                        },
                                 { name => 'language',                description => $::locale->text('Language (name)')                       },
                                 { name => 'language_id',             description => $::locale->text('Language (database ID)')                },
                                 { name => 'notes',                   description => $::locale->text('Notes')                                 },
                                 { name => 'record_type',             description => $::locale->text('Delivery Order Type') . ' [2]'          },
                                 { name => 'ordnumber',               description => $::locale->text('Order Number')                          },
                                 { name => 'payment',                 description => $::locale->text('Payment terms (name)')                  },
                                 { name => 'payment_id',              description => $::locale->text('Payment terms (database ID)')           },
                                 { name => 'reqdate',                 description => $::locale->text('Reqdate')                               },
                                 { name => 'salesman_id',             description => $::locale->text('Salesman (database ID)')                },
                                 { name => 'shippingpoint',           description => $::locale->text('Shipping Point')                        },
                                 { name => 'shipvia',                 description => $::locale->text('Ship via')                              },
                                 { name => 'shipto_id',               description => $::locale->text('Ship to (database ID)')                 },
                                 { name => 'taxincluded',             description => $::locale->text('Tax Included')                          },
                                 { name => 'taxzone',                 description => $::locale->text('Tax zone (description)')                },
                                 { name => 'taxzone_id',              description => $::locale->text('Tax zone (database ID)')                },
                                 { name => 'transaction_description', description => $::locale->text('Transaction description')               },
                                 { name => 'transdate',               description => $::locale->text('Order Date')                            },
                                 { name => 'vendor',                  description => $::locale->text('Vendor (name)')                         },
                                 { name => 'vendornumber',            description => $::locale->text('Vendor Number')                         },
                                 { name => 'vendor_id',               description => $::locale->text('Vendor (database ID)')                  },
                                );

  $self->add_cvar_columns_to_displayable_columns($self->_item_column);

  $self->add_displayable_columns($self->_item_column,
                                 { name => 'datatype',        description => $self->_item_column . ' [1]'                  },
                                 { name => 'cusordnumber',    description => $::locale->text('Customer Order Number')      },
                                 { name => 'description',     description => $::locale->text('Description')                },
                                 { name => 'discount',        description => $::locale->text('Discount')                   },
                                 { name => 'lastcost',        description => $::locale->text('Lastcost')                   },
                                 { name => 'longdescription', description => $::locale->text('Long Description')           },
                                 { name => 'ordnumber',       description => $::locale->text('Order Number')               },
                                 { name => 'partnumber',      description => $::locale->text('Part Number')                },
                                 { name => 'parts_id',        description => $::locale->text('Part (database ID)')         },
                                 { name => 'position',        description => $::locale->text('position')                   },
                                 { name => 'price_factor',    description => $::locale->text('Price factor (name)')        },
                                 { name => 'price_factor_id', description => $::locale->text('Price factor (database ID)') },
                                 { name => 'pricegroup',      description => $::locale->text('Price group (name)')         },
                                 { name => 'pricegroup_id',   description => $::locale->text('Price group (database ID)')  },
                                 { name => 'project',         description => $::locale->text('Project (description)')      },
                                 { name => 'projectnumber',   description => $::locale->text('Project (number)')           },
                                 { name => 'project_id',      description => $::locale->text('Project (database ID)')      },
                                 { name => 'qty',             description => $::locale->text('Quantity')                   },
                                 { name => 'reqdate',         description => $::locale->text('Reqdate')                    },
                                 { name => 'sellprice',       description => $::locale->text('Sellprice')                  },
                                 { name => 'serialnumber',    description => $::locale->text('Serial No.')                 },
                                 { name => 'transdate',       description => $::locale->text('Order Date')                 },
                                 { name => 'unit',            description => $::locale->text('Unit')                       },
                                );

  $self->add_cvar_columns_to_displayable_columns($self->_stock_column);

  $self->add_displayable_columns($self->_stock_column,
                                 { name => 'datatype',     description => $self->_stock_column . ' [1]'              },
                                 { name => 'warehouse',    description => $::locale->text('Warehouse')               },
                                 { name => 'warehouse_id', description => $::locale->text('Warehouse (database ID)') },
                                 { name => 'bin',          description => $::locale->text('Bin')                     },
                                 { name => 'bin_id',       description => $::locale->text('Bin (database ID)')       },
                                 { name => 'chargenumber', description => $::locale->text('Charge number')           },
                                 { name => 'qty',          description => $::locale->text('Quantity')                },
                                 { name => 'unit',         description => $::locale->text('Unit')                    },
                                );
  if ($::instance_conf->get_show_bestbefore) {
    $self->add_displayable_columns($self->_stock_column,
                                   { name => 'bestbefore', description => $::locale->text('Best Before') });
  }
}


sub init_languages_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $self->all_languages } } ) } qw(id description article_code) };
}

sub init_all_parts {
  my ($self) = @_;

  return SL::DB::Manager::Part->get_all(where => [or => [ obsolete => 0, obsolete => undef ]]);
}

sub init_parts_by {
  my ($self) = @_;

  return { map { my $col = $_; ( $col => { map { ( trim($_->$col) => $_ ) } @{ $self->all_parts } } ) } qw(id partnumber ean description) };
}

sub init_part_counts_by {
  my ($self) = @_;

  my $part_counts_by;

  $part_counts_by->{ean}->        {trim($_->ean)}++         for @{ $self->all_parts };
  $part_counts_by->{description}->{trim($_->description)}++ for @{ $self->all_parts };

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

sub init_warehouses_by {
  my ($self) = @_;

  my $all_warehouses = SL::DB::Manager::Warehouse->get_all(query => [ or => [ invalid => 0, invalid => undef ]]);
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_warehouses } } ) } qw(id description) };
}

sub init_bins_by {
  my ($self) = @_;

  my $all_bins = SL::DB::Manager::Bin->get_all();
  my $bins_by;
  $bins_by->{_wh_id_and_id_ident()}          = { map { ( _wh_id_and_id_maker($_->warehouse_id, $_->id)                   => $_ ) } @{ $all_bins } };
  $bins_by->{_wh_id_and_description_ident()} = { map { ( _wh_id_and_description_maker($_->warehouse_id, $_->description) => $_ ) } @{ $all_bins } };

  return $bins_by;
}

sub init_transfer_types_by {
  my ($self) = @_;

  my $all_transfer_types = SL::DB::Manager::TransferType->get_all();
  my $transfer_types_by;
  $transfer_types_by->{_transfer_type_dir_and_description_ident()} = {
    map { ( _transfer_type_dir_and_description_maker($_->direction, $_->description) => $_ ) } @{ $all_transfer_types }
  };

  return $transfer_types_by;
}

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  my $order_entry;
  my $item_entry;
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $entry->{info_data}->{datatype} = $entry->{raw_data}->{datatype};

    if ($entry->{raw_data}->{datatype} eq $self->_order_column) {
      $self->handle_order($entry);
      $order_entry = $entry;
    } elsif ($entry->{raw_data}->{datatype} eq $self->_item_column && $entry->{object}->can('part')) {
      $self->handle_item($entry, $order_entry);
      $item_entry = $entry;
    } elsif ($entry->{raw_data}->{datatype} eq $self->_stock_column) {
      $self->handle_stock($entry, $item_entry, $order_entry);
      push @{ $order_entry->{errors} }, $::locale->text('Error: Stock problem') if scalar(@{$entry->{errors}}) > 0;
    } else {
      $order_entry = undef;
      $item_entry  = undef;
    }

    $self->handle_cvars($entry, sub_module => 'delivery_order_items');

  } continue {
    $i++;
  }

  $self->add_info_columns($self->_order_column,
                          { header => $::locale->text('Data type'), method => 'datatype' });
  $self->add_info_columns($self->_item_column,
                          { header => $::locale->text('Data type'), method => 'datatype' });
  $self->add_info_columns($self->_stock_column,
                          { header => $::locale->text('Data type'), method => 'datatype' });

  $self->add_info_columns($self->_order_column,
                          { header => $::locale->text('Customer/Vendor'), method => 'vc_name' },
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


  # Check overall qtys for sales delivery orders, because they are
  # stocked out in the end and a stock underrun can occure.
  # Todo: let it work even with bestbefore turned off.
  $order_entry = undef;
  $item_entry  = undef;
  my %wanted_qtys_by_part_wh_bin_charge_bestbefore;
  my %stock_entries_with_part_wh_bin_charge_bestbefore;
  my %order_entries_with_part_wh_bin_charge_bestbefore;
  foreach my $entry (@{ $self->controller->data }) {
    if ($entry->{raw_data}->{datatype} eq $self->_order_column) {
      if (scalar(@{ $entry->{errors} }) || !$entry->{object}->is_sales) {
        $order_entry = undef;
        $item_entry  = undef;
        next;
      }
      $order_entry = $entry;

    } elsif (defined $order_entry && $entry->{raw_data}->{datatype} eq $self->_item_column) {
      if (scalar(@{ $entry->{errors} })) {
        $item_entry = undef;
        next;
      }
      $item_entry = $entry;

    } elsif (defined $item_entry && $entry->{raw_data}->{datatype} eq $self->_stock_column) {
      my $object = $entry->{object};
      my $key = join('+',
                     $item_entry->{object}->parts_id,
                     $object->warehouse_id,
                     $object->bin_id,
                     $object->chargenumber,
                     $object->bestbefore);
      $wanted_qtys_by_part_wh_bin_charge_bestbefore{$key} += $object->qty;
      push @{$order_entries_with_part_wh_bin_charge_bestbefore{$key}}, $order_entry;
      push @{$stock_entries_with_part_wh_bin_charge_bestbefore{$key}}, $entry;
    }
  }

  foreach my $key (keys %wanted_qtys_by_part_wh_bin_charge_bestbefore) {
    my ($parts_id, $wh_id, $bin_id, $chargenumber, $bestbefore) = split '\+', $key;
    my $qty = $self->get_stocked_qty($parts_id, $wh_id, $bin_id, $chargenumber, $bestbefore);
    if ($wanted_qtys_by_part_wh_bin_charge_bestbefore{$key} > $qty) {

      foreach my $stock_entry (@{ $stock_entries_with_part_wh_bin_charge_bestbefore{$key} }) {
        push @{ $stock_entry->{errors} }, $::locale->text('Error: Stocking out would result in stock underrun');
      }

      foreach my $order_entry (uniq @{ $order_entries_with_part_wh_bin_charge_bestbefore{$key} }) {
        my $part            = $self->parts_by->{id}->{$parts_id}->displayable_name;
        my $stock           = $self->bins_by->{_wh_id_and_id_ident()}->{_wh_id_and_id_maker($wh_id, $bin_id)}->full_description;
        my $bestbefore_obj  = $::locale->parse_date_to_object($bestbefore, dateformat=>'yyyy-mm-dd');
        my $bestbefore_text = $bestbefore_obj? $::locale->parse_date_to_object($bestbefore_obj, dateformat=>'yyyy-mm-dd')->to_kivitendo: '-';
        my $wanted_qty      = $wanted_qtys_by_part_wh_bin_charge_bestbefore{$key};
        my $details_text    = sprintf('%s (%s / %s / %s): %s > %s',
                                      $part,
                                      $stock,
                                      $chargenumber,
                                      $bestbefore_text,
                                      $::form->format_amount(\%::myconfig, $wanted_qty,  2),
                                      $::form->format_amount(\%::myconfig, $qty, 2));
        push @{ $order_entry->{errors} }, $::locale->text('Error: Stocking out would result in stock underrun: #1', $details_text);
      }

    }
  }

}

sub handle_order {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  $object->orderitems([]);

  $self->handle_order_sources($entry);
  my $first_source_order = $object->{source_orders}->[0];

  my $vc_obj;
  if (any { $entry->{raw_data}->{$_} } qw(customer customernumber customer_id)) {
    $self->check_vc($entry, 'customer_id');
    $vc_obj = SL::DB::Customer->new(id => $object->customer_id)->load if $object->customer_id;

  } elsif (any { $entry->{raw_data}->{$_} } qw(vendor vendornumber vendor_id)) {
    $self->check_vc($entry, 'vendor_id');
    $vc_obj = SL::DB::Vendor->new(id => $object->vendor_id)->load if $object->vendor_id;

  } else {
    # customer / vendor from (first) source order if not given
    if ($first_source_order) {
      if ($first_source_order->customer) {
        $vc_obj = $first_source_order->customer;
        $object->customer($first_source_order->customer);
      } elsif ($first_source_order->vendor) {
        $vc_obj = $first_source_order->vendor;
        $object->vendor($first_source_order->vendor);
      }
    }
  }

  if (!$vc_obj) {
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

  # copy from (first) source order if not given
  # if no source order, then copy some values from customer/vendor
  if ($first_source_order) {
    foreach (qw(cusordnumber notes intnotes shippingpoint shipvia
                transaction_description currency_id delivery_term_id
                department_id language_id payment_id globalproject_id shipto_id
                taxzone_id)) {
      $object->$_($first_source_order->$_) unless $object->$_;
    }
  } elsif ($vc_obj) {
    foreach (qw(currency_id delivery_term_id language_id payment_id taxzone_id)) {
      $object->$_($vc_obj->$_) unless $object->$_;
    }
    $object->intnotes($vc_obj->notes) unless $object->intnotes;
  }

  $self->handle_salesman($entry);
  $self->handle_employee($entry);
}

sub handle_item {
  my ($self, $entry, $order_entry) = @_;

  return unless $order_entry;

  my $order_obj = $order_entry->{object};
  my $object    = $entry->{object};
  $object->delivery_order_stock_entries([]);

  if (!$self->check_part($entry)) {
    if ($self->controller->profile->get('ignore_faulty_positions')) {
      push @{ $order_entry->{information} }, $::locale->text('Warning: Faulty position ignored');
    } else {
      push @{ $order_entry->{errors} }, $::locale->text('Error: Faulty position in this delivery order');
    }
    return;
  }

  $order_obj->add_items($object);

  my $part_obj = SL::DB::Part->new(id => $object->parts_id)->load;

  $self->handle_item_source($entry, $order_entry);
  $object->position($object->{source_item}->position) if $object->{source_item};

  $self->handle_unit($entry);

  # copy from part if not given
  $object->description($part_obj->description) unless $object->description;
  $object->longdescription($part_obj->notes)   unless $object->longdescription;
  $object->lastcost($part_obj->lastcost)       unless defined $object->lastcost;

  $self->check_project($entry, global => 0);
  $self->check_price_factor($entry);
  $self->check_pricegroup($entry);

  $self->handle_sellprice($entry, $order_entry);
  $self->handle_discount($entry, $order_entry);

  push @{ $order_entry->{errors} }, $::locale->text('Error: Faulty position in this delivery order') if scalar(@{$entry->{errors}}) > 0;
}

sub handle_stock {
  my ($self, $entry, $item_entry, $order_entry) = @_;

  return unless $item_entry;

  my $item_obj  = $item_entry->{object};
  return unless $item_obj->part;

  my $order_obj = $order_entry->{object};
  my $object    = $entry->{object};

  $item_obj->add_delivery_order_stock_entries($object);

  $self->check_warehouse($entry);
  $self->check_bin($entry);

  $self->handle_unit($entry, $item_obj->part);

  # check if enough is stocked
  # not necessary, because overall stock underrun is checked later
  # if ($order_obj->is_sales) {
  #   my $stocked_qty = $self->get_stocked_qty($item_obj->parts_id,
  #                                            $object->warehouse_id,
  #                                            $object->bin_id,
  #                                            $object->chargenumber,
  #                                            $object->bestbefore);
  #   if ($stocked_qty < $object->qty) {
  #     push @{ $entry->{errors} }, $::locale->text('Error: Not enough parts in stock');
  #   }
  # }

  my ($stock_info_entry, $part) = @_;

  # Todo: option: should stock?
  if (1) {
    my $tt_key = $order_obj->is_sales
               ? _transfer_type_dir_and_description_maker('out', 'shipped')
               : _transfer_type_dir_and_description_maker('in', 'stock');
    my $trans_type_id = $self->transfer_types_by->{_transfer_type_dir_and_description_ident()}{$tt_key}->id;

    my $qty = $order_obj->is_sales ? -1*($object->qty) : $object->qty;
    my $inventory = SL::DB::Inventory->new(
      parts_id      => $item_obj->parts_id,
      warehouse_id  => $object->warehouse_id,
      bin_id        => $object->bin_id,
      PURCHASE_DELIVERY_ORDER_TYPE() => $trans_type_id,
      qty           => $qty,
      chargenumber  => $object->chargenumber,
      employee_id   => $order_obj->employee_id,
      shippingdate  => ($order_obj->reqdate || DateTime->today_local),
      comment       => $order_obj->transaction_description,
      project_id    => ($order_obj->globalproject_id || $item_obj->project_id),
    );
    $inventory->bestbefore($object->bestbefore) if $::instance_conf->get_show_bestbefore;
    $object->{inventory_obj} = $inventory;
    $order_obj->delivered(1);
  }
}

sub handle_type {
  my ($self, $entry) = @_;

  if (!exists $entry->{raw_data}->{record_type}) {
    # if no type is present - set to sales delivery order or purchase delivery
    # order depending on is_sales or customer/vendor

    $entry->{object}->record_type(
      $entry->{object}->customer_id  ? SALES_DELIVERY_ORDER_TYPE :
      $entry->{object}->vendor_id    ? PURCHASE_DELIVERY_ORDER_TYPE :
      $entry->{raw_data}->{is_sales} ? SALES_DELIVERY_ORDER_TYPE :
                                       PURCHASE_DELIVERY_ORDER_TYPE
    );
  }
  $entry->{info_data}->{record_type} = $::locale->text($entry->{object}->record_type);
}

sub handle_order_sources {
  my ($self, $entry) = @_;

  my $record = $entry->{object};

  $record->{source_orders} = [];
  return $record->{source_orders} if !$record->ordnumber;

  my @order_numbers = split ' ', $record->ordnumber;

  my $orders = SL::DB::Manager::Order->get_all(where => [ordnumber => \@order_numbers]);

  if (scalar @$orders == 0) {
    push @{ $entry->{errors} }, $::locale->text('Error: Source order not found');
  } elsif (scalar @$orders > 1) {
    push @{ $entry->{errors} }, $::locale->text('Error: More than one source order found');
  }

  foreach my $order (@$orders) {
    $self->{remaining_source_qtys_by_item_id} = { map { $_->id => $_->qty } @{ $order->items } };
  }

  $record->{source_orders} = $orders;
}

sub handle_item_source {
  my ($self, $entry, $record_entry) = @_;

  my $item   = $entry->{object};
  my $record = $record_entry->{object};

  return if !@{ $record->{source_orders} };

  # Todo: units?

  foreach my $order (@{ $record->{source_orders} }) {
    # First: Excact matches and source order position is still complete.
    $item->{source_item} = first {
         $item->parts_id                                     == $_->parts_id
      && $item->qty                                          == $_->qty
      && $self->{remaining_source_qtys_by_item_id}->{$_->id} == $_->qty
    } @{ $order->items_sorted };
    if ($item->{source_item}) {
      $self->{remaining_source_qtys_by_item_id}->{$item->{source_item}->id} -= $item->qty;
      last;
    }

    # Second: Smallest remaining order qty greater or equal delivery order qty.
    $item->{source_item} = first {
         $item->parts_id                                     == $_->parts_id
      && $self->{remaining_source_qtys_by_item_id}->{$_->id} >= $item->qty
    } sort { $self->{remaining_source_qtys_by_item_id}->{$a->id} <=> $self->{remaining_source_qtys_by_item_id}->{$b->id} } @{ $order->items_sorted };
    if ($item->{source_item}) {
      $self->{remaining_source_qtys_by_item_id}->{$item->{source_item}->id} -= $item->qty;
      last;
    }

    # Last: Overdelivery?
    # $item->{source_item} = first {
    #      $item->parts_id == $_->parts_id
    # } @{ $order->items_sorted };
    # if ($item->{source_item}) {
    #   $self->{remaining_source_qtys_by_item_id}->{$item->{source_item}->id} -= $item->qty;
    #   last;
    # }
  }
}

sub handle_unit {
  my ($self, $entry, $part) = @_;

  my $object = $entry->{object};

  $part ||= $object->part;

  # Set unit from part if not given.
  if (!$object->unit) {
    $object->unit($part->unit);
    return 1;
  }

  # Check whether or not unit is valid.
  if ($object->unit && !$self->units_by->{name}->{ $object->unit }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid unit');
    return 0;
  }

  # Check whether unit is convertible to parts unit
  if (none { $object->unit eq $_ } map { $_->name } @{ $part->unit_obj->convertible_units }) {
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

    if ($item->{source_item}) {
      # Set sellprice from source order item if not given. Convert with respect to unit.
      my $sellprice = $item->{source_item}->sellprice;
      if ($item->unit ne $item->{source_item}->unit) {
        $sellprice = $item->unit_obj->convert_to($sellprice, $item->{source_item}->unit_obj);
      }
      $item->sellprice($sellprice);
      $item->active_price_source($item->{source_item}->active_price_source);

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
}

sub handle_discount {
  my ($self, $entry, $record_entry) = @_;

  my $item   = $entry->{object};
  my $record = $record_entry->{object};

  return if !$record->customervendor;

  # If discount is given, set discount to none.
  if (exists $entry->{raw_data}->{discount}) {
    my $price_source = SL::PriceSource->new(record_item => $item, record => $record);
    my $discount     = $price_source->price_from_source('');
    $item->active_discount_source($discount->source);

  } else {

    if ($item->{source_item}) {
      # Set discount from source order item if not given.
      $item->discount($item->{source_item}->discount);
      $item->active_discount_source($item->{source_item}->active_discount_source);

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

sub check_part {
  my ($self, $entry) = @_;

  my $object = $entry->{object};
  my $is_ambiguous;

  # Check whether or not part ID is valid.
  if ($object->parts_id && !$self->parts_by->{id}->{ $object->parts_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Part not found');
    return 0;
  }

  # Map number to ID if given.
  if (!$object->parts_id && $entry->{raw_data}->{partnumber}) {
    my $part = $self->parts_by->{partnumber}->{ trim($entry->{raw_data}->{partnumber}) };
    if (!$part) {
      push @{ $entry->{errors} }, $::locale->text('Error: Part not found');
      return 0;
    }

    $object->parts_id($part->id);
  }

  # Map description to ID if given.
  if (!$object->parts_id && $entry->{raw_data}->{description}) {
    my $part = $self->parts_by->{description}->{ trim($entry->{raw_data}->{description}) };
    if (!$part) {
      push @{ $entry->{errors} }, $::locale->text('Error: Part not found');
      return 0;
    }

    if ($self->part_counts_by->{description}->{ trim($entry->{raw_data}->{description}) } > 1) {
      $is_ambiguous = 1;
    } else {
      $object->parts_id($part->id);
    }
  }

  # Map ean to ID if given.
  if (!$object->parts_id && $entry->{raw_data}->{ean}) {
    my $part = $self->parts_by->{ean}->{ trim($entry->{raw_data}->{ean}) };
    if (!$part) {
      push @{ $entry->{errors} }, $::locale->text('Error: Part not found');
      return 0;
    }

    if ($self->part_counts_by->{ean}->{ trim($entry->{raw_data}->{ean}) } > 1) {
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

sub check_warehouse {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not warehouse ID is valid.
  if ($object->warehouse_id && !$self->warehouses_by->{id}->{ $object->warehouse_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid warehouse');
    return 0;
  }

  # Map description to ID if given.
  if (!$object->warehouse_id && $entry->{raw_data}->{warehouse}) {
    my $wh = $self->warehouses_by->{description}->{ $entry->{raw_data}->{warehouse} };
    if (!$wh) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid warehouse');
      return 0;
    }

    $object->warehouse_id($wh->id);
  }

  if ($object->warehouse_id) {
    $entry->{info_data}->{warehouse} = $self->warehouses_by->{id}->{ $object->warehouse_id }->description;
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Warehouse not found');
    return 0;
  }

  return 1;
}

# Check bin for given warehouse, so check_warehouse must be called first.
sub check_bin {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not bin ID is valid.
  if ($object->bin_id && !$self->bins_by->{_wh_id_and_id_ident()}->{ _wh_id_and_id_maker($object->warehouse_id, $object->bin_id) }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid bin');
    return 0;
  }

  # Map description to ID if given.
  if (!$object->bin_id && $entry->{raw_data}->{bin}) {
    my $bin = $self->bins_by->{_wh_id_and_description_ident()}->{ _wh_id_and_description_maker($object->warehouse_id, $entry->{raw_data}->{bin}) };
    if (!$bin) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid bin');
      return 0;
    }

    $object->bin_id($bin->id);
  }

  if ($object->bin_id) {
    $entry->{info_data}->{bin} = $self->bins_by->{_wh_id_and_id_ident()}->{ _wh_id_and_id_maker($object->warehouse_id, $object->bin_id) }->description;
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Bin not found');
    return 0;
  }

  return 1;
}

sub save_additions {
  my ($self, $object) = @_;

  # record links
  my $orders = delete $object->{source_orders};

  if (scalar(@$orders)) {

    $_->link_to_record($object) for @$orders;

    foreach my $item (@{ $object->items }) {
      my $orderitem = delete $item->{source_item};
      $orderitem->link_to_record($item) if $orderitem;
    }
  }

  # delivery order for all positions created?
  if (scalar(@$orders)) {
    SL::Helper::ShippedQty->new->calculate($orders)->write_to_objects;
    $_->update_attributes(delivered => $_->delivered) for @{ $orders };
  }

  # inventory (or use WH->transfer?)
  foreach my $item (@{ $object->items }) {
    foreach my $stock_info (@{ $item->delivery_order_stock_entries }) {
      my $inventory  = delete $stock_info->{inventory_obj};
      next if !$inventory;
      my ($trans_id) = selectrow_query($::form, $object->db->dbh, qq|SELECT nextval('id')|);
      $inventory->trans_id($trans_id);
      $inventory->oe_id($object->id);
      $inventory->delivery_order_items_stock_id($stock_info->id);
      $inventory->save;
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

sub get_stocked_qty {
  my ($self, $parts_id, $wh_id, $bin_id, $chargenumber, $bestbefore) = @_;

  my $key = join '+', $parts_id, $wh_id, $bin_id, $chargenumber, $bestbefore;
  return $self->{stocked_qty}->{$key} if exists $self->{stocked_qty}->{$key};

  my $bestbefore_filter  = '';
  my $bestbefore_val_cnt = 0;
  if ($::instance_conf->get_show_bestbefore) {
    $bestbefore_filter  = ($bestbefore) ? 'AND bestbefore = ?' : 'AND bestbefore IS NULL';
    $bestbefore_val_cnt = ($bestbefore) ? 1                    : 0;
  }

  my $query = <<SQL;
    SELECT sum(qty) FROM inventory
      WHERE parts_id = ? AND warehouse_id = ? AND bin_id = ? AND chargenumber = ? $bestbefore_filter
      GROUP BY warehouse_id, bin_id, chargenumber
SQL

  my @values = ($parts_id,
                $wh_id,
                $bin_id,
                $chargenumber);
  push @values, $bestbefore if $bestbefore_val_cnt;

  my $dbh = $self->controller->data->[0]{object}->db->dbh;
  my ($stocked_qty) = selectrow_query($::form, $dbh, $query, @values);

  $self->{stocked_qty}->{$key} = $stocked_qty;
  return $stocked_qty;
}

sub _wh_id_and_description_ident {
  return 'wh_id+description';
}

sub _wh_id_and_description_maker {
  return join '+', $_[0], $_[1]
}

sub _wh_id_and_id_ident {
  return 'wh_id+id';
}

sub _wh_id_and_id_maker {
  return join '+', $_[0], $_[1]
}

sub _transfer_type_dir_and_description_ident {
  return 'dir+description';
}

sub _transfer_type_dir_and_description_maker {
  return join '+', $_[0], $_[1]
}

sub _order_column {
  $_[0]->settings->{'order_column'}
}

sub _item_column {
  $_[0]->settings->{'item_column'}
}

sub _stock_column {
  $_[0]->settings->{'stock_column'}
}

1;
