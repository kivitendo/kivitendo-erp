#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger, Accounting
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Inventory Control module
#
#======================================================================

use POSIX qw(strftime);
use List::Util qw(first max);
use List::MoreUtils qw(any);

use SL::AM;
use SL::CVar;
use SL::IC;
use SL::Helper::Flash qw(flash);
use SL::HTML::Util;
use SL::Presenter::Part;
use SL::ReportGenerator;

#use SL::PE;

use strict;
#use warnings;

# global imports
our ($form, $locale, %myconfig, $lxdebug, $auth);

require "bin/mozilla/io.pl";
require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

1;

# Parserhappy(R):
# type=submit $locale->text('Add Part')
# type=submit $locale->text('Add Service')
# type=submit $locale->text('Add Assembly')
# type=submit $locale->text('Edit Part')
# type=submit $locale->text('Edit Service')
# type=submit $locale->text('Edit Assembly')
# $locale->text('Parts')
# $locale->text('Services')
# $locale->text('Inventory quantity must be zero before you can set this part obsolete!')
# $locale->text('Inventory quantity must be zero before you can set this assembly obsolete!')
# $locale->text('Part Number missing!')
# $locale->text('Service Number missing!')
# $locale->text('Assembly Number missing!')
# $locale->text('ea');

# end of main

