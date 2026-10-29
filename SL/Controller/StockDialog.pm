package SL::Controller::StockDialog;

use strict;
use parent qw(SL::Controller::Base);

use SL::Controller::DeliveryOrder;
use SL::Controller::Order;
use SL::DB::Bin;
use SL::DB::Part;
use SL::DB::Unit;
use SL::DB::Warehouse;
use SL::Helper::Number qw(_format_number _parse_number);
use SL::JSON;
use SL::YAML;

use List::Util qw(any sum0);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(main_controller order valid_types type_data) ],
);

sub action_stock_in_out_dialog {
  my ($self) = @_;

  my $part        = SL::DB::Part->load_cached($::form->{parts_id}) or die "need parts_id";
  my $unit        = SL::DB::Unit->load_cached($::form->{unit}) or die "need unit";
  my $stock       = $::form->{stock};
  my $row         = $::form->{row};
  my $item_id     = $::form->{item_id};
  my $qty         = _parse_number($::form->{qty_as_number});
  my $row_ui_id   = $::form->{row_ui_id};
  my $next_button = $::form->{next_button} eq 'true';

  my $inout = $self->type_data->properties("transfer");

  my @contents   = DO->get_item_availability(parts_id => $part->id);
  my $stock_info = DO->unpack_stock_information(packed => $stock);

  $self->merge_stock_data($stock_info, \@contents, $part, $unit);

  my $delivered = $self->order->delivered;
  $self->render("stock_dialog/stock_dialog", { layout => 0 },
    WHCONTENTS  => \@contents,
    STOCK_INFO  => $stock_info,
    WAREHOUSES  => !$delivered ? SL::DB::Manager::Warehouse->get_all(query => [ or => [ invalid => 0, invalid => undef ]], with_objects=> ["bins",]) : [],
    part        => $part,
    do_qty      => $qty,
    do_unit     => $unit->name,
    delivered   => $self->order->delivered,
    row         => $row,
    item_id     => $item_id,
    in_out      => $inout,
    row_ui_id   => $row_ui_id,
    next_button => $next_button,
  );
}

sub action_add_stock_in_line_to_dialog {
  my ($self) = @_;

  my $do_qty    = _parse_number($::form->{do_qty});
  my $row_count = $::form->{row_count};
  my $part      = SL::DB::Part->load_cached($::form->{parts_id}) or die "need parts_id";

  my %units_by_name = map { $_->name => $_ } @{ SL::DB::Manager::Unit->get_all };
  my $do_unit = $units_by_name{$::form->{do_unit}};

  my $qty_sum = sum0 map {
    $units_by_name{$_->{unit}}->convert_to($_->{qty}, $do_unit);
  } @{$::form->{qties_with_units}};

  my $row_as_html = $self->p->render('stock_dialog/_stock_in_new_row',
    WAREHOUSES => SL::DB::Manager::Warehouse->get_all(with_objects=> ["bins",]),
    PART => $part,
    pos  => $row_count + 1,
    remaining_qty => $do_qty - $qty_sum,
    do_unit => $do_unit->name,
  );

  $self->js->append('#stock-in-out-table tbody', $row_as_html)->render();
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

sub merge_stock_data {
  my ($self, $stock_info, $contents, $part, $unit) = @_;
  # TODO rewrite to mapping

  if (!$self->order->delivered) {
    for my $row (@$contents) {
      # row here is in parts units. stock is in item units
      $row->{available_qty} = _format_number(
        $part->unit_obj->convert_to($row->{qty}, $unit), 2
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

sub init_main_controller {
  my $type = $::form->{type};

  if (any { $type eq $_} @{SL::DB::DeliveryOrder::TypeData->valid_types}) {
    return SL::Controller::DeliveryOrder->new;
  }
  if (any { $type eq $_} @{SL::DB::Order::TypeData->valid_types}) {
    return SL::Controller::Order->new;
  }

  die "Not a valid type for stock dialog";
}

sub init_order {
  $_[0]->main_controller->order;
}

sub init_type_data {
  $_[0]->main_controller->type_data;
}

1;
