#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#############################################################################
# SQL-Ledger, Accounting
# Copyright (c) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#
#######################################################################
#
# warehouse and packinglist
#
#######################################################################

use Carp;
use List::Util qw(any first none);
use POSIX qw(strftime);
use Scalar::Util qw(blessed);

use SL::Form;
use SL::User;

use SL::AM;
use SL::CVar;
use SL::CT;
use SL::Helper::Flash qw(flash flash_later);
use SL::IC;
use SL::WH;
use SL::OE;
use SL::Helper::Inventory qw(get_stock produce_assembly allocate_for_assembly check_allocations_for_assembly);
use SL::Helper::Inventory::Allocation;
use SL::Locale::String qw(t8);
use SL::ReportGenerator;
use SL::Presenter::Tag qw(checkbox_tag);
use SL::Presenter::Part;

use SL::DB::Part;

use Data::Dumper;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

use strict;

# parserhappy(R):

# contents of the "transfer_type" table:
#  $locale->text('back')
#  $locale->text('correction')
#  $locale->text('disposed')
#  $locale->text('found')
#  $locale->text('missing')
#  $locale->text('stock')
#  $locale->text('shipped')
#  $locale->text('transfer')
#  $locale->text('used')
#  $locale->text('return_material')
#  $locale->text('release_material')
#  $locale->text('assembled')
#  $locale->text('stocktaking')

# --------------------------------------------------------------------
# Transfer
# --------------------------------------------------------------------

sub transfer_warehouse_selection {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });

  show_no_warehouses_error() if (!scalar @{ $form->{WAREHOUSES} });

  my $units      = AM->retrieve_units(\%myconfig, $form);

  my $part = 0;
  if ( $form->{parts_id} ) {
    $part = SL::DB::Part->new();
    $part->id($form->{parts_id});
    $part->load();
  }

  # der zweite Parameter von unit_select_data gibt den default-Namen (selected) vor
  $form->{UNITS} = AM->unit_select_data($units, $form->{unit}, 0, $part ? $part->unit : 0);

  if (scalar @{ $form->{WAREHOUSES} }) {
    $form->{warehouse_id} ||= $form->{WAREHOUSES}->[0]->{id};
    $form->{bin_id}       ||= $form->{WAREHOUSES}->[0]->{BINS}->[0]->{id};
  }

  my $content;

  if ($form->{trans_type} eq 'removal') {
    setup_wh_transfer_warehouse_selection_action_bar("removal_parts_selection");
    $form->{title}   = $locale->text('Removal from Warehouse');
    $content         = $form->parse_html_template('wh/warehouse_selection');

  } elsif (!$form->{trans_type} || ($form->{trans_type} eq 'transfer')) {
    setup_wh_transfer_warehouse_selection_action_bar("transfer_parts_selection");
    $form->{title}   = $locale->text('Transfer');
    $content         = $form->parse_html_template('wh/warehouse_selection');

  } elsif ($form->{trans_type} eq 'assembly') {
    setup_wh_transfer_warehouse_selection_assembly_action_bar();
    $form->{title} = $locale->text('Produce Assembly');
    $content       = $form->parse_html_template('wh/warehouse_selection_assembly');
  }

  $form->header();
  print $content;

  $main::lxdebug->leave_sub();
}

sub transfer_parts_selection {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  transfer_or_removal_prepare_contents('direction' => 'transfer');

  setup_wh_transfer_parts_action_bar();

  $form->{title} = $locale->text('Transfer');
  $form->header();
  print $form->parse_html_template("wh/transfer_parts_selection");

  $main::lxdebug->leave_sub();
}

sub transfer_or_removal_prepare_contents {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my %args = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });

  my $warehouse_idx = get_warehouse_idx($form->{warehouse_id});
  $form->show_generic_error($locale->text("The selected warehouse does not exist.")) if (-1 == $warehouse_idx);

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_idx];

  $form->{initial_warehouse_idx} = $warehouse_idx;
  $form->{warehouse_description} = $warehouse->{description};
  $warehouse->{selected}         = 1;

  $form->show_generic_error($locale->text("The source warehouse does not contain any bins.")) if (0 == scalar @{ $warehouse->{BINS} });

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bin chargenumber bestbefore partunit ean);

  $form->{sort} = 'bindescription';
  my @contents  = WH->get_warehouse_report("warehouse_id" => $form->{warehouse_id},
                                           "bin_id"       => $form->{bin_id},
                                           "chargenumber" => $form->{chargenumber},
                                           "bestbefore"   => $form->{bestbefore},
                                           "partsid"      => $form->{part_id},
                                           "ean"          => $form->{ean});

  if (0 == scalar(@contents)) {
    $form->show_generic_error($locale->text("The selected warehouse is empty, or no stocked items where found that match the filter settings."));
  }

  my $all_units = AM->retrieve_units(\%myconfig, $form);

  foreach (@contents) {
    $_->{qty} = $form->format_amount(\%myconfig, $_->{qty}) . ' ' . $_->{partunit};

    my $this_unit = $_->{partunit};

    if ($all_units->{$_->{partunit}} && ($all_units->{g}->{base_unit} eq $all_units->{$_->{partunit}}->{base_unit})) {
      $this_unit = "kg";
    }

    $_->{UNITS} = AM->unit_select_data($all_units, $this_unit, 0, $_->{partunit});
  }

  my $transfer_types = WH->retrieve_transfer_types($args{direction});
  map { $_->{description} = $locale->text($_->{description}) } @{ $transfer_types };

  $form->{CONTENTS}       = \@contents;
  $form->{TRANSFER_TYPES} = $transfer_types;

  $main::lxdebug->leave_sub();
}