sub search {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  $form->{revers}       = 0;  # switch for backward sorting
  $form->{lastsort}     = ""; # memory for which table was sort at last time
  $form->{ndxs_counter} = 0;  # counter for added entries to top100

  $form->{title} = (ucfirst $form->{searchitems}) . "s";
  $form->{title} =~ s/ys$/ies/;
  $form->{title} = $locale->text($form->{title});

  $form->{CUSTOM_VARIABLES}                  = CVar->get_configs('module' => 'IC');
  ($form->{CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $form->{CUSTOM_VARIABLES},
                                                                           'include_prefix' => 'l_',
                                                                           'include_value'  => 'Y');

  setup_ic_search_action_bar();
  $form->header;

  $form->get_lists('partsgroup'    => 'ALL_PARTSGROUPS');
  print $form->parse_html_template('ic/search');

  $lxdebug->leave_sub();
}    #end search()

sub top100 {
  $::lxdebug->enter_sub();

  $::auth->assert('part_service_assembly_edit');

  $::form->{l_soldtotal} = "Y";
  $::form->{sort}        = "soldtotal";
  $::form->{lastsort}    = "soldtotal";

  $::form->{l_qty}       = undef;
  $::form->{l_linetotal} = undef;
  $::form->{l_number}    = "Y";
  $::form->{number}      = "position";

  unless (   $::form->{bought}
          || $::form->{sold}
          || $::form->{rfq}
          || $::form->{quoted}) {
    $::form->{bought} = $::form->{sold} = 1;
  }

  generate_report();

  $lxdebug->leave_sub();
}

#
# Report for Wares.
# Warning, deep magic ahead.
# This function parses the requested details, sanity checks them, and converts them into a format thats usable for IC->all_parts
#
# flags coming from the form:
# hardcoded:
#  searchitems=part revers=0 lastsort=''
#
# filter:
# partnumber ean description partsgroup classification serialnumber make model drawing microfiche
# transdatefrom transdateto
#
# radio:
#  itemstatus = active | onhand | short | order_locked | obsolete | orphaned
#  action     = continue | top100
#
# checkboxes:
#  bought sold onorder ordered rfq quoted
#  l_partnumber l_description l_serialnumber l_unit l_listprice l_sellprice l_lastcost
#  l_linetotal l_priceupdate l_bin l_rop l_weight l_image l_drawing l_microfiche
#  l_partsgroup l_subtotal l_soldtotal l_deliverydate l_pricegroup l_bookinggroup
#
# hiddens:
#  nextsub revers lastsort sort ndxs_counter
#
sub generate_report {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  my ($revers, $lastsort, $description);

  my $cvar_configs = CVar->get_configs('module' => 'IC');

  $form->{title} = $locale->text('Articles');

  my %column_defs = (
    'deliverydate'       => { 'text' => $locale->text('deliverydate'), },
    'description'        => { 'text' => $locale->text('Part Description'), },
    'notes'              => { 'text' => $locale->text('Notes'), },
    'drawing'            => { 'text' => $locale->text('Drawing'), },
    'ean'                => { 'text' => $locale->text('EAN'), },
    'image'              => { 'text' => $locale->text('Image'), },
    'insertdate'         => { 'text' => $locale->text('Insert Date'), },
    'invnumber'          => { 'text' => $locale->text('Invoice Number'), },
    'lastcost'           => { 'text' => $locale->text('Last Cost'), },
    'assembly_lastcost'  => { 'text' => $locale->text('Assembly Last Cost'), },
    'linetotallastcost'  => { 'text' => $locale->text('Extended'), },
    'linetotallistprice' => { 'text' => $locale->text('Extended'), },
    'linetotalsellprice' => { 'text' => $locale->text('Extended'), },
    'listprice'          => { 'text' => $locale->text('List Price'), },
    'microfiche'         => { 'text' => $locale->text('Microfiche'), },
    'name'               => { 'text' => $locale->text('Name'), },
    'onhand'             => { 'text' => $locale->text('Stocked Qty'), },
    'assembly_qty'       => { 'text' => $locale->text('Assembly Item Qty'), },
    'ordnumber'          => { 'text' => $locale->text('Order Number'), },
    'partnumber'         => { 'text' => $locale->text('Part Number'), },
    'partsgroup'         => { 'text' => $locale->text('Partsgroup'), },
    'priceupdate'        => { 'text' => $locale->text('Price updated'), },
    'quonumber'          => { 'text' => $locale->text('Quotation'), },
    'rop'                => { 'text' => $locale->text('ROP'), },
    'sellprice'          => { 'text' => $locale->text('Sell Price'), },
    'serialnumber'       => { 'text' => $locale->text('Serial Number'), },
    'soldtotal'          => { 'text' => $locale->text('Qty in Selected Records'), },
    'name'               => { 'text' => $locale->text('Name in Selected Records'), },
    'transdate'          => { 'text' => $locale->text('Transdate Record'), },
    'unit'               => { 'text' => $locale->text('Unit'), },
    'weight'             => { 'text' => $locale->text('Weight'), },
    'shop'               => { 'text' => $locale->text('Shop article'), },
    'type_and_classific' => { 'text' => $locale->text('Type'), },
    'projectnumber'      => { 'text' => $locale->text('Project Number'), },
    'projectdescription' => { 'text' => $locale->text('Project Description'), },
    'warehouse'          => { 'text' => $locale->text('Default Warehouse'), },
    'bin'                => { 'text' => $locale->text('Default Bin'), },
    'make'               => { 'text' => $locale->text('Make'), },
    'model'              => { 'text' => $locale->text('Model'), },
    'price_factor_description' => { 'text' => $locale->text('Price Factor'), },
    'bookinggroup'       => { 'text' => $locale->text('Booking group'), },
  );

  $revers     = $form->{revers};
  $lastsort   = $form->{lastsort};

  # sorting and direction of sorting
  # ToDO: change this to the simpler field+direction method
  if (($form->{lastsort} eq "") && ($form->{sort} eq undef)) {
    $form->{revers}   = 0;
    $form->{lastsort} = "partnumber";
    $form->{sort}     = "partnumber";
  } else {
    if ($form->{lastsort} eq $form->{sort}) {
      $form->{revers} = 1 - $form->{revers};
    } else {
      $form->{revers} = 0;
      $form->{lastsort} = $form->{sort};
    }    #fi
  }    #fi

  # special case if we have a serialnumber limit search
  # serialnumbers are only given in invoices and orders,
  # so they can only pop up in bought, sold, rfq, and quoted stuff
  $form->{no_sn_joins} = 'Y' if (   !$form->{bought} && !$form->{sold}
                                 && !$form->{rfq}    && !$form->{quoted}
                                 && ($form->{l_serialnumber} || $form->{serialnumber}));

  # special case for any checkbox of bought | sold | onorder | ordered | rfq | quoted.
  # if any of these are ticked the behavior changes slightly for lastcost
  # since all those are aggregation checks for the legder tables this is an internal switch
  # refered to as ledgerchecks
  $form->{ledgerchecks} = 'Y' if (   $form->{bought} || $form->{sold} || $form->{onorder}
                                  || $form->{ordered} || $form->{rfq} || $form->{quoted});

  # if something should be activated if something else is active, enter it here
  my %dependencies = (
    onhand       => [ qw(l_onhand) ],
    short        => [ qw(l_onhand) ],
    onorder      => [ qw(l_ordnumber) ],
    ordered      => [ qw(l_ordnumber) ],
    rfq          => [ qw(l_quonumber) ],
    quoted       => [ qw(l_quonumber) ],
    bought       => [ qw(l_invnumber) ],
    sold         => [ qw(l_invnumber) ],
    ledgerchecks => [ qw(l_name) ],
    serialnumber => [ qw(l_serialnumber) ],
    no_sn_joins  => [ qw(bought sold) ],
  );

  # get name of partsgroup if id is given
  my $pg_name;
  if ($form->{partsgroup_id}) {
    my $pg = SL::DB::PartsGroup->new(id => $form->{partsgroup_id})->load;
    $pg_name = $pg->{'partsgroup'};
  }

  # these strings get displayed at the top of the results to indicate the user which switches were used
  my %optiontexts = (
    active        => $locale->text('Active'),
    obsolete      => $locale->text('Obsolete'),
    order_locked  => $locale->text('Do not order anymore'),
    orphaned      => $locale->text('Orphaned'),
    onhand        => $locale->text('On Hand'),
    assembly_qty  => $locale->text('Assembly Item Qty'),
    short         => $locale->text('Short'),
    onorder       => $locale->text('On Order'),
    ordered       => $locale->text('Ordered'),
    rfq           => $locale->text('RFQ'),
    quoted        => $locale->text('Quoted'),
    bought        => $locale->text('Bought'),
    sold          => $locale->text('Sold'),
    transdatefrom => $locale->text('From')       . " " . $locale->date(\%myconfig, $form->{transdatefrom}, 1),
    transdateto   => $locale->text('To (time)')  . " " . $locale->date(\%myconfig, $form->{transdateto}, 1),
    partnumber    => $locale->text('Part Number')      . ": '$form->{partnumber}'",
    partsgroup    => $locale->text('Partsgroup')       . ": '$form->{partsgroup}'",
    partsgroup_id => $locale->text('Partsgroup')       . ": '$pg_name'",
    serialnumber  => $locale->text('Serial Number')    . ": '$form->{serialnumber}'",
    description   => $locale->text('Part Description') . ": '$form->{description}'",
    make          => $locale->text('Make')             . ": '$form->{make}'",
    model         => $locale->text('Model')            . ": '$form->{model}'",
    customername  => $locale->text('Customer')         . ": '$form->{customername}'",
    customernumber=> $locale->text('Customer Part Number').": '$form->{customernumber}'",
    drawing       => $locale->text('Drawing')          . ": '$form->{drawing}'",
    microfiche    => $locale->text('Microfiche')       . ": '$form->{microfiche}'",
    l_soldtotal   => $locale->text('Qty in Selected Records'),
    ean           => $locale->text('EAN')              . ": '$form->{ean}'",
    insertdatefrom => $locale->text('Insert Date') . ": " . $locale->text('From')       . " " . $locale->date(\%myconfig, $form->{insertdatefrom}, 1),
    insertdateto   => $locale->text('Insert Date') . ": " . $locale->text('To (time)')  . " " . $locale->date(\%myconfig, $form->{insertdateto}, 1),
    l_service     => $locale->text('Services'),
    l_assembly    => $locale->text('Assemblies'),
    l_part        => $locale->text('Parts'),
  );

  my @itemstatus_keys = qw(active order_locked obsolete orphaned onhand short);
  my @callback_keys   = qw(onorder ordered rfq quoted bought sold partnumber partsgroup partsgroup_id serialnumber description make model
                           drawing microfiche l_soldtotal l_deliverydate transdatefrom transdateto insertdatefrom insertdateto ean shop all
                           l_service l_assembly l_part);

  # calculate dependencies
  for (@itemstatus_keys, @callback_keys) {
    next if ($form->{itemstatus} ne $_ && !$form->{$_});
    map { $form->{$_} = 'Y' } @{ $dependencies{$_} } if $dependencies{$_};
  }

  # generate callback and optionstrings
  my @options;
  for my  $key (@itemstatus_keys, @callback_keys) {
    next if ($form->{itemstatus} ne $key && !$form->{$key});
    push @options, $optiontexts{$key};
  }

  # special case for lastcost
  if ($form->{ledgerchecks}){
    # ledgerchecks don't know about sellprice or lastcost. they just return a
    # price. so rename sellprice to price, and drop lastcost.
    $column_defs{sellprice}{text} = $locale->text('Price');
    $form->{l_lastcost} = ""
  }
  $form->{l_assembly_lastcost} = "Y" if $form->{l_assembly} && $form->{l_lastcost};

  if ($form->{description}) {
    $description = $form->{description};
    $description =~ s/\n/<br>/g;
  }

  if ($form->{l_linetotal}) {
    $form->{l_qty} = "Y";
    $form->{l_linetotalsellprice} = "Y" if $form->{l_sellprice};
    $form->{l_linetotallastcost}  = $form->{searchitems} eq 'assembly' && !$form->{bom} ? "" : 'Y' if  $form->{l_lastcost};
    $form->{l_linetotallistprice} = "Y" if $form->{l_listprice};
  }
  $form->{"l_type_and_classific"} = "Y";

  if ($form->{l_service} && !$form->{l_assembly} && !$form->{l_part}) {

    # remove warehouse, bin, weight and rop from list
    map { $form->{"l_$_"} = "" } qw(bin weight rop warehouse);

    $form->{l_onhand} = "";

    # qty is irrelevant unless bought or sold
    if (   $form->{bought}
        || $form->{sold}
        || $form->{onorder}
        || $form->{ordered}
        || $form->{rfq}
        || $form->{quoted}) {
#      $form->{l_onhand} = "Y";
    } else {
      $form->{l_linetotalsellprice} = "";
      $form->{l_linetotallastcost}  = "";
    }
  }

  # soldtotal doesn't make sense with more than one bsooqr option.
  # so reset it to sold (the most common option), and issue a warning
  # ...
  # also it doesn't make sense without bsooqr. disable and issue a warning too
  my @bsooqr = qw(sold bought onorder ordered rfq quoted);
  my $bsooqr_mode = grep { $form->{$_} } @bsooqr;
  if ($form->{l_subtotal} && 1 < $bsooqr_mode) {
    my $enabled       = first { $form->{$_} } @bsooqr;
    $form->{$_}       = ''   for @bsooqr;
    $form->{$enabled} = 'Y';

    push @options, $::locale->text('Subtotal cannot distinguish betweens record types. Only one of the selected record types will be displayed: #1', $optiontexts{$enabled});
  }
  if ($form->{l_soldtotal} && !$bsooqr_mode) {
    delete $form->{l_soldtotal};

    flash('warning', $::locale->text('Soldtotal does not make sense without any bsooqr options'));
  }
  if ($form->{l_soldtotal} && ($form->{l_warehouse} || $form->{l_bin})) {
    delete $form->{"l_$_"} for  qw(bin warehouse);
    flash('warning', $::locale->text('Sorry, I am too stupid to figure out the default warehouse/bin and the sold qty. I drop the default warehouse/bin option.'));
  }
  if ($form->{l_name} && !$bsooqr_mode) {
    delete $form->{l_name};

    flash('warning', $::locale->text('Name does not make sense without any bsooqr options'));
  }
  IC->all_parts(\%myconfig, \%$form);

  my @columns = qw(
    partnumber type_and_classific description notes partsgroup warehouse bin
    make model assembly_qty onhand rop soldtotal unit price_factor_description listprice
    linetotallistprice sellprice linetotalsellprice lastcost assembly_lastcost linetotallastcost
    priceupdate weight image drawing microfiche invnumber ordnumber quonumber
    transdate name serialnumber deliverydate ean projectnumber projectdescription
    insertdate shop bookinggroup
  );

  my $pricegroups = SL::DB::Manager::Pricegroup->get_all_sorted;
  my @pricegroup_columns;
  my %column_defs_pricegroups;
  if ($form->{l_pricegroups}) {
    @pricegroup_columns      = map { "pricegroup_" . $_->id } @{ $pricegroups };
    %column_defs_pricegroups = map {
      "pricegroup_" . $_->id => {
        text    => $::locale->text('Pricegroup') . ' ' . $_->pricegroup,
        visible => 1,
      },
    }  @{ $pricegroups };
  }
  push @columns, @pricegroup_columns;

  my @includeable_custom_variables = grep { $_->{includeable} } @{ $cvar_configs };
  my @searchable_custom_variables  = grep { $_->{searchable} }  @{ $cvar_configs };
  my %column_defs_cvars            = map { +"cvar_$_->{name}" => { 'text' => $_->{description} } } @includeable_custom_variables;

  push @columns, map { "cvar_$_->{name}" } @includeable_custom_variables;

  %column_defs = (%column_defs, %column_defs_cvars, %column_defs_pricegroups);
  map { $column_defs{$_}->{visible} ||= $form->{"l_$_"} ? 1 : 0 } @columns;
  map { $column_defs{$_}->{align}   = 'right' } qw(assembly_qty onhand sellprice listprice lastcost assembly_lastcost linetotalsellprice linetotallastcost linetotallistprice rop weight soldtotal shop price_factor_description bookinggroup), @pricegroup_columns;

  my @hidden_variables = (
    qw(l_subtotal l_linetotal searchitems itemstatus bom l_pricegroups insertdatefrom insertdateto),
    qw(l_type_and_classific classification_id l_part l_service l_assembly l_assortment),
    @itemstatus_keys,
    @callback_keys,
    map({ "cvar_$_->{name}" } @searchable_custom_variables),
    map({'cvar_'. $_->{name} .'_from'} grep({$_->{type} eq 'date'} @searchable_custom_variables)),
    map({'cvar_'. $_->{name} .'_to'}   grep({$_->{type} eq 'date'} @searchable_custom_variables)),
    map({'cvar_'. $_->{name} .'_qtyop'} grep({$_->{type} eq 'number'} @searchable_custom_variables)),
    map({ "l_$_" } @columns),
  );

  my $callback         = build_std_url('action=generate_report', grep { $form->{$_} } @hidden_variables);

  my @sort_full        = qw(partnumber description onhand soldtotal deliverydate insertdate shop price_factor_description);
  my @sort_no_revers   = qw(partsgroup invnumber ordnumber quonumber name image drawing serialnumber);

  foreach my $col (@sort_full) {
    $column_defs{$col}->{link} = join '&', $callback, "sort=$col", map { "$_=" . E($form->{$_}) } qw(revers lastsort);
  }
  map { $column_defs{$_}->{link} = "${callback}&sort=$_" } @sort_no_revers;

  # add order to callback
  $form->{callback} = join '&', ($callback, map { "${_}=" . E($form->{$_}) } qw(sort revers));

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my %attachment_basenames = (
    'part'     => $locale->text('part_list'),
    'service'  => $locale->text('service_list'),
    'assembly' => $locale->text('assembly_list'),
    'article'  => $locale->text('article_list'),
  );

  $report->set_options('raw_top_info_text'     => $form->parse_html_template('ic/generate_report_top', { options => \@options }),
                       'raw_bottom_info_text'  => $form->parse_html_template('ic/generate_report_bottom' ,
                                                  { PART_CLASSIFICATIONS => SL::DB::Manager::PartClassification->get_all_sorted }),
                       'output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => 'article_list' . strftime('_%Y%m%d', localtime time),
  );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('generate_report', @hidden_variables, qw(sort revers));

  $report->set_sort_indicator($form->{sort}, $form->{revers} ? 0 : 1);

  CVar->add_custom_variables_to_report('module'         => 'IC',
                                       'trans_id_field' => 'id',
                                       'configs'        => $cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => $form->{parts});

  CVar->add_custom_variables_to_report('module'         => 'IC',
                                       'sub_module'     => sub { $_[0]->{ioi} },
                                       'trans_id_field' => 'ioi_id',
                                       'configs'        => $cvar_configs,
                                       'column_defs'    => \%column_defs,
                                       'data'           => $form->{parts});

  my @subtotal_columns = qw(sellprice listprice lastcost);
  my %subtotals = map { $_ => 0 } ('onhand', @subtotal_columns);
  my %totals    = map { $_ => 0 } @subtotal_columns;
  my $idx       = 0;
  my $same_item = @{ $form->{parts} } ? $form->{parts}[0]{ $form->{sort} } : undef;

  my $defaults  = AM->get_defaults();

  # postprocess parts
  foreach my $ref (@{ $form->{parts} }) {

    # fresh row, for inserting later
    my $row = { map { $_ => { 'data' => $ref->{$_} } } @columns };

    $ref->{exchangerate} ||= 1;
    $ref->{price_factor} ||= 1;
    $ref->{sellprice}     *= $ref->{exchangerate} / $ref->{price_factor};
    $ref->{listprice}     *= $ref->{exchangerate} / $ref->{price_factor};
    $ref->{lastcost}      *= $ref->{exchangerate} / $ref->{price_factor};
    $ref->{assembly_lastcost} *= $ref->{exchangerate} / $ref->{price_factor};

    # use this for assemblies
    my $soldtotal = $bsooqr_mode ? $ref->{soldtotal} : $ref->{onhand};

    if ($ref->{assemblyitem}) {
      $row->{partnumber}{align}   = 'right';
      $row->{soldtotal}{data}     = 0;
      $soldtotal                  = 0 if ($form->{sold});
    }

    my $edit_link               = build_std_url('script=controller.pl', 'action=Part/edit', 'part.id=' . E($ref->{id}));
    $row->{partnumber}->{link}  = $edit_link;
    $row->{description}->{link} = $edit_link;

    foreach (qw(sellprice listprice lastcost assembly_lastcost)) {
      $row->{$_}{data}            = $form->format_amount(\%myconfig, $ref->{$_}, 2);
      $row->{"linetotal$_"}{data} = $form->format_amount(\%myconfig, $ref->{onhand} * $ref->{$_}, 2);
    }
    foreach ( @pricegroup_columns ) {
      $row->{$_}{data}            = $form->format_amount(\%myconfig, $ref->{"$_"}, 2);
    };


    map { $row->{$_}{data} = $form->format_amount(\%myconfig, $ref->{$_}); } qw(onhand rop weight soldtotal);

    $row->{weight}->{data} .= ' ' . $defaults->{weightunit};

    # 'yes' and 'no' for boolean value shop
    if ($form->{l_shop}) {
      $row->{shop}{data} = $row->{shop}{data}? $::locale->text('yes') : $::locale->text('no');
    }

    if (!$ref->{assemblyitem}) {
      foreach my $col (@subtotal_columns) {
        $totals{$col}    += $soldtotal * $ref->{$col};
        $subtotals{$col} += $soldtotal * $ref->{$col};
      }

      $subtotals{soldtotal} += $soldtotal;
    }

    # set module stuff
    if ($ref->{module} eq 'oe') {
      # für oe gibt es vier fälle, jeweils nach kunde oder lieferant unterschiedlich:
      #
      # | ist bestellt  | Von Kunden bestellt |  -> edit_oe_ord_link
      # | Anfrage       | Angebot             |  -> edit_oe_quo_link

      my $edit_oe_ord_link = build_std_url("script=controller.pl", 'action=Order/edit',
                                           'type=' . E($ref->{cv} eq 'vendor' ? 'purchase_order' : 'sales_order'),        'id=' . E($ref->{trans_id}), 'callback');

      my $edit_oe_quo_link = build_std_url("script=controller.pl", 'action=Order/edit',
                                           'type=' . E($ref->{cv} eq 'vendor' ? 'request_quotation' : 'sales_quotation'), 'id=' . E($ref->{trans_id}), 'callback');

      $row->{ordnumber}{link} = $edit_oe_ord_link;
      $row->{quonumber}{link} = $edit_oe_quo_link if (!$ref->{ordnumber});

    } else {
      $row->{invnumber}{link} = build_std_url("script=$ref->{module}.pl", 'action=edit', 'type=invoice', 'id=' . E($ref->{trans_id}), 'callback') if ($ref->{invnumber});
    }

    # set properties of images
    if ($ref->{image} && (lc $report->{options}->{output_format} eq 'html')) {
      $row->{image}{data}     = '';
      $row->{image}{raw_data} = '<a href="' . H($ref->{image}) . '"><img src="' . H($ref->{image}) . '" height="32" border="0"></a>';
    }
    map { $row->{$_}{link} = $ref->{$_} } qw(drawing microfiche);

    $row->{notes}{data} = SL::HTML::Util->strip($ref->{notes});
    $row->{type_and_classific}{data} = SL::Presenter::Part::type_abbreviation($ref->{part_type}).
                                       SL::Presenter::Part::classification_abbreviation($ref->{classification_id});

    # last price update
    $row->{priceupdate}{data} = SL::DB::Part->new(id => $ref->{id})->load->last_price_update->valid_from->to_kivitendo;

    $report->add_data($row);

    my $next_ref = $form->{parts}[$idx + 1];

    # insert subtotal rows
    if (($form->{l_subtotal} eq 'Y') &&
        (!$next_ref ||
         (!$next_ref->{assemblyitem} && ($same_item ne $next_ref->{ $form->{sort} })))) {
      my $row = { map { $_ => { 'class' => 'listsubtotal', } } @columns };

      if ( !$form->{l_assembly} || !$form->{bom}) {
        $row->{soldtotal}->{data} = $form->format_amount(\%myconfig, $subtotals{soldtotal});
      }

      map { $row->{"linetotal$_"}->{data} = $form->format_amount(\%myconfig, $subtotals{$_}, 2) } @subtotal_columns;
      map { $subtotals{$_} = 0 } ('soldtotal', @subtotal_columns);

      $report->add_data($row);

      $same_item = $next_ref->{ $form->{sort} };
    }

    $idx++;
  }

  if ($form->{"l_linetotal"} && !$form->{report_generator_csv_options_for_import}) {
    my $row = { map { $_ => { 'class' => 'listtotal', } } @columns };

    map { $row->{"linetotal$_"}->{data} = $form->format_amount(\%myconfig, $totals{$_}, 2) } @subtotal_columns;

    $report->add_separator();
    $report->add_data($row);
  }

  setup_ic_generate_report_action_bar();
  $report->generate_with_headers();

  $lxdebug->leave_sub();
}    #end generate_report

sub setup_ic_search_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Search'),
        submit    => [ '#form', { action => 'generate_report' } ],
        accesskey => 'enter',
      ],

      action => [
        t8('TOP100'),
        submit => [ '#form', { action => 'top100' } ],
      ],
    );
  }
}

sub setup_ic_generate_report_action_bar {
  my %params = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Add'),
        ],
        action => [
          t8('Add Part'),
          submit    => [ '#new_form', { action => 'Part/add_part' } ],
          accesskey => 'enter',
        ],
        action => [
          t8('Add Service'),
          submit    => [ '#new_form', { action => 'Part/add_service' } ],
        ],
        action => [
          t8('Add Assembly'),
          submit    => [ '#new_form', { action => 'Part/add_assembly' } ],
        ],
        action => [
          t8('Add Assortment'),
          submit    => [ '#new_form', { action => 'Part/add_assortment' } ],
        ],
      ], # end of combobox "Add part"
    );
  }
}
