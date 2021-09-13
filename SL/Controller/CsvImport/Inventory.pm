package SL::Controller::CsvImport::Inventory;


use strict;

use SL::Helper::Csv;
use SL::Helper::DateTime;

use SL::DBUtils;
use SL::DB::Inventory;
use SL::DB::Part;
use SL::DB::Warehouse;
use SL::DB::Bin;
use SL::DB::TransferType;
use SL::DB::Employee;

use parent qw(SL::Controller::CsvImport::Base);


use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(settings parts_by warehouses_by bins_by) ],
);


sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::Inventory');
}

sub set_profile_defaults {
};

sub init_profile {
  my ($self) = @_;

  my $profile = $self->SUPER::init_profile;
  delete @{$profile}{qw(trans_id oe_id delivery_order_items_stock_id trans_type_id project_id)};
  delete @{$profile}{qw(bestbefore)}    if !$::instance_conf->get_show_bestbefore;

  return $profile;
}

sub init_settings {
  my ($self) = @_;

  return { map { ( $_ => $self->controller->profile->get($_) ) } qw(warehouse apply_warehouse
                                                                    bin       apply_bin
                                                                    comment   apply_comment) };
}

sub init_parts_by {
  my ($self) = @_;

  my $all_parts = SL::DB::Manager::Part->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_parts } } ) } qw(id partnumber ean description) };
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

sub check_objects {
  my ($self) = @_;

  $self->controller->track_progress(phase => 'building data', progress => 0);

  my $i = 0;
  my $num_data = scalar @{ $self->controller->data };
  foreach my $entry (@{ $self->controller->data }) {
    $self->controller->track_progress(progress => $i/$num_data * 100) if $i % 100 == 0;

    $self->check_warehouse($entry);
    $self->check_bin($entry);
    $self->check_part($entry);
    $self->check_qty($entry)            unless scalar @{ $entry->{errors} };
    $self->handle_comment($entry);
    $self->handle_employee($entry);
    $self->handle_transfer_type($entry) unless scalar @{ $entry->{errors} };
    $self->handle_shippingdate($entry);
  } continue {
    $i++;
  }

  $self->add_info_columns(qw(warehouse bin partnumber employee target_qty));
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->SUPER::setup_displayable_columns;

  $self->add_displayable_columns({ name => 'bin',          description => $::locale->text('Bin')                     },
                                 { name => 'bin_id',       description => $::locale->text('Bin (database ID)')       },
                                 { name => 'chargenumber', description => $::locale->text('Charge number')           },
                                 { name => 'comment',      description => $::locale->text('Comment')                 },
                                 { name => 'employee_id',  description => $::locale->text('Employee (database ID)')  },
                                 { name => 'partnumber',   description => $::locale->text('Part Number')             },
                                 { name => 'parts_id',     description => $::locale->text('Part (database ID)')      },
                                 { name => 'qty',          description => $::locale->text('qty (to transfer)')       },
                                 { name => 'shippingdate', description => $::locale->text('Shipping date')           },
                                 { name => 'target_qty',   description => $::locale->text('Target Qty')              },
                                 { name => 'warehouse',    description => $::locale->text('Warehouse')               },
                                 { name => 'warehouse_id', description => $::locale->text('Warehouse (database ID)') },
                                );
  if ($::instance_conf->get_show_bestbefore) {
    $self->add_displayable_columns({ name => 'bestbefore', description => $::locale->text('Best Before') });
  }
}

sub check_warehouse {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # If warehouse from front-end is enforced for all transfers, use this, if valid.
  if ($self->settings->{apply_warehouse} eq 'all') {
    $object->warehouse_id(undef);
    my $wh = $self->warehouses_by->{description}->{ $self->settings->{warehouse} };
    if (!$wh) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid warehouse');
      return 0;
    }

    $object->warehouse_id($wh->id);
  }

  # If warehouse from front-end is enforced for transfers with missing warehouse, use this, if valid.
  if (    $self->settings->{apply_warehouse} eq 'missing'
       && ! $object->warehouse_id
       && ! $entry->{raw_data}->{warehouse} ) {
    my $wh = $self->warehouses_by->{description}->{ $self->settings->{warehouse} };
    if (!$wh) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid warehouse');
      return 0;
    }

    $object->warehouse_id($wh->id);
  }

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

  # If bin from front-end is enforced for all transfers, use this, if valid.
  if ($self->settings->{apply_bin} eq 'all') {
    $object->bin_id(undef);
    my $bin = $self->bins_by->{_wh_id_and_description_ident()}->{ _wh_id_and_description_maker($object->warehouse_id, $self->settings->{bin}) };
    if (!$bin) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid bin');
      return 0;
    }

    $object->bin_id($bin->id);
  }

  # If bin from front-end is enforced for transfers with missing bin, use this, if valid.
  if (    $self->settings->{apply_bin} eq 'missing'
       && ! $object->bin_id
       && ! $entry->{raw_data}->{bin} ) {
    my $bin = $self->bins_by->{_wh_id_and_description_ident()}->{ _wh_id_and_description_maker($object->warehouse_id, $self->settings->{bin}) };
    if (!$bin) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid bin');
      return 0;
    }

    $object->bin_id($bin->id);
  }

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