sub transfer_parts {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->get_lists('warehouses' => { 'key' => 'WAREHOUSES', 'bins' => 'BINS' });

  my $warehouse_idx = get_warehouse_idx($form->{warehouse_id});
  $form->show_generic_error($locale->text("The selected warehouse does not exist.")) if (-1 == $warehouse_idx);

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_idx];

  $form->show_generic_error($locale->text("The source warehouse does not contain any bins.")) if (0 == scalar @{ $warehouse->{BINS} });

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bin chargenumber bestbefore partunit);

  $form->{sort} = 'bindescription';
  my @contents  = WH->get_warehouse_report("warehouse_id" => $form->{warehouse_id});
  my $all_units = AM->retrieve_units(\%myconfig, $form);

  my @transfers;

  foreach my $row (1 .. $form->{rowcount}) {
    $form->{"qty_$row"} =~ s/^\s*//;
    $form->{"qty_$row"} =~ s/\s*$//;
    next if (!$form->{"qty_$row"});

    my $bin_idx = get_bin_idx($warehouse_idx, $form->{"src_bin_id_$row"});
    $form->show_generic_error($locale->text("The selected bin does not exist.")) if (-1 == $bin_idx);
    my $bin     = $warehouse->{BINS}->[$bin_idx];

    my $orig_qty = $form->{"qty_$row"} . " " . $form->{"unit_$row"};

    my $transfer = {
      'src_warehouse_id' => $form->{warehouse_id},
      'transfer_type_id' => $form->{transfer_type_id},
    };

    map { $transfer->{$_} = $form->{"${_}_${row}"} } qw(src_bin_id chargenumber bestbefore parts_id qty dst_warehouse_id dst_bin_id);

    my $entry;

    foreach (@contents) {
      if (($_->{binid} == $transfer->{src_bin_id}) && ($_->{parts_id} == $transfer->{parts_id}) && ($_->{chargenumber} eq $transfer->{chargenumber}) && $_->{bestbefore} eq $transfer->{bestbefore}) {
        $entry = $_;
        last;
      }
    }

    if (!$entry) {
      $form->error($locale->text("There is not enough left of '#1' in bin '#2' for the removal of #3.",
                                 $form->{"partdescription_$row"}, $bin->{description}, $orig_qty));
    }

    $transfer->{qty}  = $form->parse_amount(\%myconfig, $transfer->{qty}) * $all_units->{$form->{"unit_$row"}}->{factor};
    $transfer->{qty} /= $all_units->{$entry->{partunit}}->{factor} || 1;

    if (($entry->{qty} < $transfer->{qty}) || (0 >= $transfer->{qty})) {
      $form->error($locale->text("There is not enough left of '#1' in bin '#2' for the removal of #3.",
                                 $form->{"partdescription_$row"}, $bin->{description}, $orig_qty));
    }

    $transfer->{comment} = $form->{comment};
    $transfer->{change_default_bin} = $form->{change_default_bin};

    push @transfers, $transfer;

    $entry->{qty} -= $transfer->{qty};
  }

  if (!scalar @transfers) {
    $form->show_generic_information($locale->text('Nothing has been selected for transfer.'));
    $::dispatcher->end_request;
  }

  WH->transfer(@transfers);

  $form->{trans_type}    = 'transfer';
  $form->{saved_message} = $locale->text('The parts have been transferred.');

  transfer_warehouse_selection();

  $main::lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Transfer: stock
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# Transfer: assemblies
# Dies ist die Auswahlmaske für ein assembly.
# Die ist einfach von transfer_assembly_update_part kopiert und nur um den trans_type (assembly) korrigiert worden
# Es wäre schön, hier nochmal check_assembly_max_create auf, um die max. Fertigungszahl herauszufinden.
# Ich lass das mal als auskommentierte Idee bestehen jb 18.3.09
# --------------------------------------------------------------------

sub transfer_assembly_update_part {
  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{trans_type} = 'assembly';
  $form->{qty}        = $form->parse_amount(\%myconfig, $form->{qty});

  if (!$form->{parts_id}) {
    delete $form->{partunit};
    transfer_warehouse_selection();
    return;

  }

  my $part = SL::DB::Part->new(id => $::form->{parts_id})->load;
  @{$form}{qw(parts_id partnumber description)} = ($part->id, $part->partnumber, $part->description);

  transfer_stock_get_partunit();
  transfer_warehouse_selection();
}

sub transfer_stock_part_selected {
  $main::lxdebug->enter_sub();

  my $part = shift;

  my $form     = $main::form;

  @{$form}{qw(parts_id partnumber description ean warehouse_id bin_id)} = @{$part}{qw(id partnumber description ean warehouse_id bin_id)};

  transfer_stock_get_partunit();
  transfer_warehouse_selection();

  $main::lxdebug->leave_sub();
}

sub transfer_stock_get_partunit {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  if ($form->{parts_id}) {
    my $part_info     = IC->get_basic_part_info('id' => $form->{parts_id});
    $form->{partunit} = $part_info->{unit};
  }

  $main::lxdebug->leave_sub();
}

