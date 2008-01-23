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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#######################################################################
#
# warehouse and packinglist
#
#######################################################################

use List::Util qw(min max first);
use POSIX qw(strftime);

use SL::Form;
use SL::User;

use SL::AM;
use SL::CT;
use SL::IC;
use SL::WH;
use SL::OE;
use SL::ReportGenerator;

use Data::Dumper;

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

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

# --------------------------------------------------------------------
# Transfer
# --------------------------------------------------------------------

sub transfer_warehouse_selection {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });

  show_no_warehouses_error() if (!scalar @{ $form->{WAREHOUSES} });

  my $units      = AM->retrieve_units(\%myconfig, $form, 'dimension');
  $form->{UNITS} = AM->unit_select_data($units, $form->{unit}, 0, $form->{partunit});

  if (scalar @{ $form->{WAREHOUSES} }) {
    $form->{warehouse_id} ||= $form->{WAREHOUSES}->[0]->{id};
    $form->{bin_id}       ||= $form->{WAREHOUSES}->[0]->{BINS}->[0]->{id};
  }

  my $content;

  $form->{jsscript} = 1;

  if ($form->{trans_type} eq 'removal') {
    $form->{nextsub} = "removal_parts_selection";
    $form->{title}   = $locale->text('Removal from Warehouse');
    $content         = $form->parse_html_template('wh/warehouse_selection');

  } elsif ($form->{trans_type} eq 'stock') {
    $form->{title} = $locale->text('Stock');
    $content       = $form->parse_html_template('wh/warehouse_selection_stock');

  } elsif (!$form->{trans_type} || ($form->{trans_type} eq 'transfer')) {
    $form->{nextsub} = "transfer_parts_selection";
    $form->{title}   = $locale->text('Transfer');
    $content         = $form->parse_html_template('wh/warehouse_selection');

  }

  $form->header();
  print $content;

  $lxdebug->leave_sub();
}

sub transfer_parts_selection {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  transfer_or_removal_prepare_contents('direction' => 'transfer');

  $form->{title} = $locale->text('Transfer');
  $form->header();
  print $form->parse_html_template("wh/transfer_parts_selection");

  $lxdebug->leave_sub();
}

sub transfer_or_removal_prepare_contents {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  my %args = @_;

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });

  my $warehouse_idx = get_warehouse_idx($form->{warehouse_id});
  $form->show_generic_error($locale->text("The selected warehouse does not exist.")) if (-1 == $warehouse_idx);

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_idx];

  $form->{initial_warehouse_idx} = $warehouse_idx;
  $form->{warehouse_description} = $warehouse->{description};
  $warehouse->{selected}         = 1;

  $form->show_generic_error($locale->text("The source warehouse does not contain any bins.")) if (0 == scalar @{ $warehouse->{BINS} });

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bindescription chargenumber partunit);

  $form->{sort} = 'bindescription';
  my @contents  = WH->get_warehouse_report("warehouse_id" => $form->{warehouse_id},
                                           "bin_id"       => $form->{bin_id},
                                           "chargenumber" => $form->{chargenumber},
                                           "partnumber"   => $form->{partnumber},
                                           "description"  => $form->{description});

  $form->show_generic_error($locale->text("The selected warehouse is empty.")) if (0 == scalar(@contents));

  my $all_units = AM->retrieve_units(\%myconfig, $form, 'dimension');

  foreach (@contents) {
    $_->{qty} = $form->format_amount_units('amount'     => $_->{qty},
                                           'part_unit'  => $_->{partunit},
                                           'conv_units' => 'convertible');
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

  $lxdebug->leave_sub();
}


