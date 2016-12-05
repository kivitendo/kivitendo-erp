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

  } elsif ($form->{trans_type} eq 'assembly') {
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

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bindescription chargenumber bestbefore partunit ean);

  $form->{sort} = 'bindescription';
  my @contents  = WH->get_warehouse_report("warehouse_id" => $form->{warehouse_id},
                                           "bin_id"       => $form->{bin_id},
                                           "chargenumber" => $form->{chargenumber},
                                           "bestbefore"   => $form->{bestbefore},
                                           "partnumber"   => $form->{partnumber},
                                           "ean"          => $form->{ean},
                                           "description"  => $form->{description});

  if (0 == scalar(@contents)) {
    $form->show_generic_error($locale->text("The selected warehouse is empty, or no stocked items where found that match the filter settings."));
  }

  my $all_units = AM->retrieve_units(\%myconfig, $form);

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

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bindescription chargenumber bestbefore partunit);

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

sub transfer_stock_update_part {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{trans_type} = 'stock';
  $form->{qty}        = $form->parse_amount(\%myconfig, $form->{qty});

  if (!$form->{partnumber} && !$form->{description} && !$form->{ean}) {
    delete @{$form}{qw(parts_id partunit ean)};
    transfer_warehouse_selection();

  } elsif (($form->{partnumber} && ($form->{partnumber} ne $form->{old_partnumber})) || $form->{description} || $form->{ean}) {

#    $form->{no_services}   = 1; # services may now be transfered. fix for Bug 1383.
    $form->{no_assemblies} = 0; # assemblies duerfen eingelagert werden (z.B. bei retouren)

    my $parts = Common->retrieve_parts(\%myconfig, $form, 'description', 1);

    if (!scalar @{ $parts }) {
      new_item(action => "transfer_stock_update_part");
    } elsif (scalar @{ $parts } == 1) {
      @{$form}{qw(parts_id partnumber description ean warehouse_id bin_id)} = @{$parts->[0]}{qw(id partnumber description ean warehouse_id bin_id)};
      transfer_stock_get_partunit();
      transfer_warehouse_selection();

    } else {
      select_part('transfer_stock_part_selected', @{ $parts });
    }

  } else {
    transfer_stock_get_partunit();
    transfer_warehouse_selection();
  }

  $main::lxdebug->leave_sub();
}

# --------------------------------------------------------------------
# Transfer: assemblies
# Dies ist die Auswahlmaske für ein assembly.
# Die ist einfach von transfer_assembly_update_part kopiert und nur um den trans_type (assembly) korrigiert worden
# Es wäre schön, hier nochmal check_assembly_max_create auf, um die max. Fertigungszahl herauszufinden.
# Ich lass das mal als auskommentierte Idee bestehen jb 18.3.09
# --------------------------------------------------------------------