sub create_assembly {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{qty} = $form->parse_amount(\%myconfig, $form->{qty});
  if ($form->{qty} <= 0) {
    $form->show_generic_error($locale->text('Invalid quantity.'));
  }
  if (!$form->{warehouse_id} || !$form->{bin_id}) {
    $form->error($locale->text('The warehouse or the bin is missing.'));
  }
  # need part and bin object
  my ($bin, $assembly);
  $assembly = SL::DB::Manager::Part->find_by(id => $form->{parts_id}, part_type => 'assembly');
  $form->show_generic_error($locale->text('Invalid assembly')) unless ref $assembly eq 'SL::DB::Part';

  $bin = SL::DB::Manager::Bin->find_by(id => $form->{bin_id});
  $form->show_generic_error($locale->text('Invalid bin')) unless ref $bin eq 'SL::DB::Bin';

  $form->show_generic_error($locale->text('The assembly doesn\'t have any items.')) unless (scalar @{$assembly->assemblies});

  if (!$::instance_conf->get_show_bestbefore) {
    $form->{bestbefore} = '';
  }

  # Check if there are more than one chargenumber for one part of an assembly.
  # In this case let the user select the wanted chargenumbers.
  my $stocked_wh_id = $::instance_conf->get_produce_assembly_same_warehouse ? $form->{warehouse_id} : undef;
  my $stocked_parts = get_stock(part         => [ map { $_->part } @{$assembly->assemblies} ],
                                warehouse    => $stocked_wh_id,
                                by           => 'for_allocate',
                                with_objects => [qw(part warehouse bin)]);

  # Remove entries with no stock.
  $stocked_parts = [ grep { $_->{qty} != 0 } @$stocked_parts];

  my %stocked_by_parts_id = map { my $p_id = $_->{parts_id }; $p_id => [grep { $_->{parts_id} == $p_id } @$stocked_parts] } @$stocked_parts;

  my $is_stock_ambiguous = any { scalar(@{$_ || []}) > 1 } values %stocked_by_parts_id;
  my $allocation_check_failed;
  my $stock_check_failed;

  my @allocations;
  if ($is_stock_ambiguous) {
    if (!scalar @{$form->{allocations} || []}) {
      # User has not selected something / first_time.
      # Pre-fill allocations for selection form.
      eval {
        @allocations = allocate_for_assembly(part             => $assembly,
                                             qty              => $form->{qty},
                                             warehouse        => ($form->{warehouse_id} ? SL::DB::Warehouse->new(id => $form->{warehouse_id})->load : undef),
                                             chargenumber     => $form->{chargenumber},);
        1;
      } or do  {
        my $ex = $@;
        die $ex unless blessed($ex) && $ex->isa('SL::X::Inventory::Allocation::Multi');

        render_produce_assembly_error(title  => $locale->text('Allocate for Assembly'),
                                      errors => $ex->errors);
        return $::lxdebug->leave_sub();
      };

    } else {
      # User has selected something / selection form was sent.
      # Check allocations.

      # Create allocation helper objects from form.
      @allocations = map {
        SL::Helper::Inventory::Allocation->new(
          parts_id      => $_->{parts_id},
          qty           => $form->parse_amount(\%myconfig, $_->{qty}),
          bin_id        => $_->{bin_id},
          warehouse_id  => $_->{warehouse_id},
          bestbefore    => $_->{bestbefore},
          chargenumber  => $_->{chargenumber},
          comment       => $_->{comment},
          for_object_id => undef,
        )
      } grep { $form->parse_amount(\%myconfig, $_->{qty}) != 0 } @{$form->{allocations}};

      $allocation_check_failed = !check_allocations_for_assembly(part                 => $assembly,
                                                                 qty                  => $form->{qty},
                                                                 allocations          => \@allocations,
                                                                 check_overfulfilment => 1);

      if (!$allocation_check_failed) {
        # Check, if all allocations are stocked.
        foreach my $allocation (@allocations) {
          $stock_check_failed = none {
            $_->{parts_id}     == $allocation->parts_id     &&
            $_->{warehouse_id} == $allocation->warehouse_id &&
            $_->{bin_id}       == $allocation->bin_id       &&
            $_->{bestbefore}   == $allocation->bestbefore   &&
            $_->{chargenumber} eq $allocation->chargenumber &&
            $_->{qty}          >= $allocation->qty
          } @$stocked_parts;

          last if $stock_check_failed;
        }
      }
    }

    # Show selection form if requested or check was not ok. Continue to production otherwise.
    if ($form->{show_allocations} || $allocation_check_failed || $stock_check_failed) {
      flash('warning', t8("Allocations are not sufficient or overfulfilled")) if ($allocation_check_failed);
      flash('warning', t8("Not enough on stock for one or more allocations")) if ($stock_check_failed);

      my %allocations_by_parts_id = map { my $p_id = $_->{parts_id}; $p_id => [grep { $_->{parts_id} == $p_id } @allocations] } @allocations;

      my %needed_by_parts_id = map { $_->{parts_id} => $_->qty * $form->{qty} } @{$assembly->assemblies};
      create_assembly_chargenumbers($form, \%stocked_by_parts_id, \%needed_by_parts_id, \%allocations_by_parts_id);
      return $::lxdebug->leave_sub();
    }

  }

  eval {
    produce_assembly(
              part           => $assembly,               # target assembly
              qty            => $form->{qty},            # qty
              allocations    => ($is_stock_ambiguous ? \@allocations : undef),
              auto_allocate  => !$is_stock_ambiguous,
              bin            => $bin,                    # needed unless a global standard target is configured
              chargenumber   => $form->{chargenumber},   # optional
              bestbefore     => $form->{bestbefore},
              comment        => $form->{comment},        # optional
    );
    1;

  } or do {
    my $ex = $@;
    die $ex unless blessed($ex) && $ex->isa('SL::X::Inventory::Allocation::Multi');

    render_produce_assembly_error(title  => $locale->text('Produce Assembly'),
                                  errors => $ex->errors);
    return $::lxdebug->leave_sub();
  };

  delete @{$form}{qw(parts_id partnumber description qty unit chargenumber bestbefore comment)};

  $form->{saved_message} = $locale->text('The assembly has been created.');
  $form->{trans_type}    = 'assembly';

  transfer_warehouse_selection();

  $main::lxdebug->leave_sub();
}

sub render_produce_assembly_error {
  my (%params) = @_;

  my @errors       = @{$params{errors} || []};
  $::form->{title} = $params{title};

  $::form->header;
  print $::form->parse_html_template(
    'wh/produce_assembly_error',
    {
      missing_qty_exceptions => [ grep {  $_->isa('SL::X::Inventory::Allocation::MissingQty') } @errors ],
      other_exceptions       => [ grep { !$_->isa('SL::X::Inventory::Allocation::MissingQty') } @errors ],
    });
}

sub create_assembly_chargenumbers {
  my ($form, $stocked_by_parts_id, $needed_by_parts_id, $allocated_by_parts_id) = @_;

  setup_wh_create_assembly_chargenumbers_action_bar();

  my $hidden_vars = { map { $_ => $form->{$_} } qw(parts_id warehouse_id bin_id bestbefore chargenumber qty unit comment) };

  $form->{title} = $::locale->text('Select Chargenumbers');
  $form->header;

  print $form->parse_html_template(
    'wh/create_assembly_chargenumbers',
    {
      hidden_vars           => $hidden_vars,
      stocked_by_parts_id   => $stocked_by_parts_id,
      needed_by_parts_id    => $needed_by_parts_id,
      allocated_by_parts_id => $allocated_by_parts_id,
    }
  );
}

# --------------------------------------------------------------------
# Transfer: removal
# --------------------------------------------------------------------

sub removal_parts_selection {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  transfer_or_removal_prepare_contents('direction' => 'out');

  setup_wh_removal_parts_selection_action_bar();

  $form->{title} = $locale->text('Removal');
  $form->header();
  print $form->parse_html_template("wh/removal_parts_selection");

  $main::lxdebug->leave_sub();
}