sub transfer_parts {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  $form->get_lists('warehouses' => { 'key' => 'WAREHOUSES', 'bins' => 'BINS' });

  my $warehouse_idx = get_warehouse_idx($form->{warehouse_id});
  $form->show_generic_error($locale->text("The selected warehouse does not exist.")) if (-1 == $warehouse_idx);

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_idx];

  $form->show_generic_error($locale->text("The source warehouse does not contain any bins.")) if (0 == scalar @{ $warehouse->{BINS} });

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bindescription chargenumber partunit);

  $form->{sort} = 'bindescription';
  my @contents  = WH->get_warehouse_report("warehouse_id" => $form->{warehouse_id});
  my $all_units = AM->retrieve_units(\%myconfig, $form, 'dimension');

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

    map { $transfer->{$_} = $form->{"${_}_${row}"} } qw(src_bin_id chargenumber parts_id qty dst_warehouse_id dst_bin_id);

    my $entry;

    foreach (@contents) {
      if (($_->{binid} == $transfer->{src_bin_id}) && ($_->{parts_id} == $transfer->{parts_id}) && ($_->{chargenumber} eq $transfer->{chargenumber})) {
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
    $form->show_generic_information($locale->text('Nothing has been selected for transfer.'));
    exit 0;
  }

  WH->transfer(@transfers);

  $form->{trans_type}    = 'transfer';
  $form->{saved_message} = $locale->text('The parts have been transferred.');

  transfer_warehouse_selection();

  $lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Transfer: stock
# --------------------------------------------------------------------

sub transfer_stock_update_part {
  $lxdebug->enter_sub();

  $form->{trans_type} = 'stock';
  $form->{qty}        = $form->parse_amount(\%myconfig, $form->{qty});

  if (!$form->{partnumber} && !$form->{description}) {
    delete @{$form}{qw(parts_id partunit)};
    transfer_warehouse_selection();

  } elsif (($form->{partnumber} && ($form->{partnumber} ne $form->{old_partnumber})) || $form->{description}) {

    $form->{no_services}   = 1;
    $form->{no_assemblies} = 1;

    my $parts = Common->retrieve_parts(\%myconfig, $form, 'description', 1);

    if (scalar @{ $parts } == 1) {
      @{$form}{qw(parts_id partnumber description)} = @{$parts->[0]}{qw(id partnumber description)};
      transfer_stock_get_partunit();
      transfer_warehouse_selection();

    } else {
      select_part('transfer_stock_part_selected', @{ $parts });
    }

  } else {
    transfer_stock_get_partunit();
    transfer_warehouse_selection();
  }

  $lxdebug->leave_sub();
}

sub transfer_stock_part_selected {
  $lxdebug->enter_sub();

  my $part = shift;

  @{$form}{qw(parts_id partnumber description)} = @{$part}{qw(id partnumber description)};

  transfer_stock_get_partunit();
  transfer_warehouse_selection();

  $lxdebug->leave_sub();
}

sub transfer_stock_get_partunit {
  $lxdebug->enter_sub();

  if ($form->{parts_id}) {
    my $part_info     = IC->get_basic_part_info('id' => $form->{parts_id});
    $form->{partunit} = $part_info->{unit};
  }

  $lxdebug->leave_sub();
}

sub transfer_stock {
  $lxdebug->enter_sub();

  $form->{qty} = $form->parse_amount(\%myconfig, $form->{qty});

  if ($form->{qty} <= 0) {
    $form->show_generic_error($locale->text('Invalid quantity.'), 'back_button' => 1);
  }

  if (!$form->{warehouse_id} || !$form->{bin_id}) {
    $form->error($locale->text('The warehouse or the bin is missing.'));
  }

  my $transfer = {
    'transfer_type'    => 'stock',
    'dst_warehouse_id' => $form->{warehouse_id},
    'dst_bin_id'       => $form->{bin_id},
    'chargenumber'     => $form->{chargenumber},
    'parts_id'         => $form->{parts_id},
    'qty'              => $form->{qty},
    'unit'             => $form->{unit},
    'comment'          => $form->{comment},
  };

  WH->transfer($transfer);

  delete @{$form}{qw(parts_id partnumber description qty unit chargenumber comment)};

  $form->{saved_message} = $locale->text('The parts have been stocked.');
  $form->{trans_type}    = 'stock';

  transfer_warehouse_selection();

  $lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Transfer: removal
# --------------------------------------------------------------------

sub removal_parts_selection {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  transfer_or_removal_prepare_contents('direction' => 'out');

  $form->{title} = $locale->text('Removal');
  $form->header();
  print $form->parse_html_template("wh/removal_parts_selection");

  $lxdebug->leave_sub();
}

sub remove_parts {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });

  my $warehouse_idx = get_warehouse_idx($form->{warehouse_id});
  $form->show_generic_error($locale->text("The selected warehouse does not exist.")) if (-1 == $warehouse_idx);

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_idx];

  $form->show_generic_error($locale->text("The warehouse does not contain any bins.")) if (0 == scalar @{ $warehouse->{BINS} });

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bindescription chargenumber partunit);

  $form->{sort} = 'bindescription';
  my @contents  = WH->get_warehouse_report("warehouse_id" => $form->{warehouse_id});
  my $all_units = AM->retrieve_units(\%myconfig, $form, 'dimension');

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

    map { $transfer->{$_} = $form->{"${_}_${row}"} } qw(src_bin_id chargenumber parts_id qty);

    my $entry;

    foreach (@contents) {
      if (($_->{binid} == $transfer->{src_bin_id}) && ($_->{parts_id} == $transfer->{parts_id}) && ($_->{chargenumber} eq $transfer->{chargenumber})) {
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
    exit 0;
  }

  WH->transfer(@transfers);

  $form->{trans_type}    = 'removal';
  $form->{saved_message} = $locale->text('The parts have been removed.');

  transfer_warehouse_selection();

  $lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Journal
# --------------------------------------------------------------------

sub journal {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  $form->get_lists('warehouses' => { 'key'  => 'WAREHOUSES',
                                     'bins' => 'BINS', });

  show_no_warehouses_error() if (!scalar @{ $form->{WAREHOUSES} });

  $form->{jsscript} = 1;

  $form->header();
  print $form->parse_html_template("wh/journal_filter", { "UNITS" => AM->unit_select_data(AM->retrieve_units(\%myconfig, $form)) });

  $lxdebug->leave_sub();
}

sub generate_journal {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_management');

  $form->{title}   = $locale->text("WHJournal");
  $form->{sort}  ||= 'date';

  my %filter;
  my @columns = qw(trans_id date warehouse_from bin_from warehouse_to bin_to partnumber partdescription chargenumber trans_type comment qty employee projectnumber);

  # filter stuff
  map { $filter{$_} = $form->{$_} if ($form->{$_}) } qw(warehouse_id bin_id partnumber description chargenumber);

  $filter{qty_op} = WH->convert_qty_op($form->{qty_op});
  if ($filter{qty_op}) {
    $form->isblank(qty,      $locale->text('Quantity missing.'));
    $form->isblank(qty_unit, $locale->text('Unit missing.'));

    $filter{qty}      = $form->{qty};
    $filter{qty_unit} = $form->{qty_unit};
  }
  # /filter stuff

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, qw(warehouse_id bin_id partnumber description chargenumber qty_op qty qty_unit fromdate todate);

  my %column_defs = (
    'date'            => { 'text' => $locale->text('Date'), },
    'trans_id'        => { 'text' => $locale->text('Trans Id'), },
    'trans_type'      => { 'text' => $locale->text('Trans Type'), },
    'comment'         => { 'text' => $locale->text('Comment'), },
    'warehouse_from'  => { 'text' => $locale->text('Warehouse From'), },
    'warehouse_to'    => { 'text' => $locale->text('Warehouse To'), },
    'bin_from'        => { 'text' => $locale->text('Bin From'), },
    'bin_to'          => { 'text' => $locale->text('Bin To'), },
    'partnumber'      => { 'text' => $locale->text('Part Number'), },
    'partdescription' => { 'text' => $locale->text('Description'), },
    'chargenumber'    => { 'text' => $locale->text('Charge Number'), },
    'qty'             => { 'text' => $locale->text('Qty'), },
    'employee'        => { 'text' => $locale->text('Employee'), },
    'projectnumber'   => { 'text' => $locale->text('Project Number'), },
  );

  my $href = build_std_url('action=generate_journal', grep { $form->{$_} } @hidden_variables);
  map { $column_defs{$_}->{link} = $href . "&sort=${_}&order=" . Q($_ eq $form->{sort} ? 1 - $form->{order} : $form->{order}) } @columns;

  my %column_alignment = map { $_ => 'right' } qw(qty);

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('generate_journal', @hidden_variables);

  $report->set_sort_indicator($form->{sort}, $form->{order});

  $report->set_options('output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => strftime('warehouse_journal_%Y%m%d', localtime time));
  $report->set_options_from_form();

  my $all_units = AM->retrieve_units(\%myconfig, $form);
  my @contents  = WH->get_warehouse_journal(%filter);

  foreach $entry (@contents) {
    $entry->{qty}        = $form->format_amount_units('amount'     => $entry->{qty},
                                                      'part_unit'  => $entry->{partunit},
                                                      'conv_units' => 'convertible');
    $entry->{trans_type} = $locale->text($entry->{trans_type});

    my $row = { };

    foreach my $column (@columns) {
      next if ($column eq 'trans_type');

      $row->{$column} = {
        'data'  => $entry->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{trans_type} = {
      'raw_data' => $entry->{trans_type},
      'align'    => $column_alignment{trans_type},
    };

    $report->add_data($row);
  }

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Report
# --------------------------------------------------------------------

sub report {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_content | warehouse_management');

  $form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });

  show_no_warehouses_error() if (!scalar @{ $form->{WAREHOUSES} });

  $form->{onload} .= "fokus('partnumber');";
  $form->{title}   = $locale->text("Report about wareouse contents");

  $form->header();
  print $form->parse_html_template("wh/report_filter",
                                   { "nextsub"    => "generate_report",
                                     "WAREHOUSES" => $form->{WAREHOUSES},
                                     "UNITS"      => AM->unit_select_data(AM->retrieve_units(\%myconfig, $form)) });

  $lxdebug->leave_sub();
}

sub generate_report {
  $lxdebug->enter_sub();

  $auth->assert('warehouse_content | warehouse_management');

  $form->{title}   = $locale->text("Report about wareouse contents");
  $form->{sort}  ||= 'partnumber';
  my $sort_col     = $form->{sort};

  my %filter;
  my @columns = qw(warehousedescription bindescription partnumber partdescription chargenumber qty);

  # filter stuff
  map { $filter{$_} = $form->{$_} if ($form->{$_}) } qw(warehouse_id bin_id partnumber description chargenumber);

  $filter{qty_op} = WH->convert_qty_op($form->{qty_op});
  if ($filter{qty_op}) {
    $form->isblank(qty,      $locale->text('Quantity missing.'));
    $form->isblank(qty_unit, $locale->text('Unit missing.'));

    $filter{qty}      = $form->{qty};
    $filter{qty_unit} = $form->{qty_unit};
  }
  # /filter stuff

  $form->{subtotal} = '' if (!first { $_ eq $sort_col } qw(partnumber partdescription));

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, qw(warehouse_id bin_id partnumber description chargenumber qty_op qty qty_unit l_warehousedescription l_bindescription);
  push @hidden_variables, qw(include_empty_bins subtotal);

  my %column_defs = (
    'warehousedescription' => { 'text' => $locale->text('Warehouse'), },
    'bindescription'       => { 'text' => $locale->text('Bin'), },
    'partnumber'           => { 'text' => $locale->text('Part Number'), },
    'partdescription'      => { 'text' => $locale->text('Description'), },
    'chargenumber'         => { 'text' => $locale->text('Charge Number'), },
    'qty'                  => { 'text' => $locale->text('Qty'), },
  );

  my $href = build_std_url('action=generate_report', grep { $form->{$_} } @hidden_variables);
  map { $column_defs{$_}->{link} = $href . "&sort=${_}&order=" . Q($_ eq $sort_col ? 1 - $form->{order} : $form->{order}) } @columns;

  my %column_alignment = map { $_ => 'right' } qw(qty);

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('generate_report', @hidden_variables);

  $report->set_sort_indicator($sort_col, $form->{order});

  $report->set_options('output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => strftime('warehouse_report_%Y%m%d', localtime time));
  $report->set_options_from_form();

  my $all_units = AM->retrieve_units(\%myconfig, $form);
  my @contents  = WH->get_warehouse_report(%filter);

  my $subtotal  = 0;
  my $idx       = 0;

  foreach $entry (@contents) {
    $subtotal     += $entry->{qty};
    $entry->{qty}  = $form->format_amount_units('amount'     => $entry->{qty},
                                                'part_unit'  => $entry->{partunit},
                                                'conv_units' => 'convertible');

    $row_set = [ { map { $_ => { 'data' => $entry->{$_}, 'align' => $column_alignment{$_} } } @columns } ];

    if (($form->{subtotal} eq 'Y')
        && (($idx == (scalar @contents - 1))
            || ($entry->{$sort_col} ne $contents[$idx + 1]->{$sort_col}))) {

      my $row = { map { $_ => { 'data' => '', 'class' => 'listsubtotal', 'align' => $column_alignment{$_}, } } @columns };
      $row->{qty}->{data} = $form->format_amount_units('amount'     => $subtotal,
                                                       'part_unit'  => $entry->{partunit},
                                                       'conv_units' => 'convertible');
      $subtotal = 0;

      push @{ $row_set }, $row;
    }

    $report->add_data($row_set);

    $idx++;
  }

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Utility functions
# --------------------------------------------------------------------

sub show_no_warehouses_error {
  $lxdebug->enter_sub();

  my $msg = $locale->text('No warehouse has been created yet.') . ' ';

  if ($auth->check_right($form->{login}, 'config')) {
    $msg .= $locale->text('You can create warehouses and bins via the menu "System -> Warehouses".');
  } else {
    $msg .= $locale->text('Please ask your administrator to create warehouses and bins.');
  }

  $form->show_generic_error($msg);

  $lxdebug->leave_sub();
}

sub get_warehouse_idx {
  my ($warehouse_id) = @_;

  for (my $i = 0; $i < scalar @{$form->{WAREHOUSES}}; $i++) {
    return $i if ($form->{WAREHOUSES}->[$i]->{id} == $warehouse_id);
  }

  return -1;
}

sub get_bin_idx {
  my ($warehouse_index, $bin_id) = @_;

  my $warehouse = $form->{WAREHOUSES}->[$warehouse_index];

  return -1 if (!$warehouse);

  for (my $i = 0; $i < scalar @{ $warehouse->{BINS} }; $i++) {
    return $i if ($warehouse->{BINS}->[$i]->{id} == $bin_id);
  }

  return -1;
}

sub update {
  call_sub($form->{update_nextsub} || $form->{nextsub});
}

sub continue {
  call_sub($form->{continue_nextsub} || $form->{nextsub});
}

sub stock {
  call_sub($form->{stock_nextsub} || $form->{nextsub});
}

1;
