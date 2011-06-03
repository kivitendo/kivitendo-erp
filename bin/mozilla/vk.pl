#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2001
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
#======================================================================
#
# Sales report
#
#======================================================================

use POSIX qw(strftime);
use List::Util qw(sum first);

use SL::VK;
use SL::IS;
use SL::ReportGenerator;
use Data::Dumper;

require "bin/mozilla/arap.pl";
require "bin/mozilla/common.pl";
require "bin/mozilla/drafts.pl";
require "bin/mozilla/reportgenerator.pl";

use strict;


sub search_invoice {
  $main::lxdebug->enter_sub();
  $main::auth->assert('general_ledger | invoice_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $main::cgi;

  my ($customer, $department);

  # setup customer selection
  $form->all_vc(\%myconfig, "customer", "AR");

  $form->{title}    = $locale->text('Sales Report');
  $form->{jsscript} = 1;

  $form->get_lists("projects"     => { "key" => "ALL_PROJECTS", "all" => 1 },
                   "departments"  => "ALL_DEPARTMENTS",
                   "customers"    => "ALL_VC");

  $form->{vc_keys}   = sub { "$_[0]->{name}--$_[0]->{id}" };

  $form->header;
  print $form->parse_html_template('vk/search_invoice', { %myconfig });

  $main::lxdebug->leave_sub();
}

sub invoice_transactions {
  $main::lxdebug->enter_sub();

  $main::auth->assert('general_ledger | invoice_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my ($callback, $href, @columns);

  if ( $form->{customer} =~ /--/ ) {
    # Felddaten kommen aus Dropdownbox
    ($form->{customername}, $form->{customer_id}) = split(/--/, $form->{customer});
  } elsif ($form->{customer}) {
    # es wurde ein Wert im Freitextfeld übergeben, auf Eindeutigkeit überprüfen

    # check_name wird mit no_select => 1 ausgeführt, ist die Abfrage nicht eindeutig kommt ein Fehler
    # und die Abfrage muß erneut ausgeführt werden

    # Ohne no_select kommt bei Auswahl des Kunden ein Aufruf von update der ins
    # Nichts führt, daher diese Zwischenlösung

    &check_name('customer', no_select => 1);
  
    # $form->{customer_id} wurde schon von check_name gesetzt
    $form->{customername} = $form->{customer};
  };
  # ist $form->{customer} leer passiert hier nichts weiter

  # decimalplaces überprüfen oder auf Default 2 setzen
  $form->{decimalplaces} = 2 unless $form->{decimalplaces} > 0 && $form->{decimalplaces} < 6;

#  report_generator_set_default_sort('transdate', 1);

  VK->invoice_transactions(\%myconfig, \%$form);

  # anhand von radio button die Sortierreihenfolge festlegen
  if ($form->{sortby} eq 'artikelsort') {
    $form->{'mainsort'} = 'parts_id';
    $form->{'subsort'}  = 'name';
  } else {
    $form->{'mainsort'} = 'name';
    $form->{'subsort'}  = 'parts_id';
  };

  $form->{title} = $locale->text('Sales Report');

  @columns =
    qw(description invnumber transdate customernumber partnumber transdate qty unit sellprice sellprice_total discount lastcost lastcost_total marge_total marge_percent);

  # hidden variables für pdf/csv export übergeben
  # einmal mit l_ um zu bestimmen welche Spalten ausgegeben werden sollen
  # einmal optionen für die Überschrift (z.B. transdatefrom, partnumber, ...)
  my @hidden_variables  = (qw(l_headers l_subtotal l_total l_customernumber transdatefrom transdateto decimalplaces customer customername customer_id department partnumber description project_id customernumber), "$form->{db}number", map { "l_$_" } @columns);
  my @hidden_nondefault = grep({ $form->{$_} } @hidden_variables);
  # Variablen werden dann als Hidden Variable mitgegeben, z.B.
  # <input type="hidden" name="report_generator_hidden_transdateto" value="21.05.2010">

  $href = build_std_url('action=invoice_transactions', grep { $form->{$_} } @hidden_variables);
  # href = vk.pl?action=invoice_transactions&l_headers=Y&l_subtotal=Y&l_total=Y&transdatefrom=04.03.2010 ...

  my %column_defs = (
    'description'             => { 'text' => $locale->text('Description'), },
    'partnumber'              => { 'text' => $locale->text('Part Number'), },
    'invnumber'               => { 'text' => $locale->text('Invoice Number'), },
    'transdate'               => { 'text' => $locale->text('Invoice Date'), },
    'qty'                     => { 'text' => $locale->text('Quantity'), },
    'unit'                    => { 'text' => $locale->text('Unit'), },
    'sellprice'               => { 'text' => $locale->text('Sales price'), },
    'sellprice_total'         => { 'text' => $locale->text('Sales net amount'), },
    'lastcost_total'          => { 'text' => $locale->text('Purchase net amount'), },
    'discount'                => { 'text' => $locale->text('Discount'), },
    'lastcost'                => { 'text' => $locale->text('Purchase price'), },
    'marge_total'             => { 'text' => $locale->text('Sales margin'), },
    'marge_percent'           => { 'text' => $locale->text('Sales margin %'), },
    'customernumber'          => { 'text' => $locale->text('Customer Number'), },
  );

  my %column_alignment = map { $_ => 'right' } qw(lastcost sellprice sellprice_total lastcost_total unit discount marge_total marge_percent qty);

  $form->{"l_type"} = "Y";
  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;


  my @options;
  if ($form->{description}) {
    push @options, $locale->text('Description') . " : $form->{description}";
  }
  if ($form->{customer}) {
    push @options, $locale->text('Customer') . " : $form->{customername}";
  }
  if ($form->{customernumber}) {
    push @options, $locale->text('Customer Number') . " : $form->{customernumber}";
  }
  if ($form->{department}) {
    my ($department) = split /--/, $form->{department};
    push @options, $locale->text('Department') . " : $department";
  }
  if ($form->{invnumber}) {
    push @options, $locale->text('Invoice Number') . " : $form->{invnumber}";
  }
  if ($form->{invdate}) {
    push @options, $locale->text('Invoice Date') . " : $form->{invdate}";
  }
  if ($form->{partnumber}) {
    push @options, $locale->text('Part Number') . " : $form->{partnumber}";
  }
  if ($form->{ordnumber}) {
    push @options, $locale->text('Order Number') . " : $form->{ordnumber}";
  }
  if ($form->{notes}) {
    push @options, $locale->text('Notes') . " : $form->{notes}";
  }
  if ($form->{transaction_description}) {
    push @options, $locale->text('Transaction description') . " : $form->{transaction_description}";
  }
  if ($form->{transdatefrom}) {
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
  }
  if ($form->{transdateto}) {
    push @options, $locale->text('Bis') . " " . $locale->date(\%myconfig, $form->{transdateto}, 1);
  }

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  $report->set_options('top_info_text'        => join("\n", @options),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('Sales Report') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('invoice_transactions', @hidden_variables, qw(mainsort sortdir));

  $report->set_sort_indicator($form->{mainsort}, $form->{sortdir});

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{mainsort}";

  # escape callback for href
  $callback = $form->escape($href);

  my @subtotal_columns = qw(qty sellprice sellprice_total lastcost lastcost_total marge_total marge_percent discount);
  # Gesamtsumme:
  # Summe von sellprice_total, lastcost_total und marge_total
  # Durchschnitt von marge_percent
  my @total_columns = qw(sellprice_total lastcost_total marge_total marge_percent );

  my %totals    = map { $_ => 0 } @total_columns;
  my %subtotals1 = map { $_ => 0 } @subtotal_columns;
  my %subtotals2 = map { $_ => 0 } @subtotal_columns;

  my $idx = 0;

  foreach my $ar (@{ $form->{AR} }) {

    $ar->{price_factor} = 1 unless $ar->{price_factor};
    # calculate individual sellprice
    # discount was already accounted for in db sellprice
    $ar->{sellprice} = $ar->{sellprice} / $ar->{price_factor};
    $ar->{lastcost} = $ar->{lastcost} / $ar->{price_factor};
    $ar->{sellprice_total} = $ar->{qty} * $ar->{sellprice};
    $ar->{lastcost_total}  = $ar->{qty} * $ar->{lastcost};
    # marge_percent wird neu berechnet, da Wert in invoice leer ist (Bug)
    $ar->{marge_percent} = $ar->{sellprice_total} ? (($ar->{sellprice_total}-$ar->{lastcost_total}) / $ar->{sellprice_total}) : 0;
    # marge_total neu berechnen
    $ar->{marge_total} = $ar->{sellprice_total} ? $ar->{sellprice_total}-$ar->{lastcost_total}  : 0;
    $ar->{discount} *= 100;  # für Ausgabe formatieren, 10% stored as 0.1 in db

    # Anfangshauptüberschrift
    if ( $form->{l_headers} eq "Y" && ( $idx == 0 or $ar->{ $form->{'mainsort'} } ne $form->{AR}->[$idx - 1]->{ $form->{'mainsort'} } )) {
      my $name;
      my $headerrow;
      if ( $form->{mainsort} eq 'parts_id' ) {
        $headerrow->{description}->{data} = "$ar->{description}";
      } else {
        $headerrow->{description}->{data} = "$ar->{name}";
      };
      $headerrow->{description}->{class} = "listmainsortheader";
      my $headerrow_set = [ $headerrow ];
      $report->add_data($headerrow_set);

      # add empty row after main header
#      my $emptyheaderrow->{description}->{data} = "";
#      $emptyheaderrow->{description}->{class} = "listmainsortheader";
#      my $emptyheaderrow_set = [ $emptyheaderrow ];
#      $report->add_data($emptyheaderrow_set) if $form->{l_headers} eq "Y";
    };

    # subsort überschriften
    if ( $idx == 0
      or $ar->{ $form->{'subsort'} }  ne $form->{AR}->[$idx - 1]->{ $form->{'subsort'} }
      or $ar->{ $form->{'mainsort'} } ne $form->{AR}->[$idx - 1]->{ $form->{'mainsort'} }
    ) {
      my $headerrow;
      my $name;
      if ( $form->{subsort} eq 'parts_id' ) {
        $name = 'description';
        $headerrow->{description}->{data} = "$ar->{$name}";
      } else {
        $name = 'name';
        $headerrow->{description}->{data} = "$ar->{$name}";
      };
      $headerrow->{description}->{class} = "listsubsortheader";
      my $headerrow_set = [ $headerrow ];
      $report->add_data($headerrow_set) if $form->{l_headers} eq "Y";
    };

    map { $subtotals1{$_} += $ar->{$_};
          $subtotals2{$_} += $ar->{$_};
        } @subtotal_columns;

    map { $totals{$_}    += $ar->{$_} } @total_columns;

    $subtotals2{sellprice} = $subtotals2{sellprice_total} / $subtotals2{qty} if $subtotals2{qty} != 0;
    $subtotals1{sellprice} = $subtotals1{sellprice_total} / $subtotals1{qty} if $subtotals1{qty} != 0;
    $subtotals2{lastcost} = $subtotals2{lastcost_total} / $subtotals2{qty} if $subtotals2{qty} != 0;
    $subtotals1{lastcost} = $subtotals1{lastcost_total} / $subtotals1{qty} if $subtotals1{qty} != 0;

    # Ertrag prozentual in den Summen: (summe VK - summe Ertrag) / summe VK
    $subtotals1{marge_percent} = $subtotals1{sellprice_total} ? (($subtotals1{sellprice_total} - $subtotals1{lastcost_total}) / $subtotals1{sellprice_total}) : 0;
    $subtotals2{marge_percent} = $subtotals2{sellprice_total} ? (($subtotals2{sellprice_total} - $subtotals2{lastcost_total}) / $subtotals2{sellprice_total}) : 0;

    # Ertrag prozentual:  (Summe VK betrag - Summe EK betrag) / Summe VK betrag
    # wird laufend bei jeder Position neu berechnet
    $totals{marge_percent}    = $totals{sellprice_total}    ? ( ($totals{sellprice_total} - $totals{lastcost_total}) / $totals{sellprice_total}   ) : 0;

    map { $ar->{$_} = $form->format_amount(\%myconfig, $ar->{$_}, 2) } qw(marge_total marge_percent);
    map { $ar->{$_} = $form->format_amount(\%myconfig, $ar->{$_}, $form->{"decimalplaces"} )} qw(lastcost sellprice sellprice_total lastcost_total);

    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'  => $ar->{$column},
        'align' => $column_alignment{$column},
      };
    }

   $row->{description}->{class} = 'listsortdescription';

    $row->{invnumber}->{link} = build_std_url("script=is.pl", 'action=edit')
      . "&id=" . E($ar->{id}) . "&callback=${callback}";

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{AR} } - 1))   # last element always has a subtotal
          || ($ar->{ $form->{'subsort'} } ne $form->{AR}->[$idx + 1]->{ $form->{'subsort'}   })
          || ($ar->{ $form->{'mainsort'} } ne $form->{AR}->[$idx + 1]->{ $form->{'mainsort'} })
          )) {   # if value that is sorted by changes, print subtotal
      my $name;
      if ( $form->{subsort} eq 'parts_id' ) {
        $name = 'description';
      } else {
        $name = 'name';
      };

      if ($form->{l_subtotal} eq 'Y') {
        push @{ $row_set }, create_subtotal_row_invoice(\%subtotals2, \@columns, \%column_alignment, \@subtotal_columns, 'listsubsortsubtotal', $ar->{$name}) ;
        push @{ $row_set }, insert_empty_row();
      };
    }

    # if mainsort has changed, add mainsort subtotal and empty row
    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{AR} } - 1))   # last element always has a subtotal
            || ($ar->{ $form->{'mainsort'} } ne $form->{AR}->[$idx + 1]->{ $form->{'mainsort'} })
            )) {   # if value that is sorted by changes, print subtotal
      my $name;
      if ( $form->{mainsort} eq 'parts_id' ) {
        $name = 'description';
      } else {
        $name = 'name';
      };
      if ($form->{l_subtotal} eq 'Y' ) {
        push @{ $row_set }, create_subtotal_row_invoice(\%subtotals1, \@columns, \%column_alignment, \@subtotal_columns, 'listmainsortsubtotal', $ar->{$name});
        push @{ $row_set }, insert_empty_row();
      };
    }

    $report->add_data($row_set);

    $idx++;
  }
  if ( $form->{l_total} eq "Y" ) {
    $report->add_separator();
    $report->add_data(create_subtotal_row_invoice(\%totals, \@columns, \%column_alignment, \@total_columns, 'listtotal'))
  };

  $report->generate_with_headers();
  $main::lxdebug->leave_sub();
}


sub insert_empty_row {
    my $dummyrow;
    $dummyrow->{description}->{data} = "";
    my $dummyrowset = [ $dummyrow ];
    return $dummyrow;
};



sub create_subtotal_row_invoice {
  $main::lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class, $name) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  $row->{description}->{data} = "Summe " . $name;

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } qw(marge_total marge_percent);
  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 0) } qw(qty);
  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, $form->{decimalplaces}) } qw(lastcost sellprice sellprice_total lastcost_total);


  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $main::lxdebug->leave_sub();

  return $row;
}

1;