sub remove_parts {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });

  my $warehouse_idx = get_warehouse_idx($form->{warehouse_id});
  $form->show_generic_error($locale->text("The selected warehouse does not exist.")) if (-1 == $warehouse_idx);

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_idx];

  $form->show_generic_error($locale->text("The warehouse does not contain any bins.")) if (0 == scalar @{ $warehouse->{BINS} });

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bin chargenumber bestbefore partunit);

  $form->{sort} = 'bindescription';
  my @contents  = WH->get_warehouse_report("warehouse_id" => $form->{warehouse_id});
  my $all_units = AM->retrieve_units(\%myconfig, $form);

  my @transfers;

  foreach my $row (1 .. $form->{rowcount}) {
    $form->{"qty_$row"} =~ s/^\s*//;
    $form->{"qty_$row"} =~ s/\s*$//;
    next if (!$form->{"qty_$row"});

    my $bin_idx = get_bin_idx($warehouse_idx, $form->{"src_bin_id_$row"});
    $form->show_generic_error($locale->text("The selected bin does not exist.")) if (-1 == $bin_idx);
    my $bin     = $warehouse->{BINS}->[$bin_idx];

    my $orig_qty = $form->{"qty_$row"} . " " . $form->{"unit_$row"};

    my $transfer = {
      'src_warehouse_id' => $form->{warehouse_id},
      'transfer_type_id' => $form->{transfer_type_id},
    };

    map { $transfer->{$_} = $form->{"${_}_${row}"} } qw(src_bin_id chargenumber bestbefore parts_id qty);

    my $entry;

    foreach (@contents) {
      if (($_->{binid} == $transfer->{src_bin_id}) && ($_->{parts_id} == $transfer->{parts_id}) && ($_->{chargenumber} eq $transfer->{chargenumber}) && ($_->{bestbefore} eq $transfer->{bestbefore})) {
        $entry = $_;
        last;
      }
    }

    if (!$entry) {
      $form->error($locale->text("There is not enough left of '#1' in bin '#2' for the removal of #3.",
                                 $form->{"partdescription_$row"}, $bin->{description}, $orig_qty));
    }

    $transfer->{qty}  = $form->parse_amount(\%myconfig, $transfer->{qty}) * $all_units->{$form->{"unit_$row"}}->{factor};
    $transfer->{qty} /= $all_units->{$entry->{partunit}}->{factor} || 1;

    if (($entry->{qty} < $transfer->{qty}) || (0 >= $transfer->{qty})) {
      $form->error($locale->text("There is not enough left of '#1' in bin '#2' for the removal of #3.",
                                 $form->{"partdescription_$row"}, $bin->{description}, $orig_qty));
    }

    $transfer->{comment} = $form->{comment};

    push @transfers, $transfer;

    $entry->{qty} -= $transfer->{qty};
  }

  if (!scalar @transfers) {
    $form->show_generic_information($locale->text('Nothing has been selected for removal.'));
    $::dispatcher->end_request;
  }

  WH->transfer(@transfers);

  $form->{trans_type}    = 'removal';
  $form->{saved_message} = $locale->text('The parts have been removed.');

  transfer_warehouse_selection();

  $main::lxdebug->leave_sub();
}

sub disassemble_assembly {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form = $main::form;

  croak("No assembly ids") unless scalar @{ $form->{ids}} > 0;

  # everything in one transaction
  my $db = SL::DB::Inventory->new->db;
  $db->with_transaction(sub {

    foreach my $trans_id (@{ $::form->{ids}} )  {
      SL::DB::Manager::Inventory->delete_all(where => [ trans_id => $trans_id ]);
      flash_later('info', t8("Disassembly successful for trans_id #1",  $trans_id));
    }

    1;
  }) || die t8('error while disassembling for trans_ids #1 : #2', $form->{ids})  . $db->error . "\n";

  $main::lxdebug->leave_sub();
  $form->redirect;
}

# --------------------------------------------------------------------
# Journal
# --------------------------------------------------------------------