sub check_part {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

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

  if ($object->parts_id) {
    $entry->{info_data}->{partnumber} = $self->parts_by->{id}->{ $object->parts_id }->partnumber;
  } else {
    push @{ $entry->{errors} }, $::locale->text('Error: Part not found');
    return 0;
  }

  return 1;
}

# This imports inventories when target_qty is given, transfers else.
# So we get the actual qty in stock and transfer the difference in case of
# a given target_qty
sub check_qty{
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  if (! exists $entry->{raw_data}->{target_qty} && ! exists $entry->{raw_data}->{qty}) {
    push @{ $entry->{errors} }, $::locale->text('Error: A quantity or a target quantity must be given.');
    return 0;
  }

  if (exists $entry->{raw_data}->{target_qty} && exists $entry->{raw_data}->{qty}) {
    push @{ $entry->{errors} }, $::locale->text('Error: A quantity and a target quantity could not be given both.');
    return 0;
  }

  if (exists $entry->{raw_data}->{target_qty} && ($entry->{raw_data}->{target_qty} * 1) < 0) {
    push @{ $entry->{errors} }, $::locale->text('Error: A negative target quantity is not allowed.');
    return 0;
  }

  # Actual quantity is read from stock or is the result of transfers for the
  # same part, warehouse, bin, chargenumber and bestbefore date (if
  # show_bestbefore is enabled) done before.
  my $key = join '+', $object->parts_id, $object->warehouse_id, $object->bin_id, $object->chargenumber;
  $key   .= join '+', $key, $object->bestbefore    if $::instance_conf->get_show_bestbefore;

  if (!exists $self->{resulting_quantities}->{$key}) {
    $self->{resulting_quantities}->{$key} = _get_stocked_qty($object);
  }
  my $actual_qty = $self->{resulting_quantities}->{$key};

  if (exists $entry->{raw_data}->{target_qty}) {
    my $target_qty = $entry->{raw_data}->{target_qty} * 1;

    $object->qty($target_qty - $actual_qty);
    $self->add_columns(qw(qty));
  }

  if ($object->qty == 0) {
    push @{ $entry->{errors} }, $::locale->text('Error: Quantity to transfer is zero.');
    return 0;
  }

  # Check if resulting quantity is below zero.
  if ( ($actual_qty + $object->qty) < 0 ) {
    push @{ $entry->{errors} }, $::locale->text('Error: Transfer would result in a negative target quantity.');
    return 0;
  }

  $self->{resulting_quantities}->{$key} += $object->qty;
  $entry->{info_data}->{target_qty} = $self->{resulting_quantities}->{$key};

  return 1;
}

sub handle_comment {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # If comment from front-end is enforced for all transfers, use this, if valid.
  if ($self->settings->{apply_comment} eq 'all') {
    $object->comment($self->settings->{comment});
  }

  # If comment from front-end is enforced for transfers with missing comment, use this, if valid.
  if ($self->settings->{apply_comment} eq 'missing' && ! $object->comment) {
    $object->comment($self->settings->{comment});
  }

  return;
}

sub handle_transfer_type  {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  my $transfer_type = SL::DB::Manager::TransferType->find_by(description => 'correction',
                                                             direction   => ($object->qty > 0)? 'in': 'out');
  $object->trans_type($transfer_type);

  return;
}

# ToDo: employee by name
sub handle_employee {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # employee from front end if not given
  if (!$object->employee_id) {
    $object->employee_id($self->controller->{employee_id})
  }

  # employee from login if not given
  if (!$object->employee_id) {
    $object->employee_id(SL::DB::Manager::Employee->current->id) if SL::DB::Manager::Employee->current;
  }

  if ($object->employee_id) {
    $entry->{info_data}->{employee} = $object->employee->name;
  }

}

sub handle_shippingdate {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  if (!$object->shippingdate) {
    $object->shippingdate(DateTime->today_local);
  }
}

sub save_objects {
  my ($self, %params) = @_;

  my $data = $params{data} || $self->controller->data;

  foreach my $entry (@{ $data }) {
    my ($trans_id) = selectrow_query($::form,$entry->{object}->db->dbh, qq|SELECT nextval('id')|);
    $entry->{object}->trans_id($trans_id);
  }

  $self->SUPER::save_objects(%params);
}

sub _get_stocked_qty {
  my ($object) = @_;

  my $bestbefore_filter  = '';
  my $bestbefore_val_cnt = 0;
  if ($::instance_conf->get_show_bestbefore) {
    $bestbefore_filter  = ($object->bestbefore) ? 'AND bestbefore = ?' : 'AND bestbefore IS NULL';
    $bestbefore_val_cnt = ($object->bestbefore) ? 1                    : 0;
  }

  my $query = <<SQL;
    SELECT sum(qty) FROM inventory
      WHERE parts_id = ? AND warehouse_id = ? AND bin_id = ? AND chargenumber = ? $bestbefore_filter
      GROUP BY warehouse_id, bin_id, chargenumber
SQL

  my @values = ($object->parts_id,
                $object->warehouse_id,
                $object->bin_id,
                $object->chargenumber);
  push @values, $object->bestbefore if $bestbefore_val_cnt;

  my ($stocked_qty) = selectrow_query($::form, $object->db->dbh, $query, @values);

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

1;
