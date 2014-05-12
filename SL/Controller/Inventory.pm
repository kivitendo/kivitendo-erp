package SL::Controller::Inventory;

use strict;
use warnings;

use parent qw(SL::Controller::Base);

use SL::DB::Inventory;
use SL::DB::Part;
use SL::DB::Warehouse;
use SL::DB::Unit;
use SL::WH;
use SL::Locale::String qw(t8);
use SL::Presenter;
use SL::DBUtils;
use SL::Helper::Flash;

use English qw(-no_match_vars);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(warehouses units p) ],
  'scalar'                => [ qw(warehouse bin unit part) ],
);

__PACKAGE__->run_before('_check_auth');
__PACKAGE__->run_before('_check_warehouses');
__PACKAGE__->run_before('load_part_from_form',   only => [ qw(stock_in part_changed mini_stock stock) ]);
__PACKAGE__->run_before('load_unit_from_form',   only => [ qw(stock_in part_changed mini_stock stock) ]);
__PACKAGE__->run_before('load_wh_from_form',     only => [ qw(stock_in warehouse_changed stock) ]);
__PACKAGE__->run_before('load_bin_from_form',    only => [ qw(stock_in stock) ]);
__PACKAGE__->run_before('set_target_from_part',  only => [ qw(part_changed) ]);
__PACKAGE__->run_before('mini_stock',            only => [ qw(stock_in mini_stock) ]);
__PACKAGE__->run_before('sanitize_target',       only => [ qw(stock_in warehouse_changed part_changed) ]);
__PACKAGE__->run_before('set_layout');

sub action_stock_in {
  my ($self) = @_;

  $::form->{title}   = t8('Stock');

  $::request->layout->focus('#part_id_name');
  my $transfer_types = WH->retrieve_transfer_types('in');
  map { $_->{description} = $main::locale->text($_->{description}) } @{ $transfer_types };
  $self->render('inventory/warehouse_selection_stock', title => $::form->{title}, TRANSFER_TYPES => $transfer_types );
}

sub action_stock {
  my ($self) = @_;

  my $transfer_error;
  my $qty = $::form->parse_amount(\%::myconfig, $::form->{qty});
  if (!$qty) {
    $transfer_error = t8('Cannot stock without amount');
  } elsif ($qty < 0) {
    $transfer_error = t8('Cannot stock negative amounts');
  } else {
    # do stock
    $::form->throw_on_error(sub {
      eval {
        WH->transfer({
          parts         => $self->part,
          dst_bin       => $self->bin,
          dst_wh        => $self->warehouse,
          qty           => $qty,
          unit          => $self->unit,
          transfer_type => 'stock',
          chargenumber  => $::form->{chargenumber},
          bestbefore    => $::form->{bestbefore},
          ean           => $::form->{ean},
          comment       => $::form->{comment},
        });
        1;
      } or do { $transfer_error = $EVAL_ERROR->getMessage; }
    });

    if (!$transfer_error) {
      if ($::form->{write_default_bin}) {
        $self->part->load;   # onhand is calculated in between. don't mess that up
        $self->part->bin($self->bin);
        $self->part->warehouse($self->warehouse);
        $self->part->save;
      }

      flash_later('info', t8('Transfer successful'));
    }
  }

  my %additional_redirect_params = ();
  if ($transfer_error) {
    flash_later('error', $transfer_error);
    $additional_redirect_params{$_}  = $::form->{$_} for qw(qty chargenumber bestbefore ean comment);
    $additional_redirect_params{qty} = $qty;
  }

  # redirect
  $self->redirect_to(
    action       => 'stock_in',
    part_id      => $self->part->id,
    bin_id       => $self->bin->id,
    warehouse_id => $self->warehouse->id,
    unit_id      => $self->unit->id,
    %additional_redirect_params,
  );
}

sub action_part_changed {
  my ($self) = @_;

  # no standard? ask user if he wants to write it
  if ($self->part->id && !$self->part->bin_id && !$self->part->warehouse_id) {
    $self->js->show('#write_default_bin_span');
  } else {
    $self->js->hide('#write_default_bin_span')
             ->removeAttr('#write_default_bin', 'checked');
  }

  $self->js
    ->replaceWith('#warehouse_id', $self->build_warehouse_select)
    ->replaceWith('#bin_id', $self->build_bin_select)
    ->replaceWith('#unit_id', $self->build_unit_select)
    ->focus('#warehouse_id')
    ->render;
}