sub journal {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{title} = $locale->text('Report about warehouse transactions');
  $form->get_lists('warehouses' => { 'key'  => 'WAREHOUSES',
                                     'bins' => 'BINS', });

  show_no_warehouses_error() if (!scalar @{ $form->{WAREHOUSES} });

  my $cvar_configs                           = CVar->get_configs('module' => 'IC');
  ($form->{CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $cvar_configs,
                                                                           'include_prefix' => 'l_',
                                                                           'include_value'  => 'Y');

  setup_wh_journal_action_bar();

  $form->header();
  print $form->parse_html_template("wh/journal_filter", { "UNITS" => AM->unit_select_data(AM->retrieve_units(\%myconfig, $form)) });

  $main::lxdebug->leave_sub();
}

sub generate_journal {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  setup_wh_journal_list_all_action_bar();
  $form->{title}   = $locale->text("WHJournal");
  $form->{sort}  ||= 'date';

  $form->{report_generator_output_format} = 'HTML' if !$form->{report_generator_output_format};

  my %filter;
  my @columns = qw(ids trans_id date warehouse_from bin_from warehouse_to bin_to partnumber type_and_classific partdescription chargenumber bestbefore comment transfer direction qty partunit trans_type employee oe_id projectnumber);

  # filter stuff
  map { $filter{$_} = $form->{$_} if ($form->{$_}) } qw(warehouse_id bin_id classification_id partnumber description chargenumber bestbefore transtype_id transtype_ids comment projectnumber trans_id id);

  # ids are directly to db
  $form->show_generic_error($locale->text("ID needs to be a number.")) if    ($filter{trans_id} && $filter{trans_id} !~ /^[0-9]*$/)
                                                                          || ($filter{id}       && $filter{id}       !~ /^[0-9]*$/);

  $filter{qty_op} = WH->convert_qty_op($form->{qty_op});
  if ($filter{qty_op}) {
    $form->isblank("qty",      $locale->text('Quantity missing.'));
    $form->isblank("qty_unit", $locale->text('Unit missing.'));

    $filter{qty}      = $form->{qty};
    $filter{qty_unit} = $form->{qty_unit};
  }
  # /filter stuff

  my $allrows        = !!($form->{report_generator_output_format} ne 'HTML') ;

  # manual paginating
  my $pages          = {};
  my $page           = $::form->{page} || 1;
  $pages->{per_page} = $::form->{per_page} || 15;
  my $first_nr       = ($page - 1) * $pages->{per_page};
  my $last_nr        = $first_nr + $pages->{per_page};

  # no optimisation if qty op
  if ( !$allrows && $form->{maxrows} && !$filter{qty_op}) {
    $filter{limit}  = $pages->{per_page};
    $filter{offset} = ($page - 1) * $pages->{per_page};
    $first_nr       = 0;
    $last_nr        = $pages->{per_page};
  }

  my $old_l_trans_id = $form->{l_trans_id};
  my @contents  = WH->get_warehouse_journal(%filter);
  $form->{l_trans_id} = $old_l_trans_id;

  # get maxcount
  if (!$form->{maxrows}) {
    $form->{maxrows} = scalar @contents ;
  }

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my $cvar_configs                 = CVar->get_configs('module' => 'IC');
  my @includeable_custom_variables = grep { $_->{includeable} } @{ $cvar_configs };
  my @searchable_custom_variables  = grep { $_->{searchable} }  @{ $cvar_configs };
  push @columns, map { "cvar_$_->{name}" } @includeable_custom_variables;

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, qw(warehouse_id bin_id partnumber description chargenumber bestbefore qty_op qty qty_unit unit partunit fromdate todate transtype_ids comment projectnumber);
  push @hidden_variables, qw(classification_id trans_id id);
  push @hidden_variables, map({'cvar_'. $_->{name}}                                         @searchable_custom_variables);
  push @hidden_variables, map({'cvar_'. $_->{name} .'_from'}  grep({$_->{type} eq  'date'}  @searchable_custom_variables));
  push @hidden_variables, map({'cvar_'. $_->{name} .'_to'}    grep({$_->{type} eq  'date'}  @searchable_custom_variables));
  push @hidden_variables, map({'cvar_'. $_->{name} .'_qtyop'} grep({$_->{type} eq 'number'} @searchable_custom_variables));

  my %column_defs = (
    'ids'             => { raw_header_data => checkbox_tag("", id => "check_all", checkall  => "[data-checkall=1]") },
    'date'            => { 'text' => $locale->text('Date'), },
    'trans_id'        => { 'text' => $locale->text('Trans Id'), },
    'trans_type'      => { 'text' => $locale->text('Trans Type'), },
    'comment'         => { 'text' => $locale->text('Comment'), },
    'warehouse_from'  => { 'text' => $locale->text('Warehouse From'), },
    'warehouse_to'    => { 'text' => $locale->text('Warehouse To'), },
    'bin_from'        => { 'text' => $locale->text('Bin From'), },
    'bin_to'          => { 'text' => $locale->text('Bin To'), },
    'partnumber'      => { 'text' => $locale->text('Part Number'), },
    'type_and_classific'
                      => { 'text' => $locale->text('Type'), },
    'partdescription' => { 'text' => $locale->text('Part Description'), },
    'chargenumber'    => { 'text' => $locale->text('Charge Number'), },
    'bestbefore'      => { 'text' => $locale->text('Best Before'), },
    'direction'       => { 'text' => $locale->text('+/-'), },
    'qty'             => { 'text' => $locale->text('Qty'), },
    'unit'            => { 'text' => $locale->text('Part Unit'), },
    'partunit'        => { 'text' => $locale->text('Unit'), },
    'employee'        => { 'text' => $locale->text('Employee'), },
    'projectnumber'   => { 'text' => $locale->text('Project Number'), },
    'oe_id'           => { 'text' => $locale->text('Document'), },
  );

  my %column_defs_cvars = map { +"cvar_$_->{name}" => { 'text' => $_->{description} } } @includeable_custom_variables;
  %column_defs          = (%column_defs, %column_defs_cvars);

  if ($form->{transtype_ids} && 'ARRAY' eq ref $form->{transtype_ids}) {
    for (my $i = 0; $i < scalar(@{ $form->{transtype_ids} }); $i++) {
      delete $form->{transtype_ids}[$i] if $form->{transtype_ids}[$i] eq '';
    }
    $form->{transtype_ids} = join(",", @{ $form->{transtype_ids} });
  }

  my $href = build_std_url('action=generate_journal', grep { $form->{$_} } @hidden_variables);
  $href .= "&maxrows=".$form->{maxrows};

  map { $column_defs{$_}->{link} = $href ."&page=".$page. "&sort=${_}&order=" . Q($_ eq $form->{sort} ? 1 - $form->{order} : $form->{order}) } grep {!/^cvar/} @columns;

  my %column_alignment = map { $_ => 'right' } qw(qty);

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;
  $column_defs{partunit}->{visible} = 1;
  $column_defs{type_and_classific}->{visible} = 1;
  $column_defs{type_and_classific}->{link} ='';
  $column_defs{ids}->{visible} = 1;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('generate_journal', @hidden_variables, qw(sort order));

  $report->set_sort_indicator($form->{sort}, $form->{order});

  $report->set_options('output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => strftime($locale->text('warehouse_journal_list') . '_%Y%m%d', localtime time));
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  my $all_units = AM->retrieve_units(\%myconfig, $form);

  CVar->add_custom_variables_to_report('module'         => 'IC',
                                       'trans_id_field' => 'parts_id',
                                       'configs'        => $cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => \@contents);


  my %doc_types = ( 'sales_quotation'         => { action => 'Order/edit', script => 'controller', title => $locale->text('Sales quotation') },
                    'sales_order'             => { action => 'Order/edit', script => 'controller', title => $locale->text('Sales Order') },
                    'request_quotation'       => { action => 'Order/edit', script => 'controller', title => $locale->text('Request quotation') },
                    'purchase_order'          => { action => 'Order/edit', script => 'controller', title => $locale->text('Purchase Order') },
                    'sales_delivery_order'    => { action => 'DeliveryOrder/edit', script => 'controller', title => $locale->text('Sales delivery order') },
                    'purchase_delivery_order' => { action => 'DeliveryOrder/edit', script => 'controller', title => $locale->text('Purchase delivery order') },
                    'supplier_delivery_order' => { action => 'DeliveryOrder/edit', script => 'controller', title => $locale->text('Supplier delivery order') },
                    'rma_delivery_order'      => { action => 'DeliveryOrder/edit', script => 'controller', title => $locale->text('RMA delivery order') },
                    'sales_invoice'           => { action => 'edit', script => 'is', title => $locale->text('Sales Invoice') },
                    'purchase_invoice'        => { action => 'edit', script => 'ir', title => $locale->text('Purchase Invoice') },
                  );

  my $idx       = 0;
  my $undo_date  = DateTime->today->subtract(days => $::instance_conf->get_undo_transfer_interval);
  foreach my $entry (@contents) {
    $entry->{type_and_classific} = SL::Presenter::Part::type_abbreviation($entry->{part_type}) .
                                   SL::Presenter::Part::classification_abbreviation($entry->{classification_id});
    $entry->{qty}        = $form->format_amount(\%myconfig, $entry->{qty});
    $entry->{assembled} = $entry->{trans_type} eq 'assembled' ? 1 : '';
    $entry->{trans_type} = $locale->text($entry->{trans_type});
    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'  => $entry->{$column},
        'align' => $column_alignment{$column},
      };
      if ($column eq 'partnumber') {
        $row->{$column}->{link}  = build_std_url("script=controller.pl", 'action=Part/edit', 'part.id=' . E($entry->{parts_id}), 'callback', $href);
      }
    }

    if ($entry->{assembled}) {
      my $insertdate = DateTime->from_kivitendo($entry->{shippingdate});
      if (ref $undo_date eq 'DateTime' && ref $insertdate eq 'DateTime' && $insertdate > $undo_date) {
        $row->{ids}->{raw_data} = checkbox_tag("ids[]", value => $entry->{trans_id}, "data-checkall" => 1);
      }
    }
    $row->{trans_type}->{raw_data} = $entry->{trans_type};

    $row->{direction}->{raw_data} =   $entry->{direction} eq 'in'       ? '+'
                                    : $entry->{direction} eq 'out'      ? '-'
                                    : $entry->{direction} eq 'transfer' ? '='
                                    : die "Invalid direction entry";

    if ($form->{l_oe_id}) {
      $row->{oe_id}->{data} = '';
      my $info              = $entry->{oe_id_info};

      if ($info && $info->{id} && $info->{type} && $doc_types{$info->{type}}) {
        $row->{oe_id} = { data => $doc_types{ $info->{type} }->{title} . ' ' . $info->{number},
                          link => build_std_url('script=' . $doc_types{ $info->{type} }->{script} . '.pl', 'action=' . $doc_types{ $info->{type} }->{action}, 'id=' . $info->{id}, 'type=' . $info->{type}) };
      }
    }

    if ( $allrows || ($idx >= $first_nr && $idx < $last_nr )) {
      $report->add_data($row);
    }
    $idx++;
  }


    $report->set_options(
      raw_top_info_text     => $form->parse_html_template('wh/report_top'),
      raw_bottom_info_text  => $form->parse_html_template('wh/report_bottom', { callback => $href }),
    );
  if ( ! $allrows ) {
      $pages->{max}  = SL::DB::Helper::Paginated::ceil($form->{maxrows}, $pages->{per_page}) || 1;
      $pages->{page} = $page < 1 ? 1: $page > $pages->{max} ? $pages->{max}: $page;
      $pages->{common} = [ grep { $_->{visible} } @{ SL::DB::Helper::Paginated::make_common_pages($pages->{page}, $pages->{max}) } ];

      $report->set_options('raw_bottom_info_text' =>  $form->parse_html_template('wh/report_bottom', { callback => $href }) . $form->parse_html_template('common/paginate',
                                                            { 'pages' => $pages , 'base_url' => $href.'&sort='.$form->{sort}.'&order='.$form->{order}}) );
  }
  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Report
# --------------------------------------------------------------------

sub report {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_contents | warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', },
                   'partsgroup' => 'PARTSGROUPS');

  show_no_warehouses_error() if (!scalar @{ $form->{WAREHOUSES} });

  my $cvar_configs                           = CVar->get_configs('module' => 'IC');
  ($form->{CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $cvar_configs,
                                                                           'include_prefix' => 'l_',
                                                                           'include_value'  => 'Y');

  $form->{title}   = $locale->text("Report about warehouse contents");

  setup_wh_report_action_bar();

  $form->header();
  print $form->parse_html_template("wh/report_filter",
                                   { "WAREHOUSES"  => $form->{WAREHOUSES},
                                     "PARTSGROUPS" => $form->{PARTSGROUPS},
                                     "UNITS"       => AM->unit_select_data(AM->retrieve_units(\%myconfig, $form)),
                                   });

  $main::lxdebug->leave_sub();
}

sub generate_report {
  $main::lxdebug->enter_sub();

  $main::auth->assert('warehouse_contents | warehouse_management');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{title}   = $locale->text("Report about warehouse contents");
  $form->{sort}  ||= 'partnumber';
  my $sort_col     = $form->{sort};

  my %filter;
  my @columns = qw(warehouse bin partnumber type_and_classific partdescription chargenumber bestbefore comment qty partunit list_price purchase_price price_factor stock_value);

  # filter stuff
  map { $filter{$_} = $form->{$_} if ($form->{$_}) } qw(warehouse_id bin_id classification_id partnumber description partsgroup_id chargenumber bestbefore date include_invalid_warehouses);

  # show filter stuff also in report
  my @options;
  my $currentdate = $form->current_date(\%myconfig);
  push @options, $locale->text('Printdate') . " : ".$locale->date(\%myconfig, $currentdate, 1);

  # dispatch all options
  my $dispatch_options = {
   warehouse_id   => sub { push @options, $locale->text('Warehouse') . " : " .
                                            SL::DB::Manager::Warehouse->find_by(id => $form->{warehouse_id})->description},
   bin_id         => sub { push @options, $locale->text('Bin') . " : " .
                                            SL::DB::Manager::Bin->find_by(id => $form->{bin_id})->description},
   partnumber     => sub { push @options, $locale->text('Partnumber')     . " : $form->{partnumber}"},
   classification_id => sub { push @options, $locale->text('Parts Classification'). " : ".
                                               SL::DB::Manager::PartClassification->get_first(where => [ id => $form->{classification_id} ] )->description; },
   description    => sub { push @options, $locale->text('Description')    . " : $form->{description}"},
   partsgroup_id  => sub { push @options, $locale->text('Partsgroup')     . " : " .
                                            SL::DB::PartsGroup->new(id => $form->{partsgroup_id})->load->partsgroup},
   chargenumber   => sub { push @options, $locale->text('Charge Number')  . " : $form->{chargenumber}"},
   bestbefore     => sub { push @options, $locale->text('Best Before')    . " : $form->{bestbefore}"},
   include_invalid_warehouses    => sub { push @options, $locale->text('Include invalid warehouses ')},
  };
  foreach (keys %filter) {
   $dispatch_options->{$_}->() if $dispatch_options->{$_};
  }
  push @options, $locale->text('Stock Qty for Date') . " " . $locale->date(\%myconfig, $form->{date}?$form->{date}:$currentdate, 1);

  # / end show filter stuff also in report

  $filter{qty_op} = WH->convert_qty_op($form->{qty_op});
  if ($filter{qty_op}) {
    $form->isblank("qty",      $locale->text('Quantity missing.'));
    $form->isblank("qty_unit", $locale->text('Unit missing.'));

    $filter{qty}      = $form->{qty};
    $filter{qty_unit} = $form->{qty_unit};
  }
  # /filter stuff

  $form->{report_generator_output_format} = 'HTML' if !$form->{report_generator_output_format};

  # manual paginating
  my $allrows        = $form->{report_generator_output_format} eq 'HTML' ? $form->{allrows} : 1;
  my $page           = $::form->{page} || 1;
  my $pages          = {};
  $pages->{per_page} = $::form->{per_page} || 20;
  my $first_nr       = ($page - 1) * $pages->{per_page};
  my $last_nr        = $first_nr + $pages->{per_page};

  # no optimisation if qty op
  if ( !$allrows && $form->{maxrows} && !$filter{qty_op}) {
    $filter{limit}  = $pages->{per_page};
    $filter{offset} = ($page - 1) * $pages->{per_page};
    $first_nr       = 0;
    $last_nr        = $pages->{per_page};
  }

  my @contents  = WH->get_warehouse_report(%filter);

  # get maxcount
  if (!$form->{maxrows}) {
    $form->{maxrows} = scalar @contents ;
  }

  $form->{subtotal} = '' if (!first { $_ eq $sort_col } qw(partnumber partdescription));

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my $cvar_configs                 = CVar->get_configs('module' => 'IC');
  my @includeable_custom_variables = grep { $_->{includeable} } @{ $cvar_configs };
  my @searchable_custom_variables  = grep { $_->{searchable} }  @{ $cvar_configs };
  push @columns, map { "cvar_$_->{name}" } @includeable_custom_variables;

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, qw(warehouse_id bin_id partnumber partstypes_id description partsgroup_id chargenumber bestbefore qty_op qty qty_unit partunit l_warehouse l_bin);
  push @hidden_variables, qw(include_empty_bins subtotal include_invalid_warehouses date);
  push @hidden_variables, qw(classification_id stock_value_basis allrows);
  push @hidden_variables, map({'cvar_'. $_->{name}}                                         @searchable_custom_variables);
  push @hidden_variables, map({'cvar_'. $_->{name} .'_from'}  grep({$_->{type} eq 'date'}   @searchable_custom_variables));
  push @hidden_variables, map({'cvar_'. $_->{name} .'_to'}    grep({$_->{type} eq 'date'}   @searchable_custom_variables));
  push @hidden_variables, map({'cvar_'. $_->{name} .'_qtyop'} grep({$_->{type} eq 'number'} @searchable_custom_variables));

  my %column_defs = (
    'warehouse'            => { 'text' => $locale->text('Warehouse'), },
    'bin'                  => { 'text' => $locale->text('Bin'), },
    'partnumber'           => { 'text' => $locale->text('Part Number'), },
    'type_and_classific'   => { 'text' => $locale->text('Type'), },
    'partdescription'      => { 'text' => $locale->text('Part Description'), },
    'chargenumber'         => { 'text' => $locale->text('Charge Number'), },
    'bestbefore'           => { 'text' => $locale->text('Best Before'), },
    'qty'                  => { 'text' => $locale->text('Qty'), },
    'partunit'             => { 'text' => $locale->text('Unit'), },
    'stock_value'          => { 'text' => $locale->text('Stock value'), },
    'purchase_price'       => { 'text' => $locale->text('Purchase price'), },
    'list_price'           => { 'text' => $locale->text('List Price'), },
    'price_factor'         => { 'text' => $locale->text('Price Factor'), },
  );

  my %column_defs_cvars = map { +"cvar_$_->{name}" => { 'text' => $_->{description} } } @includeable_custom_variables;
  %column_defs = (%column_defs, %column_defs_cvars);

  my $href = build_std_url('action=generate_report', grep { $form->{$_} } @hidden_variables);
  $href .= "&maxrows=".$form->{maxrows};

  my %cvar_is_text = ();
  $cvar_is_text{"cvar_$_->{name}"} = 1 for
    grep {$_->{type} =~ m/text|textfield|htmlfield/}
    @$cvar_configs;

  map { $column_defs{$_}->{link} = $href . "&page=".$page."&sort=${_}&order=" . Q($_ eq $sort_col ? 1 - $form->{order} : $form->{order}) }
    grep {!/^cvar_/ or $cvar_is_text{$_}}
    @columns;

  my %column_alignment = map { $_ => 'right' } qw(qty list_price purchase_price price_factor stock_value);

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $column_defs{partunit}->{visible}           = 1;
  $column_defs{type_and_classific}->{visible} = 1;
  $column_defs{type_and_classific}->{link} ='';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('generate_report', @hidden_variables, qw(sort order));

  $report->set_sort_indicator($sort_col, $form->{order});

  $report->set_options('top_info_text'        => join("\n", @options),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => strftime($locale->text('warehouse_report_list') . '_%Y%m%d', localtime time));
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';
  CVar->add_custom_variables_to_report('module'         => 'IC',
                                       'trans_id_field' => 'parts_id',
                                       'configs'        => $cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => \@contents);

  my $all_units = AM->retrieve_units(\%myconfig, $form);
  my $idx       = 0;

  my @subtotals_columns = qw(qty stock_value);
  my %subtotals         = map { $_ => 0 } @subtotals_columns;

  my $total_stock_value = 0;

  foreach my $entry (@contents) {

    $entry->{type_and_classific} = SL::Presenter::Part::type_abbreviation($entry->{part_type}).
                                   SL::Presenter::Part::classification_abbreviation($entry->{classification_id});
    map { $subtotals{$_} += $entry->{$_} } @subtotals_columns;
    $total_stock_value   += $entry->{stock_value} * 1;
    $entry->{qty}         = $form->format_amount(\%myconfig, $entry->{qty});
    $entry->{stock_value} = $form->format_amount(\%myconfig, $entry->{stock_value} * 1, 2);
    $entry->{purchase_price} = $form->format_amount(\%myconfig, $entry->{purchase_price} * 1, 2);
    $entry->{list_price}     = $form->format_amount(\%myconfig, $entry->{list_price}     * 1, 2);

    my $row_set = [ { map { $_ => { 'data' => $entry->{$_}, 'align' => $column_alignment{$_} } } @columns } ];

    if ( ($form->{subtotal} eq 'Y' && !$form->{report_generator_csv_options_for_import} )
        && (($idx == (scalar @contents - 1))
            || ($entry->{$sort_col} ne $contents[$idx + 1]->{$sort_col}))) {

      my $row = { map { $_ => { 'data' => '', 'class' => 'listsubtotal', 'align' => $column_alignment{$_}, } } @columns };
      $row->{qty}->{data}         = $form->format_amount(\%myconfig, $subtotals{qty});
      $row->{stock_value}->{data} = $form->format_amount(\%myconfig, $subtotals{stock_value} * 1, 2);
      $row->{purchase_price}->{data} = $form->format_amount(\%myconfig, $subtotals{purchase_price} * 1, 2);
      $row->{list_price}->{data}     = $form->format_amount(\%myconfig, $subtotals{list_price}     * 1, 2);

      %subtotals                  = map { $_ => 0 } @subtotals_columns;

      push @{ $row_set }, $row;
    }

    if ( $allrows || ($idx >= $first_nr && $idx < $last_nr )) {
        $report->add_data($row_set);
    }
    $idx++;
  }

  if ( $column_defs{stock_value}->{visible} && !$form->{report_generator_csv_options_for_import} ) {
    $report->add_separator();

    my $row                      = { map { $_ => { 'data' => '', 'class' => 'listsubtotal', } } @columns };

    my $left_col                 = first { $column_defs{$_}->{visible} } @columns;

    $row->{$left_col}->{data}    = $locale->text('Total stock value');
    $row->{stock_value}->{data}  = $form->format_amount(\%myconfig, $total_stock_value, 2);
    $row->{stock_value}->{align} = 'right';

    $report->add_data($row);
  }
  if ( ! $allrows ) {
    $pages->{max}  = SL::DB::Helper::Paginated::ceil($form->{maxrows}, $pages->{per_page}) || 1;
    $pages->{page} = $page < 1 ? 1: $page > $pages->{max} ? $pages->{max}: $page;
    $pages->{common} = [ grep { $_->{visible} } @{ SL::DB::Helper::Paginated::make_common_pages($pages->{page}, $pages->{max}) } ];

    $report->set_options('raw_bottom_info_text' => $form->parse_html_template('common/paginate',
                                                                              {'pages' => $pages , 'base_url' => $href}) );
  }

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Utility functions
# --------------------------------------------------------------------

sub show_no_warehouses_error {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $msg = $locale->text('No warehouse has been created yet or the quantity of the bins is not configured yet.') . ' ';

  if ($main::auth->check_right($::myconfig{login}, 'config')) {
    $msg .= $locale->text('You can create warehouses and bins via the menu "System -> Warehouses".');
  } else {
    $msg .= $locale->text('Please ask your administrator to create warehouses and bins.');
  }

  $form->show_generic_error($msg);

  $main::lxdebug->leave_sub();
}

sub get_warehouse_idx {
  my ($warehouse_id) = @_;

  my $form     = $main::form;

  for (my $i = 0; $i < scalar @{$form->{WAREHOUSES}}; $i++) {
    return $i if ($form->{WAREHOUSES}->[$i]->{id} == $warehouse_id);
  }

  return -1;
}

sub get_bin_idx {
  my ($warehouse_index, $bin_id) = @_;

  my $form     = $main::form;

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_index];

  return -1 if (!$warehouse);

  for (my $i = 0; $i < scalar @{ $warehouse->{BINS} }; $i++) {
    return $i if ($warehouse->{BINS}->[$i]->{id} == $bin_id);
  }

  return -1;
}

sub new_item {
  $main::lxdebug->enter_sub();
  my %params = @_;

  my $form     = $main::form;

  # change callback
  $form->{old_callback} = $form->escape($form->{callback}, 1);
  $form->{callback}     = $form->escape("$form->{script}?action=$params{action}", 1);

  # save all form variables except action in a previousform variable
  my $previousform = join '&', map { my $value = $form->{$_}; $value =~ s/&/%26/; "$_=$value" } grep { !/action/ } keys %$form;
  my @HIDDENS = ();

#  push @HIDDENS,      { 'name' => 'previousform', 'value' => $form->escape($previousform, 1) };
  push @HIDDENS, map +{ 'name' => $_,             'value' => $form->{$_} }, qw(partnumber description unit vc sellprice ean);
  push @HIDDENS,      { 'name' => 'taxaccount2',  'value' => $form->{taxaccounts} };
  push @HIDDENS,      { 'name' => 'notes',        'value' => $form->{longdescription} };

  $form->header();
  print $form->parse_html_template("generic/new_item", { HIDDENS => [ sort { $a->{name} cmp $b->{name} } @HIDDENS ] } );

  $main::lxdebug->leave_sub();
}

sub update {
  my $form     = $main::form;
  call_sub($form->{update_nextsub} || $form->{nextsub});
}

sub continue {
  my $form     = $main::form;
  call_sub($form->{continue_nextsub} || $form->{nextsub});
}

sub stock {
  my $form     = $main::form;
  call_sub($form->{stock_nextsub} || $form->{nextsub});
}

sub setup_wh_transfer_warehouse_selection_action_bar {
  my ($action) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => $action } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_wh_transfer_warehouse_selection_assembly_action_bar {
  my ($action) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => 'transfer_assembly_update_part' } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Produce'),
        submit   => [ '#form', { action => 'create_assembly', show_allocations => 1 } ],
        disabled => $::form->{parts_id} ? undef : $::locale->text('No assembly has been selected yet.'),
      ],
    );
  }
}