sub transfer_assembly_update_part {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{trans_type} = 'assembly';
  $form->{qty}        = $form->parse_amount(\%myconfig, $form->{qty});

  if (!$form->{partnumber} && !$form->{description}) {
    delete @{$form}{qw(parts_id partunit)};
    transfer_warehouse_selection();

  } elsif (($form->{partnumber} && ($form->{partnumber} ne $form->{old_partnumber})) || $form->{description}) {
    $form->{assemblies} = 1;
    $form->{no_assemblies} = 0;
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

# hier die oben benannte idee
#    my $maxcreate = Common->check_assembly_max_create(assembly_id => $form->{parts_id}, dbh => $my_dbh);
  $main::lxdebug->leave_sub();
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

# vorüberlegung jb 22.2.2009
# wir benötigen für diese funktion, die anzahl die vom erzeugnis hergestellt werden soll. vielleicht direkt per js fehleingaben verhindern?
# ferner dann nochmal mit check_asssembly_max_create gegenprüfen und dann transaktionssicher wegbuchen.
# wir brauchen eine hilfsfunktion, die nee. brauchen wir nicht. der algorithmus läuft genau wie bei check max_create, nur dass hier auch eine lagerbewegung (verbraucht) stattfindet
# Manko ist derzeit noch, dass unterschiedliche Lagerplätze, bzw. das Quelllager an sich nicht ausgewählt werden können.
# Laut Absprache in KW11 09 übernimmt mb hier den rest im April ... jb 18.3.09

sub create_assembly {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $form->{qty} = $form->parse_amount(\%myconfig, $form->{qty});
  if ($form->{qty} <= 0) {
    $form->show_generic_error($locale->text('Invalid quantity.'), 'back_button' => 1);
  }
  # TODO Es wäre schön, hier schon die maximale Anzahl der zu fertigenden Erzeugnisse zu haben
  #else { if ($form->{qty} > $maxcreate) { #s.o.
  #     $form->show_generic_error($locale->text('Can not create that quantity with current stock'), 'back_button' => 1);
  #     $form->show_generic_error('Maximale Stückzahl' . $maxcreate , 'back_button' => 1);
  #   }
  #  }

  if (!$form->{warehouse_id} || !$form->{bin_id}) {
    $form->error($locale->text('The warehouse or the bin is missing.'));
  }

  if (!$::instance_conf->get_show_bestbefore) {
      $form->{bestbefore} = '';
  }

  # WIESO war das nicht vorher schon ein %HASH?? ein hash ist ein hash! das hat mich mehr als eine Stunde gekostet herauszufinden. grr. jb 3.3.2009
  # Anm. jb 18.3. vielleicht auch nur meine unwissenheit in perl-datenstrukturen
  my %TRANSFER = (
    'transfer_type'    => 'assembly',
    'login'            => $::myconfig{login},
    'dst_warehouse_id' => $form->{warehouse_id},
    'dst_bin_id'       => $form->{bin_id},
    'chargenumber'     => $form->{chargenumber},
    'bestbefore'       => $form->{bestbefore},
    'assembly_id'      => $form->{parts_id},
    'qty'              => $form->{qty},
    'unit'             => $form->{unit},
    'comment'          => $form->{comment}
  );

  my $ret = WH->transfer_assembly (%TRANSFER);
  # Frage: Ich pack in den return-wert auch gleich die Fehlermeldung. Irgendwelche Nummern als Fehlerkonstanten definieren find ich auch nicht besonders schick...
  # Ideen? jb 18.3.09
  if ($ret ne "1"){
    # Die locale-Funktion kann keine Double-Quotes escapen, deswegen hier erstmal so (ein wahrscheinlich immerwährender Hotfix) s.a. Frage davor jb 25.4.09
    $form->show_generic_error($ret, 'back_button' => 1);
  }

  delete @{$form}{qw(parts_id partnumber description qty unit chargenumber bestbefore comment)};

  $form->{saved_message} = $locale->text('The assembly has been created.');
  $form->{trans_type}    = 'assembly';

  transfer_warehouse_selection();

  $main::lxdebug->leave_sub();
}

sub transfer_stock {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

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
    'bestbefore'       => $form->{bestbefore},
    'parts_id'         => $form->{parts_id},
    'qty'              => $form->{qty},
    'unit'             => $form->{unit},
    'comment'          => $form->{comment},
  };

  WH->transfer($transfer);

  delete @{$form}{qw(parts_id partnumber description qty unit chargenumber bestbefore comment ean)};

  $form->{saved_message} = $locale->text('The parts have been stocked.');
  $form->{trans_type}    = 'stock';

  transfer_warehouse_selection();

  $main::lxdebug->leave_sub();
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

  map { $form->{"l_$_"} = 'Y' } qw(parts_id qty warehouseid binid partnumber partdescription bindescription chargenumber bestbefore partunit);

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

  $form->{title}   = $locale->text("WHJournal");
  $form->{sort}  ||= 'date';

  $form->{report_generator_output_format} = 'HTML' if !$form->{report_generator_output_format};

  my %filter;
  my @columns = qw(trans_id date warehouse_from bin_from warehouse_to bin_to partnumber partdescription chargenumber bestbefore trans_type comment qty employee oe_id projectnumber);

  # filter stuff
  map { $filter{$_} = $form->{$_} if ($form->{$_}) } qw(warehouse_id bin_id partnumber description chargenumber bestbefore);

  $filter{qty_op} = WH->convert_qty_op($form->{qty_op});
  if ($filter{qty_op}) {
    $form->isblank("qty",      $locale->text('Quantity missing.'));
    $form->isblank("qty_unit", $locale->text('Unit missing.'));

    $filter{qty}      = $form->{qty};
    $filter{qty_unit} = $form->{qty_unit};
  }
  # /filter stuff

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, qw(warehouse_id bin_id partnumber description chargenumber bestbefore qty_op qty qty_unit fromdate todate);

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
    'partdescription' => { 'text' => $locale->text('Part Description'), },
    'chargenumber'    => { 'text' => $locale->text('Charge Number'), },
    'bestbefore'      => { 'text' => $locale->text('Best Before'), },
    'qty'             => { 'text' => $locale->text('Qty'), },
    'unit'            => { 'text' => $locale->text('Part Unit'), },
    'partunit'        => { 'text' => $locale->text('Unit'), },
    'employee'        => { 'text' => $locale->text('Employee'), },
    'projectnumber'   => { 'text' => $locale->text('Project Number'), },
    'oe_id'           => { 'text' => $locale->text('Document'), },
  );

  my $href = build_std_url('action=generate_journal', grep { $form->{$_} } @hidden_variables);
  my $page = $::form->{page} || 1;
  map { $column_defs{$_}->{link} = $href ."&page=".$page. "&sort=${_}&order=" . Q($_ eq $form->{sort} ? 1 - $form->{order} : $form->{order}) } @columns;

  my %column_alignment = map { $_ => 'right' } qw(qty);

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

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
  my @contents  = WH->get_warehouse_journal(%filter);

  my %doc_types = ( 'sales_quotation'         => { script => 'oe', title => $locale->text('Sales quotation') },
                    'sales_order'             => { script => 'oe', title => $locale->text('Sales Order') },
                    'request_quotation'       => { script => 'oe', title => $locale->text('Request quotation') },
                    'purchase_order'          => { script => 'oe', title => $locale->text('Purchase Order') },
                    'sales_delivery_order'    => { script => 'do', title => $locale->text('Sales delivery order') },
                    'purchase_delivery_order' => { script => 'do', title => $locale->text('Purchase delivery order') },
                    'sales_invoice'           => { script => 'is', title => $locale->text('Sales Invoice') },
                    'purchase_invoice'        => { script => 'ir', title => $locale->text('Purchase Invoice') },
                  );

   my $allrows = 0;
   $allrows = 1 if $form->{report_generator_output_format} ne 'HTML' ;

   # manual paginating
   my $pages = {};
   $pages->{per_page}        = $::form->{per_page} || 15;
   my $first_nr = ($page - 1) * $pages->{per_page};
   my $last_nr  = $first_nr + $pages->{per_page};
   my $idx       = 0;

  foreach my $entry (@contents) {
    $entry->{qty}        = $form->format_amount_units('amount'     => $entry->{qty},
                                                      'part_unit'  => $entry->{partunit},
                                                      'conv_units' => 'convertible');
    $entry->{trans_type} = $locale->text($entry->{trans_type});

    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'  => $entry->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{trans_type}->{raw_data} = $entry->{trans_type};

    if ($form->{l_oe_id}) {
      $row->{oe_id}->{data} = '';
      my $info              = $entry->{oe_id_info};

      if ($info && $info->{id} && $info->{type} && $doc_types{$info->{type}}) {
        $row->{oe_id} = { data => $doc_types{ $info->{type} }->{title} . ' ' . $info->{number},
                          link => build_std_url('script=' . $doc_types{ $info->{type} }->{script} . '.pl', 'action=edit', 'id=' . $info->{id}, 'type=' . $info->{type}) };
      }
    }

    if ( $allrows || ($idx >= $first_nr && $idx < $last_nr )) {
       $report->add_data($row);
    }
    $idx++;
  }

  if ( ! $allrows ) {
      $pages->{max}  = SL::DB::Helper::Paginated::ceil($idx, $pages->{per_page}) || 1;
      $pages->{page} = $page < 1 ? 1: $page > $pages->{max} ? $pages->{max}: $page;
      $pages->{common} = [ grep { $_->{visible} } @{ SL::DB::Helper::Paginated::make_common_pages($pages->{page}, $pages->{max}) } ];

      $report->set_options('raw_bottom_info_text' => $form->parse_html_template('common/paginate',
                                                            { 'pages' => $pages , 'base_url' => $href}) );
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
                                     'bins'   => 'BINS', });

  show_no_warehouses_error() if (!scalar @{ $form->{WAREHOUSES} });

  $form->{title}   = $locale->text("Report about warehouse contents");

  $form->header();
  print $form->parse_html_template("wh/report_filter",
                                   { "nextsub"    => "generate_report",
                                     "WAREHOUSES" => $form->{WAREHOUSES},
                                     "UNITS"      => AM->unit_select_data(AM->retrieve_units(\%myconfig, $form)) });

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
  $form->{sort}  ||= 'partunit';
  my $sort_col     = $form->{sort};

  my %filter;
  my @columns = qw(warehousedescription bindescription partnumber partdescription chargenumber bestbefore qty stock_value);

  # filter stuff
  map { $filter{$_} = $form->{$_} if ($form->{$_}) } qw(warehouse_id bin_id partstypes_id partnumber description chargenumber bestbefore date include_invalid_warehouses);

  # show filter stuff also in report
  my @options;
  # dispatch all options
  my $dispatch_options = {
   warehouse_id   => sub { push @options, $locale->text('Warehouse') . " : " .
                                            SL::DB::Manager::Warehouse->find_by(id => $form->{warehouse_id})->description},
   bin_id         => sub { push @options, $locale->text('Bin') . " : " .
                                            SL::DB::Manager::Bin->find_by(id => $form->{bin_id})->description},
   partnumber     => sub { push @options, $locale->text('Partnumber')     . " : $form->{partnumber}"},
   description    => sub { push @options, $locale->text('Description')    . " : $form->{description}"},
   chargenumber   => sub { push @options, $locale->text('Charge Number')  . " : $form->{chargenumber}"},
   bestbefore     => sub { push @options, $locale->text('Best Before')    . " : $form->{bestbefore}"},
   date           => sub { push @options, $locale->text('Date')           . " : $form->{date}"},
   include_invalid_warehouses    => sub { push @options, $locale->text('Include invalid warehouses ')},
  };
  foreach (keys %filter) {
   $dispatch_options->{$_}->() if $dispatch_options->{$_};
  }
  # / end show filter stuff also in report

  $filter{qty_op} = WH->convert_qty_op($form->{qty_op});
  if ($filter{qty_op}) {
    $form->isblank("qty",      $locale->text('Quantity missing.'));
    $form->isblank("qty_unit", $locale->text('Unit missing.'));

    $filter{qty}      = $form->{qty};
    $filter{qty_unit} = $form->{qty_unit};
  }
  # /filter stuff

  $form->{subtotal} = '' if (!first { $_ eq $sort_col } qw(partnumber partdescription));

  $form->{report_generator_output_format} = 'HTML' if !$form->{report_generator_output_format};
  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, qw(warehouse_id bin_id partnumber partstypes_id description chargenumber bestbefore qty_op qty qty_unit partunit l_warehousedescription l_bindescription);
  push @hidden_variables, qw(include_empty_bins subtotal include_invalid_warehouses date);

  my %column_defs = (
    'warehousedescription' => { 'text' => $locale->text('Warehouse'), },
    'bindescription'       => { 'text' => $locale->text('Bin'), },
    'partnumber'           => { 'text' => $locale->text('Part Number'), },
    'partdescription'      => { 'text' => $locale->text('Part Description'), },
    'chargenumber'         => { 'text' => $locale->text('Charge Number'), },
    'bestbefore'           => { 'text' => $locale->text('Best Before'), },
    'qty'                  => { 'text' => $locale->text('Qty'), },
    'partunit'             => { 'text' => $locale->text('Unit'), },
    'stock_value'          => { 'text' => $locale->text('Stock value'), },
  );

  my $href = build_std_url('action=generate_report', grep { $form->{$_} } @hidden_variables);
  my $page = $::form->{page} || 1;
  map { $column_defs{$_}->{link} = $href . "&page=".$page."&sort=${_}&order=" . Q($_ eq $sort_col ? 1 - $form->{order} : $form->{order}) } @columns;

  my %column_alignment = map { $_ => 'right' } qw(qty stock_value);

  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

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

  my $all_units = AM->retrieve_units(\%myconfig, $form);
  my @contents  = WH->get_warehouse_report(%filter);

  my $idx       = 0;

  my @subtotals_columns = qw(qty stock_value);
  my %subtotals         = map { $_ => 0 } @subtotals_columns;

  my $total_stock_value = 0;

  my $allrows = 0;
  $allrows = 1 if $form->{report_generator_output_format} ne 'HTML' ;

  # manual paginating
  my $pages = {};
  $pages->{per_page}        = $::form->{per_page} || 20;
  my $first_nr = ($page - 1) * $pages->{per_page};
  my $last_nr  = $first_nr + $pages->{per_page};

  foreach my $entry (@contents) {
    map { $subtotals{$_} += $entry->{$_} } @subtotals_columns;
    $total_stock_value   += $entry->{stock_value} * 1;
    $entry->{qty}         = $form->format_amount(\%myconfig, $entry->{qty});
#    $entry->{qty}         = $form->format_amount_units('amount'     => $entry->{qty},
#                                                       'part_unit'  => $entry->{partunit},
#                                                       'conv_units' => 'convertible');
    $entry->{stock_value} = $form->format_amount(\%myconfig, $entry->{stock_value} * 1, 2);

    my $row_set = [ { map { $_ => { 'data' => $entry->{$_}, 'align' => $column_alignment{$_} } } @columns } ];

    if ( ($form->{subtotal} eq 'Y' && !$form->{report_generator_csv_options_for_import} )
        && (($idx == (scalar @contents - 1))
            || ($entry->{$sort_col} ne $contents[$idx + 1]->{$sort_col}))) {

      my $row = { map { $_ => { 'data' => '', 'class' => 'listsubtotal', 'align' => $column_alignment{$_}, } } @columns };
      $row->{qty}->{data}         = $form->format_amount(\%myconfig, $subtotals{qty});
#      $row->{qty}->{data}         = $form->format_amount_units('amount'     => $subtotals{qty} * 1,
#                                                               'part_unit'  => $entry->{partunit},
#                                                               'conv_units' => 'convertible');
      $row->{stock_value}->{data} = $form->format_amount(\%myconfig, $subtotals{stock_value} * 1, 2);

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