sub action_warehouse_changed {
  my ($self) = @_;

  $self->js
    ->replaceWith('#bin_id', $self->build_bin_select)
    ->focus('#bin_id')
    ->render;
}

sub action_mini_stock {
  my ($self) = @_;

  $self->js
    ->html('#stock', $self->render('inventory/_stock', { output => 0 }))
    ->render;
}

#================================================================

sub _check_auth {
  $main::auth->assert('warehouse_management');
}

sub _check_warehouses {
  $_[0]->show_no_warehouses_error if !@{ $_[0]->warehouses };
}

sub init_warehouses {
  SL::DB::Manager::Warehouse->get_all(query => [ or => [ invalid => 0, invalid => undef ]]);
}

sub init_units {
  SL::DB::Manager::Unit->get_all;
}

sub init_p {
  SL::Presenter->get;
}

sub set_target_from_part {
  my ($self) = @_;

  return if !$self->part;

  $self->warehouse($self->part->warehouse) if $self->part->warehouse;
  $self->bin(      $self->part->bin)       if $self->part->bin;
}

sub sanitize_target {
  my ($self) = @_;

  $self->warehouse($self->warehouses->[0])       if !$self->warehouse || !$self->warehouse->id;
  $self->bin      ($self->warehouse->bins->[0])  if !$self->bin       || !$self->bin->id;
}

sub load_part_from_form {
  $_[0]->part(SL::DB::Manager::Part->find_by_or_create(id => $::form->{part_id}));
}

sub load_unit_from_form {
  $_[0]->unit(SL::DB::Manager::Unit->find_by_or_create(id => $::form->{unit_id}));
}

sub load_wh_from_form {
  $_[0]->warehouse(SL::DB::Manager::Warehouse->find_by_or_create(id => $::form->{warehouse_id}));
}

sub load_bin_from_form {
  $_[0]->bin(SL::DB::Manager::Bin->find_by_or_create(id => $::form->{bin_id}));
}

sub set_layout {
  $::request->layout->add_javascripts('client_js.js');
}

sub build_warehouse_select {
 $_[0]->p->select_tag('warehouse_id', $_[0]->warehouses,
   title_key => 'description',
   default   => $_[0]->warehouse->id,
   onchange  => 'reload_bin_selection()',
  )
}

sub build_bin_select {
  $_[0]->p->select_tag('bin_id', [ $_[0]->warehouse->bins ],
    title_key => 'description',
    default   => $_[0]->bin->id,
  );
}

sub build_unit_select {
  $_[0]->part->id
    ? $_[0]->p->select_tag('unit_id', $_[0]->part->available_units,
        title_key => 'name',
        default   => $_[0]->part->unit_obj->id,
      )
    : $_[0]->p->select_tag('unit_id', $_[0]->units,
        title_key => 'name',
      )
}

sub mini_journal {
  my ($self) = @_;

  # get last 10 transaction ids
  my $query = 'SELECT trans_id, max(itime) FROM inventory GROUP BY trans_id ORDER BY max(itime) DESC LIMIT 10';
  my @ids = selectall_array_query($::form, $::form->get_standard_dbh, $query);

  my $objs;
  $objs = SL::DB::Manager::Inventory->get_all(query => [ trans_id => \@ids ]) if @ids;

  # at most 2 of them belong to a transaction and the qty determins in or out.
  # sort them for display
  my %transactions;
  for (@$objs) {
    $transactions{ $_->trans_id }{ $_->qty > 0 ? 'in' : 'out' } = $_;
    $transactions{ $_->trans_id }{base} = $_;
  }
  # and get them into order again
  my @sorted = map { $transactions{$_} } @ids;

  return \@sorted;
}

sub mini_stock {
  my ($self) = @_;

  my $stock             = $self->part->get_simple_stock;
  $self->{stock_by_bin} = { map { $_->{bin_id} => $_ } @$stock };
  $self->{stock_empty}  = ! grep { $_->{sum} * 1 } @$stock;
}

sub show_no_warehouses_error {
  my ($self) = @_;

  my $msg = t8('No warehouse has been created yet or the quantity of the bins is not configured yet.') . ' ';

  if ($::auth->check_right($::myconfig{login}, 'config')) { # TODO wut?
    $msg .= t8('You can create warehouses and bins via the menu "System -> Warehouses".');
  } else {
    $msg .= t8('Please ask your administrator to create warehouses and bins.');
  }
  $::form->show_generic_error($msg);
}

1;