sub setup_wh_create_assembly_chargenumbers_action_bar {
  my ($action) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => 'create_assembly', show_allocations => 1 } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Produce'),
        submit   => [ '#form', { action => 'create_assembly' } ],
        disabled => $::form->{parts_id} ? undef : $::locale->text('No assembly has been selected yet.'),
      ],
    );
  }
}

sub setup_wh_transfer_parts_action_bar {
  my ($action) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Transfer'),
        submit    => [ '#form', { action => 'transfer_parts' } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

sub setup_wh_removal_parts_selection_action_bar {
  my ($action) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Transfer out'),
        submit    => [ '#form', { action => 'remove_parts' } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

sub setup_wh_report_action_bar {
  my ($action) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#form', { action => 'generate_report' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_wh_journal_action_bar {
  my ($action) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#form', { action => 'generate_journal' } ],
        accesskey => 'enter',
      ],
    );
  }
}
sub setup_wh_journal_list_all_action_bar {
  my ($action) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [ t8('Actions') ],
        action => [
          t8('Disassemble Assembly'),
            submit => [ '#form', { action => 'disassemble_assembly' } ],
            checks => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
          ],
        ],
    );
  }
}


1;

__END__

=head1 NAME

bin/mozilla/wh.pl - Warehouse frontend.

=head1 FUNCTIONS

=over 4

=item new_item

call new item dialogue from warehouse masks.

PARAMS:
  action  => name of sub to be called when new item is done

=back

=cut
