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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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

sub add {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  my $title                = 'Add ' . ucfirst $form->{item};
  $form->{title}           = $locale->text($title);
  $form->{callback}        = "$form->{script}?action=add&item=$form->{item}" unless $form->{callback};
  $form->{unit_changeable} = 1;

  IC->get_pricegroups(\%myconfig, \%$form);
  &link_part;
  &display_form;

  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  $form->{revers}       = 0;  # switch for backward sorting
  $form->{lastsort}     = ""; # memory for which table was sort at last time
  $form->{ndxs_counter} = 0;  # counter for added entries to top100

  my %is_xyz     = map { +"is_$_" => ($form->{searchitems} eq $_) } qw(part service assembly);

  $form->{title} = (ucfirst $form->{searchitems}) . "s";
  $form->{title} = $locale->text($form->{title});
  $form->{title} = $locale->text('Assemblies') if ($is_xyz{is_assembly});

  $form->{CUSTOM_VARIABLES}                  = CVar->get_configs('module' => 'IC');
  ($form->{CUSTOM_VARIABLES_FILTER_CODE},
   $form->{CUSTOM_VARIABLES_INCLUSION_CODE}) = CVar->render_search_options('variables'      => $form->{CUSTOM_VARIABLES},
                                                                           'include_prefix' => 'l_',
                                                                           'include_value'  => 'Y');

  $form->header;

  $form->get_lists('partsgroup'    => 'ALL_PARTSGROUPS');
  print $form->parse_html_template('ic/search', { %is_xyz, });

  $lxdebug->leave_sub();
}    #end search()

sub search_update_prices {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  my $pricegroups = IC->get_pricegroups(\%myconfig, \%$form);

  $form->{title} = $locale->text('Update Prices');

  $form->header;

  print $form->parse_html_template('ic/search_update_prices', { PRICE_ROWS => $pricegroups });

  $lxdebug->leave_sub();
}    #end search()

sub confirm_price_update {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  my @errors      = ();
  my $value_found = undef;

  foreach my $idx (qw(sellprice listprice), (1..$form->{price_rows})) {
    my $name      = $idx =~ m/\d/ ? $form->{"pricegroup_${idx}"}      : $idx eq 'sellprice' ? $locale->text('Sell Price') : $locale->text('List Price');
    my $type      = $idx =~ m/\d/ ? $form->{"pricegroup_type_${idx}"} : $form->{"${idx}_type"};
    my $value_idx = $idx =~ m/\d/ ? "price_${idx}" : $idx;
    my $value     = $form->parse_amount(\%myconfig, $form->{$value_idx});

    if ((0 > $value) && ($type eq 'percent')) {
      push @errors, $locale->text('You cannot adjust the price for pricegroup "#1" by a negative percentage.', $name);

    } elsif (!$value && ($form->{$value_idx} ne '')) {
      push @errors, $locale->text('No valid number entered for pricegroup "#1".', $name);

    } elsif (0 < $value) {
      $value_found = 1;
    }
  }

  push @errors, $locale->text('No prices will be updated because no prices have been entered.') if (!$value_found);

  my $num_matches = IC->get_num_matches_for_priceupdate();

  $form->header();

  if (@errors) {
    $form->show_generic_error(join('<br>', @errors), 'back_button' => 1);
  }

  $form->{nextsub} = "update_prices";

  map { delete $form->{$_} } qw(action header);

  print $form->parse_html_template('ic/confirm_price_update', { HIDDENS     => [ map { name => $_, value => $form->{$_} }, keys %$form ],
                                                                num_matches => $num_matches });

  $lxdebug->leave_sub();
}

sub update_prices {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  my $num_updated = IC->update_prices(\%myconfig, \%$form);

  if (-1 != $num_updated) {
    $form->redirect($locale->text('#1 prices were updated.', $num_updated));
  } else {
    $form->error($locale->text('Could not update prices!'));
  }

  $lxdebug->leave_sub();
}

#sub choice {
#  $lxdebug->enter_sub();
#
#  $auth->assert('part_service_assembly_edit');
#
#  our ($j, $lastndx);
#  my ($totop100);
#
#  $form->{title} = $locale->text('Top 100 hinzufuegen');
#
#  $form->header;
#
#  push @custom_hiddens, qw(searchitems title bom titel revers lastsort sort ndxs_counter extras);
#  push @custom_hiddens, qw(itemstatus l_linetotal l_partnumber l_description l_onhand l_unit l_sellprice l_linetotalsellprice);
#  my @HIDDENS = (
#        +{ name => 'row',     value => $j              },
#        +{ name => 'nextsub', value => 'item_selected' },
#        +{ name => 'test',    value => 'item_selected' },
#        +{ name => 'lastndx', value => $lastndx        },
#    map(+{ name => $_,        value => $form->{$_}     }, @custom_hiddens),
#  );
#
#  my ($partnumber, $description, $unit, $sellprice, $soldtotal);
#  # if choice set data
##  if ($form->{ndx}) {
##    for my $i (0 .. $form->{ndxs_counter}) {
##
##      # insert data into top100
##      push @{ $form->{parts} },
##        { number      => "",
##          partnumber  => $form->{"totop100_partnumber_$j"},
##          description => $form->{"totop100_description_$j"},
##          unit        => $form->{"totop100_unit_$j"},
##          sellprice   => $form->{"totop100_sellprice_$j"},
##          soldtotal   => $form->{"totop100_soldtotal_$j"},
##        };
##    }    #rof
##  }    #fi
#
#  $totop100 = "";
#
#  # set data for next page
#  for my $i (1 .. $form->{ndxs_counter}) {
#    $partnumber  = $form->{"totop100_partnumber_$i"};
#    $description = $form->{"totop100_description_$i"};
#    $unit        = $form->{"totop100_unit_$i"};
#    $sellprice   = $form->{"totop100_sellprice_$i"};
#    $soldtotal   = $form->{"totop100_soldtotal_$i"};
#
#  push @PARTS, {
#    totop100_partnumber  => $form->{"totop100_partnumber_$i"},
#    totop100_description => $form->{"totop100_description_$i"},
#    totop100_unit        => $form->{"totop100_unit_$i"},
#    totop100_sellprice   => $form->{"totop100_sellprice_$i"},
#    totop100_soldtotal   => $form->{"totop100_soldtotal_$i"},
#  }
#
##    $totop100 .= qq|
##<input type=hidden name=totop100_partnumber_$i value=$form->{"totop100_partnumber_$i"}>
##<input type=hidden name=totop100_description_$i value=$form->{"totop100_description_$i"}>
##<input type=hidden name=totop100_unit_$i value=$form->{"totop100_unit_$i"}>
##<input type=hidden name=totop100_sellprice_$i value=$form->{"totop100_sellprice_$i"}>
##<input type=hidden name=totop100_soldtotal_$i value=$form->{"totop100_soldtotal_$i"}>
##    |;
#  }    #rof
#
#  print $form->parse_html_template('ic/choice', +{ HIDDENS => \@HIDDENS, PARTS => \@PARTS });
#
#  $lxdebug->leave_sub();
#}    #end choice

#sub list {
#  $lxdebug->enter_sub();
#
#  $auth->assert('part_service_assembly_edit');
#
#  our ($lastndx);
#  our ($partnumber, $description, $unit, $sellprice, $soldtotal);
#
#  my @sortorders = ("", "partnumber", "description", "all");
#  my $sortorder = $sortorders[($form->{description} ? 2 : 0) + ($form->{partnumber} ? 1 : 0)];
#  IC->get_parts(\%myconfig, \%$form, $sortorder);
#
#  $form->{title} = $locale->text('Top 100 hinzufuegen');
#
#  $form->header;
#
#  print qq|
#  <h1>| . $locale->text('choice part') . qq|</h1>
#  <form method=post action=ic.pl>
#    <table width=100%>
#        <tr class=listheading>
#          <th>&nbsp;</th>
#          <th class=listheading>| . $locale->text('Part Number') . qq|</th>
#          <th class=listheading>| . $locale->text('Part Description') . qq|</th>
#          <th class=listheading>| . $locale->text('Unit of measure') . qq|</th>
#          <th class=listheading>| . $locale->text('Sell Price') . qq|</th>
#          <th class=listheading>| . $locale->text('soldtotal') . qq|</th>
#        </tr>|;
#
#  my $j = 0;
#  my $i = $form->{rows};
#
#  for ($j = 1; $j <= $i; $j++) {
#
#    print qq|
#        <tr class=listrow| . ($j % 2) . qq|>|;
#    if ($j == 1) {
#      print qq|
#            <td><input name=ndx class=radio type=radio value=$j checked></td>|;
#    } else {
#      print qq|
#          <td><input name=ndx class=radio type=radio value=$j></td>|;
#    }
#    print qq|
#          <td><input name="new_partnumber_$j" type=hidden value="$form->{"partnumber_$j"}">$form->{"partnumber_$j"}</td>
#          <td><input name="new_description_$j" type=hidden value="$form->{"description_$j"}">$form->{"description_$j"}</td>
#          <td><input name="new_unit_$j" type=hidden value="$form->{"unit_$j"}">$form->{"unit_$j"}</td>
#          <td><input name="new_sellprice_$j" type=hidden value="$form->{"sellprice_$j"}">$form->{"sellprice_$j"}</td>
#          <td><input name="new_soldtotal_$j" type=hidden value="$form->{"soldtotal_$j"}">$form->{"soldtotal_$j"}</td>
#        </tr>
#
#        <input name="new_id_$j" type=hidden value="$form->{"id_$j"}">|;
#  }
#
#  print qq|
#
#</table>
#
#<br>
#
#
#<input type=hidden name=itemstatus value="$form->{itemstatus}">
#<input type=hidden name=l_linetotal value="$form->{l_linetotal}">
#<input type=hidden name=l_partnumber value="$form->{l_partnumber}">
#<input type=hidden name=l_description value="$form->{l_description}">
#<input type=hidden name=l_onhand value="$form->{l_onhand}">
#<input type=hidden name=l_unit value="$form->{l_unit}">
#<input type=hidden name=l_sellprice value="$form->{l_sellprice}">
#<input type=hidden name=l_linetotalsellprice value="$form->{l_linetotalsellprice}">
#<input type=hidden name=sort value="$form->{sort}">
#<input type=hidden name=revers value="$form->{revers}">
#<input type=hidden name=lastsort value="$form->{lastsort}">
#
#<input type=hidden name=bom value="$form->{bom}">
#<input type=hidden name=titel value="$form->{titel}">
#<input type=hidden name=searchitems value="$form->{searchitems}">
#
#<input type=hidden name=row value=$j>
#
#<input type=hidden name=nextsub value=item_selected>
#
#<input name=lastndx type=hidden value=$lastndx>
#
#<input name=ndxs_counter type=hidden value=$form->{ndxs_counter}>|;
#
#  my $totop100 = "";
#
#  if (($form->{ndxs_counter}) > 0) {
#    for ($i = 1; ($i < $form->{ndxs_counter} + 1); $i++) {
#
#      $partnumber  = $form->{"totop100_partnumber_$i"};
#      $description = $form->{"totop100_description_$i"};
#      $unit        = $form->{"totop100_unit_$i"};
#      $sellprice   = $form->{"totop100_sellprice_$i"};
#      $soldtotal   = $form->{"totop100_soldtotal_$i"};
#
#      $totop100 .= qq|
#<input type=hidden name=totop100_partnumber_$i value=$form->{"totop100_partnumber_$i"}>
#<input type=hidden name=totop100_description_$i value=$form->{"totop100_description_$i"}>
#<input type=hidden name=totop100_unit_$i value=$form->{"totop100_unit_$i"}>
#<input type=hidden name=totop100_sellprice_$i value=$form->{"totop100_sellprice_$i"}>
#<input type=hidden name=totop100_soldtotal_$i value=$form->{"totop100_soldtotal_$i"}>
#      |;
#    }    #rof
#  }    #fi
#
#  print $totop100;
#
#  print qq|
#<input class=submit type=submit name=action value="|
#    . $locale->text('TOP100') . qq|">
#
#</form>
#|;
#  $lxdebug->leave_sub();
#}    #end list()

sub top100 {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  if ($form->{ndx}) {
    $form->{ndxs_counter}++;

    if ($form->{ndxs_counter} > 0) {

      my $index = $form->{ndx};

      $form->{"totop100_partnumber_$form->{ndxs_counter}"} = $form->{"new_partnumber_$index"};
      $form->{"totop100_description_$form->{ndxs_counter}"} = $form->{"new_description_$index"};
      $form->{"totop100_unit_$form->{ndxs_counter}"} = $form->{"new_unit_$index"};
      $form->{"totop100_sellprice_$form->{ndxs_counter}"} = $form->{"new_sellprice_$index"};
      $form->{"totop100_soldtotal_$form->{ndxs_counter}"} = $form->{"new_soldtotal_$index"};
    }    #fi
  }    #fi
  &addtop100();
  $lxdebug->leave_sub();
}    #end top100

sub addtop100 {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  my ($revers, $lastsort, $callback, $option, $description, $sameitem,
      $partnumber, $unit, $sellprice, $soldtotal, $totop100, $onhand, $align);
  my (@column_index, %column_header, %column_data);
  my ($totalsellprice, $totallastcost, $totallistprice, $subtotalonhand, $subtotalsellprice, $subtotallastcost, $subtotallistprice);

  $form->{top100}      = "top100";
  $form->{l_soldtotal} = "Y";
  $form->{soldtotal}   = "soldtotal";
  $form->{sort}        = "soldtotal";
  $form->{l_qty}       = "N";
  $form->{l_linetotal} = "";
  $form->{revers}      = 1;
  $form->{number}      = "position";
  $form->{l_number}    = "Y";

  $totop100 = "";

  $form->{title} = $locale->text('Top 100');

  $revers   = $form->{revers};
  $lastsort = $form->{lastsort};

  if (($form->{lastsort} eq "") && ($form->{sort} eq undef)) {
    $form->{revers}   = 0;
    $form->{lastsort} = "partnumber";
    $form->{sort}     = "partnumber";
  }    #fi

  $callback =
    "$form->{script}?action=top100&searchitems=$form->{searchitems}&itemstatus=$form->{itemstatus}&bom=$form->{bom}&l_linetotal=$form->{l_linetotal}&title="
    . $form->escape($form->{title}, 1);

  # if we have a serialnumber limit search
  if ($form->{serialnumber} || $form->{l_serialnumber}) {
    $form->{l_serialnumber} = "Y";
    unless (   $form->{bought}
            || $form->{sold}
            || $form->{rfq}
            || $form->{quoted}) {
      $form->{bought} = $form->{sold} = 1;
    }
  }
  IC->all_parts(\%myconfig, \%$form);

  if ($form->{itemstatus} eq 'active') {
    $option .= $locale->text('Active') . " : ";
  }
  if ($form->{itemstatus} eq 'obsolete') {
    $option .= $locale->text('Obsolete') . " : ";
  }
  if ($form->{itemstatus} eq 'orphaned') {
    $option .= $locale->text('Orphaned') . " : ";
  }
  if ($form->{itemstatus} eq 'onhand') {
    $option .= $locale->text('On Hand') . " : ";
    $form->{l_onhand} = "Y";
  }
  if ($form->{itemstatus} eq 'short') {
    $option .= $locale->text('Short') . " : ";
    $form->{l_onhand} = "Y";
  }
  if ($form->{onorder}) {
    $form->{l_ordnumber} = "Y";
    $callback .= "&onorder=$form->{onorder}";
    $option   .= $locale->text('On Order') . " : ";
  }
  if ($form->{ordered}) {
    $form->{l_ordnumber} = "Y";
    $callback .= "&ordered=$form->{ordered}";
    $option   .= $locale->text('Ordered') . " : ";
  }
  if ($form->{rfq}) {
    $form->{l_quonumber} = "Y";
    $callback .= "&rfq=$form->{rfq}";
    $option   .= $locale->text('RFQ') . " : ";
  }
  if ($form->{quoted}) {
    $form->{l_quonumber} = "Y";
    $callback .= "&quoted=$form->{quoted}";
    $option   .= $locale->text('Quoted') . " : ";
  }
  if ($form->{bought}) {
    $form->{l_invnumber} = "Y";
    $callback .= "&bought=$form->{bought}";
    $option   .= $locale->text('Bought') . " : ";
  }
  if ($form->{sold}) {
    $form->{l_invnumber} = "Y";
    $callback .= "&sold=$form->{sold}";
    $option   .= $locale->text('Sold') . " : ";
  }
  if (   $form->{bought}
      || $form->{sold}
      || $form->{onorder}
      || $form->{ordered}
      || $form->{rfq}
      || $form->{quoted}) {

    $form->{l_lastcost} = "";
    $form->{l_name}     = "Y";
    if ($form->{transdatefrom}) {
      $callback .= "&transdatefrom=$form->{transdatefrom}";
      $option   .= "\n<br>"
        . $locale->text('From')
        . "&nbsp;"
        . $locale->date(\%myconfig, $form->{transdatefrom}, 1);
    }
    if ($form->{transdateto}) {
      $callback .= "&transdateto=$form->{transdateto}";
      $option   .= "\n<br>"
        . $locale->text('To')
        . "&nbsp;"
        . $locale->date(\%myconfig, $form->{transdateto}, 1);
    }
  }

  $option .= "<br>";

  if ($form->{partnumber}) {
    $callback .= "&partnumber=$form->{partnumber}";
    $option   .= $locale->text('Part Number') . qq| : $form->{partnumber}<br>|;
  }
  if ($form->{ean}) {
    $callback .= "&partnumber=$form->{ean}";
    $option   .= $locale->text('EAN') . qq| : $form->{ean}<br>|;
  }
  if ($form->{partsgroup}) {
    $callback .= "&partsgroup=$form->{partsgroup}";
    $option   .= $locale->text('Group') . qq| : $form->{partsgroup}<br>|;
  }
  if ($form->{serialnumber}) {
    $callback .= "&serialnumber=$form->{serialnumber}";
    $option   .= $locale->text('Serial Number') . qq| : $form->{serialnumber}<br>|;
  }
  if ($form->{description}) {
    $callback   .= "&description=$form->{description}";
    $description = $form->{description};
    $description =~ s/\n/<br>/g;
    $option     .= $locale->text('Part Description') . qq| : $form->{description}<br>|;
  }
  if ($form->{make}) {
    $callback .= "&make=$form->{make}";
    $option   .= $locale->text('Make') . qq| : $form->{make}<br>|;
  }
  if ($form->{model}) {
    $callback .= "&model=$form->{model}";
    $option   .= $locale->text('Model') . qq| : $form->{model}<br>|;
  }
  if ($form->{drawing}) {
    $callback .= "&drawing=$form->{drawing}";
    $option   .= $locale->text('Drawing') . qq| : $form->{drawing}<br>|;
  }
  if ($form->{microfiche}) {
    $callback .= "&microfiche=$form->{microfiche}";
    $option   .= $locale->text('Microfiche') . qq| : $form->{microfiche}<br>|;
  }
  if ($form->{l_soldtotal}) {
    $callback .= "&soldtotal=$form->{soldtotal}";
    $option   .= $locale->text('soldtotal') . qq| : $form->{soldtotal}<br>|;
  }

  my @columns = $form->sort_columns(
    qw(number partnumber ean description partsgroup bin onhand rop unit listprice linetotallistprice sellprice linetotalsellprice lastcost linetotallastcost priceupdate weight image drawing microfiche invnumber ordnumber quonumber name serialnumber soldtotal)
  );

  if ($form->{l_linetotal}) {
    $form->{l_onhand} = "Y";
    $form->{l_linetotalsellprice} = "Y" if $form->{l_sellprice};
    if ($form->{l_lastcost}) {
      $form->{l_linetotallastcost} = "Y";
      if (($form->{searchitems} eq 'assembly') && !$form->{bom}) {
        $form->{l_linetotallastcost} = "";
      }
    }
    $form->{l_linetotallistprice} = "Y" if $form->{l_listprice};
  }

  if ($form->{searchitems} eq 'service') {

    # remove bin, weight and rop from list
    map { $form->{"l_$_"} = "" } qw(bin weight rop);

    $form->{l_onhand} = "";

    # qty is irrelevant unless bought or sold
    if (   $form->{bought}
        || $form->{sold}
        || $form->{onorder}
        || $form->{ordered}
        || $form->{rfq}
        || $form->{quoted}) {
      $form->{l_onhand} = "Y";
    } else {
      $form->{l_linetotalsellprice} = "";
      $form->{l_linetotallastcost}  = "";
    }
  }

  foreach my $item (@columns) {
    if ($form->{"l_$item"} eq "Y") {
      push @column_index, $item;

      # add column to callback
      $callback .= "&l_$item=Y";
    }
  }

  if ($form->{l_subtotal} eq 'Y') {
    $callback .= "&l_subtotal=Y";
  }

  $column_header{number} =
    qq|<th class=listheading nowrap>| . $locale->text('number') . qq|</th>|;
  $column_header{partnumber} =
    qq|<th nowrap><a class=listheading href=$callback&sort=partnumber&revers=$form->{revers}&lastsort=$form->{lastsort}>|
    . $locale->text('Part Number')
    . qq|</a></th>|;
  $column_header{description} =
    qq|<th nowrap><a class=listheading href=$callback&sort=description&revers=$form->{revers}&lastsort=$form->{lastsort}>|
    . $locale->text('Part Description')
    . qq|</a></th>|;
  $column_header{partsgroup} =
      qq|<th nowrap><a class=listheading href=$callback&sort=partsgroup>|
    . $locale->text('Group')
    . qq|</a></th>|;
  $column_header{bin} =
      qq|<th><a class=listheading href=$callback&sort=bin>|
    . $locale->text('Bin')
    . qq|</a></th>|;
  $column_header{priceupdate} =
      qq|<th nowrap><a class=listheading href=$callback&sort=priceupdate>|
    . $locale->text('Updated')
    . qq|</a></th>|;
  $column_header{onhand} =
    qq|<th nowrap><a  class=listheading href=$callback&sort=onhand&revers=$form->{revers}&lastsort=$form->{lastsort}>|
    . $locale->text('Qty')
    . qq|</th>|;
  $column_header{unit} =
    qq|<th class=listheading nowrap>| . $locale->text('Unit') . qq|</th>|;
  $column_header{listprice} =
      qq|<th class=listheading nowrap>|
    . $locale->text('List Price')
    . qq|</th>|;
  $column_header{lastcost} =
    qq|<th class=listheading nowrap>| . $locale->text('Last Cost') . qq|</th>|;
  $column_header{rop} =
    qq|<th class=listheading nowrap>| . $locale->text('ROP') . qq|</th>|;
  $column_header{weight} =
    qq|<th class=listheading nowrap>| . $locale->text('Weight') . qq|</th>|;

  $column_header{invnumber} =
      qq|<th nowrap><a class=listheading href=$callback&sort=invnumber>|
    . $locale->text('Invoice Number')
    . qq|</a></th>|;
  $column_header{ordnumber} =
      qq|<th nowrap><a class=listheading href=$callback&sort=ordnumber>|
    . $locale->text('Order Number')
    . qq|</a></th>|;
  $column_header{quonumber} =
      qq|<th nowrap><a class=listheading href=$callback&sort=quonumber>|
    . $locale->text('Quotation')
    . qq|</a></th>|;

  $column_header{name} =
      qq|<th nowrap><a class=listheading href=$callback&sort=name>|
    . $locale->text('Name')
    . qq|</a></th>|;

  $column_header{sellprice} =
      qq|<th class=listheading nowrap>|
    . $locale->text('Sell Price')
    . qq|</th>|;
  $column_header{linetotalsellprice} =
    qq|<th class=listheading nowrap>| . $locale->text('Extended') . qq|</th>|;
  $column_header{linetotallastcost} =
    qq|<th class=listheading nowrap>| . $locale->text('Extended') . qq|</th>|;
  $column_header{linetotallistprice} =
    qq|<th class=listheading nowrap>| . $locale->text('Extended') . qq|</th>|;

  $column_header{image} =
    qq|<th class=listheading nowrap>| . $locale->text('Image') . qq|</a></th>|;
  $column_header{drawing} =
      qq|<th nowrap><a class=listheading href=$callback&sort=drawing>|
    . $locale->text('Drawing')
    . qq|</a></th>|;
  $column_header{microfiche} =
      qq|<th nowrap><a class=listheading href=$callback&sort=microfiche>|
    . $locale->text('Microfiche')
    . qq|</a></th>|;

  $column_header{serialnumber} =
      qq|<th nowrap><a class=listheading href=$callback&sort=serialnumber>|
    . $locale->text('Serial Number')
    . qq|</a></th>|;
  $column_header{soldtotal} =
    qq|<th nowrap><a class=listheading href=$callback&sort=soldtotal&revers=$form->{revers}&lastsort=$form->{lastsort}>|
    . $locale->text('soldtotal')
    . qq|</a></th>|;

  $form->header;
  my $colspan = $#column_index + 1;

  print qq|
    <h1>$form->{title}</h1>

<table width=100%>

  <tr><td colspan=$colspan>$option</td></tr>

  <tr class=listheading>
|;

  map { print "\n$column_header{$_}" } @column_index;

  print qq|
  </tr>
  |;

  # add order to callback
  $form->{callback} = $callback .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($callback);

  if (@{ $form->{parts} }) {
    $sameitem = $form->{parts}->[0]->{ $form->{sort} };
  }

  # insert numbers for top100
  my $j = 0;
  foreach my $ref (@{ $form->{parts} }) {
    $j++;
    $ref->{number} = $j;
  }

  # if avaible -> insert choice here
  if (($form->{ndxs_counter}) > 0) {
    for (my $i = 1; ($i < $form->{ndxs_counter} + 1); $i++) {
      $partnumber  = $form->{"totop100_partnumber_$i"};
      $description = $form->{"totop100_description_$i"};
      $unit        = $form->{"totop100_unit_$i"};
      $sellprice   = $form->{"totop100_sellprice_$i"};
      $soldtotal   = $form->{"totop100_soldtotal_$i"};

      $totop100 .= qq|
<input type=hidden name=totop100_partnumber_$i value=$form->{"totop100_partnumber_$i"}>
<input type=hidden name=totop100_description_$i value=$form->{"totop100_description_$i"}>
<input type=hidden name=totop100_unit_$i value=$form->{"totop100_unit_$i"}>
<input type=hidden name=totop100_sellprice_$i value=$form->{"totop100_sellprice_$i"}>
<input type=hidden name=totop100_soldtotal_$i value=$form->{"totop100_soldtotal_$i"}>
      |;

      # insert into list
      push @{ $form->{parts} },
        { number      => "",
          partnumber  => "$partnumber",
          description => "$description",
          unit        => "$unit",
          sellprice   => "$sellprice",
          soldtotal   => "$soldtotal" };
    }    #rof
  }    #fi
       # build data for columns
  my $i = 0;
  foreach my $ref (@{ $form->{parts} }) {

    if ($form->{l_subtotal} eq 'Y' && !$ref->{assemblyitem}) {
      if ($sameitem ne $ref->{ $form->{sort} }) {
        parts_subtotal(\@column_index, \$subtotalonhand, \$subtotalsellprice, \$subtotallastcost, \$subtotallistprice);
        $sameitem = $ref->{ $form->{sort} };
      }
    }

    $ref->{exchangerate} = 1 unless $ref->{exchangerate};
    $ref->{sellprice} *= $ref->{exchangerate};
    $ref->{listprice} *= $ref->{exchangerate};
    $ref->{lastcost}  *= $ref->{exchangerate};

    # use this for assemblies
    $onhand = $ref->{onhand};

    $align = "left";
    if ($ref->{assemblyitem}) {
      $align = "right";
      $onhand = 0 if ($form->{sold});
    }

    $ref->{description} =~ s/\n/<br>/g;

    $column_data{number} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{number})
      . "</td>";
    $column_data{partnumber} =
      "<td align=$align>$ref->{partnumber}&nbsp;</a></td>";
    $column_data{description} = "<td>$ref->{description}&nbsp;</td>";
    $column_data{partsgroup}  = "<td>$ref->{partsgroup}&nbsp;</td>";

    $column_data{onhand} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{onhand})
      . "</td>";
    $column_data{sellprice} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{sellprice})
      . "</td>";
    $column_data{listprice} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{listprice})
      . "</td>";
    $column_data{lastcost} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{lastcost})
      . "</td>";

    $column_data{linetotalsellprice} = "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{onhand} * $ref->{sellprice}, 2)
      . "</td>";
    $column_data{linetotallastcost} = "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{onhand} * $ref->{lastcost}, 2)
      . "</td>";
    $column_data{linetotallistprice} = "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{onhand} * $ref->{listprice}, 2)
      . "</td>";

    if (!$ref->{assemblyitem}) {
      $totalsellprice += $onhand * $ref->{sellprice};
      $totallastcost  += $onhand * $ref->{lastcost};
      $totallistprice += $onhand * $ref->{listprice};

      $subtotalonhand    += $onhand;
      $subtotalsellprice += $onhand * $ref->{sellprice};
      $subtotallastcost  += $onhand * $ref->{lastcost};
      $subtotallistprice += $onhand * $ref->{listprice};
    }

    $column_data{rop} =
      "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{rop}) . "</td>";
    $column_data{weight} =
        "<td align=right>"
      . $form->format_amount(\%myconfig, $ref->{weight})
      . "</td>";
    $column_data{unit}        = "<td>$ref->{unit}&nbsp;</td>";
    $column_data{bin}         = "<td>$ref->{bin}&nbsp;</td>";
    $column_data{priceupdate} = "<td>$ref->{priceupdate}&nbsp;</td>";

    $column_data{invnumber} =
      ($ref->{module} ne 'oe')
      ? "<td><a href=$ref->{module}.pl?action=edit&type=invoice&id=$ref->{trans_id}&callback=$callback>$ref->{invnumber}</a></td>"
      : "<td>$ref->{invnumber}</td>";
    $column_data{ordnumber} =
      ($ref->{module} eq 'oe')
      ? "<td><a href=$ref->{module}.pl?action=edit&type=$ref->{type}&id=$ref->{trans_id}&callback=$callback>$ref->{ordnumber}</a></td>"
      : "<td>$ref->{ordnumber}</td>";
    $column_data{quonumber} =
      ($ref->{module} eq 'oe' && !$ref->{ordnumber})
      ? "<td><a href=$ref->{module}.pl?action=edit&type=$ref->{type}&id=$ref->{trans_id}&callback=$callback>$ref->{quonumber}</a></td>"
      : "<td>$ref->{quonumber}</td>";

    $column_data{name} = "<td>$ref->{name}</td>";

    $column_data{image} =
      ($ref->{image})
      ? "<td><a href=$ref->{image}><img src=$ref->{image} height=32 border=0></a></td>"
      : "<td>&nbsp;</td>";
    $column_data{drawing} =
      ($ref->{drawing})
      ? "<td><a href=$ref->{drawing}>$ref->{drawing}</a></td>"
      : "<td>&nbsp;</td>";
    $column_data{microfiche} =
      ($ref->{microfiche})
      ? "<td><a href=$ref->{microfiche}>$ref->{microfiche}</a></td>"
      : "<td>&nbsp;</td>";

    $column_data{serialnumber} = "<td>$ref->{serialnumber}</td>";

    $column_data{soldtotal} = "<td  align=right>$ref->{soldtotal}</td>";

    $i++;
    $i %= 2;
    print "<tr class=listrow$i>";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
    </tr>
|;
  }

  if ($form->{l_subtotal} eq 'Y') {
    parts_subtotal(\@column_index, \$subtotalonhand, \$subtotalsellprice, \$subtotallastcost, \$subtotallistprice);
  }    #fi

  if ($form->{"l_linetotal"}) {
    map { $column_data{$_} = "<td>&nbsp;</td>" } @column_index;
    $column_data{linetotalsellprice} =
        "<th class=listtotal align=right>"
      . $form->format_amount(\%myconfig, $totalsellprice, 2)
      . "</th>";
    $column_data{linetotallastcost} =
        "<th class=listtotal align=right>"
      . $form->format_amount(\%myconfig, $totallastcost, 2)
      . "</th>";
    $column_data{linetotallistprice} =
        "<th class=listtotal align=right>"
      . $form->format_amount(\%myconfig, $totallistprice, 2)
      . "</th>";

    print "<tr class=listtotal>";

    map { print "\n$column_data{$_}" } @column_index;

    print qq|</tr>
    |;
  }

  print qq|
  <tr><td colspan=$colspan><hr size=3 noshade></td></tr>
</table>

|;

  print qq|

<br>

<form method=post action=$form->{script}>

<input type=hidden name=itemstatus value="$form->{itemstatus}">
<input type=hidden name=l_linetotal value="$form->{l_linetotal}">
<input type=hidden name=l_partnumber value="$form->{l_partnumber}">
<input type=hidden name=l_description value="$form->{l_description}">
<input type=hidden name=l_onhand value="$form->{l_onhand}">
<input type=hidden name=l_unit value="$form->{l_unit}">
<input type=hidden name=l_sellprice value="$form->{l_sellprice}">
<input type=hidden name=l_linetotalsellprice value="$form->{l_linetotalsellprice}">
<input type=hidden name=sort value="$form->{sort}">
<input type=hidden name=revers value="$form->{revers}">
<input type=hidden name=lastsort value="$form->{lastsort}">
<input type=hidden name=parts value="$form->{parts}">

<input type=hidden name=bom value="$form->{bom}">
<input type=hidden name=titel value="$form->{titel}">
<input type=hidden name=searchitems value="$form->{searchitems}">|;

  print $totop100;

  print qq|
<!--    <input type=hidden name=ndxs_counter value="$form->{ndxs_counter}">-->

<!--    <input class=submit type=submit name=action value="|
    . $locale->text('choice') . qq|"> -->

  </form>
|;

  $lxdebug->leave_sub();
}    # end addtop100

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
# partnumber ean description partsgroup serialnumber make model drawing microfiche
# transdatefrom transdateto
#
# radio:
#  itemstatus = active | onhand | short | obsolete | orphaned
#  action     = continue | top100
#
# checkboxes:
#  bought sold onorder ordered rfq quoted
#  l_partnumber l_description l_serialnumber l_unit l_listprice l_sellprice l_lastcost
#  l_linetotal l_priceupdate l_bin l_rop l_weight l_image l_drawing l_microfiche
#  l_partsgroup l_subtotal l_soldtotal l_deliverydate l_pricegroups
#
# hiddens:
#  nextsub revers lastsort sort ndxs_counter
#
sub generate_report {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  my ($revers, $lastsort, $description);

  my $cvar_configs = CVar->get_configs('module' => 'IC');

  $form->{title} = (ucfirst $form->{searchitems}) . "s";
  $form->{title} =~ s/ys$/ies/;
  $form->{title} = $locale->text($form->{title});

  my %column_defs = (
    'bin'                => { 'text' => $locale->text('Bin'), },
    'deliverydate'       => { 'text' => $locale->text('deliverydate'), },
    'description'        => { 'text' => $locale->text('Part Description'), },
    'notes'              => { 'text' => $locale->text('Notes'), },
    'drawing'            => { 'text' => $locale->text('Drawing'), },
    'ean'                => { 'text' => $locale->text('EAN'), },
    'image'              => { 'text' => $locale->text('Image'), },
    'insertdate'         => { 'text' => $locale->text('Insert Date'), },
    'invnumber'          => { 'text' => $locale->text('Invoice Number'), },
    'lastcost'           => { 'text' => $locale->text('Last Cost'), },
    'linetotallastcost'  => { 'text' => $locale->text('Extended'), },
    'linetotallistprice' => { 'text' => $locale->text('Extended'), },
    'linetotalsellprice' => { 'text' => $locale->text('Extended'), },
    'listprice'          => { 'text' => $locale->text('List Price'), },
    'microfiche'         => { 'text' => $locale->text('Microfiche'), },
    'name'               => { 'text' => $locale->text('Name'), },
    'onhand'             => { 'text' => $locale->text('Stocked Qty'), },
    'ordnumber'          => { 'text' => $locale->text('Order Number'), },
    'partnumber'         => { 'text' => $locale->text('Part Number'), },
    'partsgroup'         => { 'text' => $locale->text('Group'), },
    'priceupdate'        => { 'text' => $locale->text('Updated'), },
    'quonumber'          => { 'text' => $locale->text('Quotation'), },
    'rop'                => { 'text' => $locale->text('ROP'), },
    'sellprice'          => { 'text' => $locale->text('Sell Price'), },
    'serialnumber'       => { 'text' => $locale->text('Serial Number'), },
    'soldtotal'          => { 'text' => $locale->text('Qty in Selected Records'), },
    'name'               => { 'text' => $locale->text('Name in Selected Records'), },
    'transdate'          => { 'text' => $locale->text('Transdate'), },
    'unit'               => { 'text' => $locale->text('Unit'), },
    'weight'             => { 'text' => $locale->text('Weight'), },
    'shop'               => { 'text' => $locale->text('Shop article'), },
    'projectnumber'      => { 'text' => $locale->text('Project Number'), },
    'projectdescription' => { 'text' => $locale->text('Project Description'), },
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
    orphaned      => $locale->text('Orphaned'),
    onhand        => $locale->text('On Hand'),
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
    partsgroup    => $locale->text('Group')            . ": '$form->{partsgroup}'",
    partsgroup_id => $locale->text('Group')            . ": '$pg_name'",
    serialnumber  => $locale->text('Serial Number')    . ": '$form->{serialnumber}'",
    description   => $locale->text('Part Description') . ": '$form->{description}'",
    make          => $locale->text('Make')             . ": '$form->{make}'",
    model         => $locale->text('Model')            . ": '$form->{model}'",
    drawing       => $locale->text('Drawing')          . ": '$form->{drawing}'",
    microfiche    => $locale->text('Microfiche')       . ": '$form->{microfiche}'",
    l_soldtotal   => $locale->text('Qty in Selected Records'),
    ean           => $locale->text('EAN')              . ": '$form->{ean}'",
    insertdatefrom => $locale->text('Insert Date') . ": " . $locale->text('From')       . " " . $locale->date(\%myconfig, $form->{insertdatefrom}, 1),
    insertdateto   => $locale->text('Insert Date') . ": " . $locale->text('To (time)')  . " " . $locale->date(\%myconfig, $form->{insertdateto}, 1),
  );

  my @itemstatus_keys = qw(active obsolete orphaned onhand short);
  my @callback_keys   = qw(onorder ordered rfq quoted bought sold partnumber partsgroup partsgroup_id serialnumber description make model
                           drawing microfiche l_soldtotal l_deliverydate transdatefrom transdateto insertdatefrom insertdateto ean shop);

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

  if ($form->{searchitems} eq 'service') {

    # remove bin, weight and rop from list
    map { $form->{"l_$_"} = "" } qw(bin weight rop);

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
  if ($form->{l_name} && !$bsooqr_mode) {
    delete $form->{l_name};

    flash('warning', $::locale->text('Name does not make sense without any bsooqr options'));
  }
  IC->all_parts(\%myconfig, \%$form);

  my @columns = qw(
    partnumber description notes partsgroup bin onhand rop soldtotal unit listprice
    linetotallistprice sellprice linetotalsellprice lastcost linetotallastcost
    priceupdate weight image drawing microfiche invnumber ordnumber quonumber
    transdate name serialnumber deliverydate ean projectnumber projectdescription
    insertdate shop
  );

  my $pricegroups = SL::DB::Manager::Pricegroup->get_all(sort => 'id');
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
  map { $column_defs{$_}->{align}   = 'right' } qw(onhand sellprice listprice lastcost linetotalsellprice linetotallastcost linetotallistprice rop weight soldtotal shop), @pricegroup_columns;

  my @hidden_variables = (
    qw(l_subtotal l_linetotal searchitems itemstatus bom l_pricegroups insertdatefrom insertdateto),
    @itemstatus_keys,
    @callback_keys,
    map({ "cvar_$_->{name}" } @searchable_custom_variables),
    map({'cvar_'. $_->{name} .'_qtyop'} grep({$_->{type} eq 'number'} @searchable_custom_variables)),
    map({ "l_$_" } @columns),
  );

  my $callback         = build_std_url('action=generate_report', grep { $form->{$_} } @hidden_variables);

  my @sort_full        = qw(partnumber description onhand soldtotal deliverydate insertdate shop);
  my @sort_no_revers   = qw(partsgroup bin priceupdate invnumber ordnumber quonumber name image drawing serialnumber);

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
  );

  $report->set_options('raw_top_info_text'     => $form->parse_html_template('ic/generate_report_top', { options => \@options }),
                       'raw_bottom_info_text'  => $form->parse_html_template('ic/generate_report_bottom'),
                       'output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => $attachment_basenames{$form->{searchitems}} . strftime('_%Y%m%d', localtime time),
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

    # use this for assemblies
    my $soldtotal = $bsooqr_mode ? $ref->{soldtotal} : $ref->{onhand};

    if ($ref->{assemblyitem}) {
      $row->{partnumber}{align}   = 'right';
      $row->{soldtotal}{data}     = 0;
      $soldtotal                  = 0 if ($form->{sold});
    }

    my $edit_link               = build_std_url('action=edit', 'id=' . E($ref->{id}), 'callback');
    $row->{partnumber}->{link}  = $edit_link;
    $row->{description}->{link} = $edit_link;

    foreach (qw(sellprice listprice lastcost)) {
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

      my $edit_oe_ord_link = build_std_url("script=oe.pl", 'action=edit', 'type=' . E($ref->{cv} eq 'vendor' ? 'purchase_order' : 'sales_order'), 'id=' . E($ref->{trans_id}), 'callback');
      my $edit_oe_quo_link = build_std_url("script=oe.pl", 'action=edit', 'type=' . E($ref->{cv} eq 'vendor' ? 'request_quotation' : 'sales_quotation'), 'id=' . E($ref->{trans_id}), 'callback');

      $row->{ordnumber}{link} = $edit_oe_ord_link;
      $row->{quonumber}{link} = $edit_oe_quo_link if (!$ref->{ordnumber});

    } else {
      $row->{invnumber}{link} = build_std_url("script=$ref->{module}.pl", 'action=edit', 'type=invoice', 'id=' . E($ref->{trans_id}), 'callback');
    }

    # set properties of images
    if ($ref->{image} && (lc $report->{options}->{output_format} eq 'html')) {
      $row->{image}{data}     = '';
      $row->{image}{raw_data} = '<a href="' . H($ref->{image}) . '"><img src="' . H($ref->{image}) . '" height="32" border="0"></a>';
    }
    map { $row->{$_}{link} = $ref->{$_} } qw(drawing microfiche);

    $row->{notes}{data} = SL::HTML::Util->strip($ref->{notes});

    $report->add_data($row);

    my $next_ref = $form->{parts}[$idx + 1];

    # insert subtotal rows
    if (($form->{l_subtotal} eq 'Y') &&
        (!$next_ref ||
         (!$next_ref->{assemblyitem} && ($same_item ne $next_ref->{ $form->{sort} })))) {
      my $row = { map { $_ => { 'class' => 'listsubtotal', } } @columns };

      if (($form->{searchitems} ne 'assembly') || !$form->{bom}) {
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

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}    #end generate_report

sub parts_subtotal {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  my (%column_data);
  my ($column_index, $subtotalonhand, $subtotalsellprice, $subtotallastcost, $subtotallistprice) = @_;

  map { $column_data{$_} = "<td>&nbsp;</td>" } @{ $column_index };
  $$subtotalonhand = 0 if ($form->{searchitems} eq 'assembly' && $form->{bom});

  $column_data{onhand} =
      "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $$subtotalonhand)
    . "</th>";

  $column_data{linetotalsellprice} =
      "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $$subtotalsellprice, 2)
    . "</th>";
  $column_data{linetotallistprice} =
      "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $$subtotallistprice, 2)
    . "</th>";
  $column_data{linetotallastcost} =
      "<th class=listsubtotal align=right>"
    . $form->format_amount(\%myconfig, $$subtotallastcost, 2)
    . "</th>";

  $$subtotalonhand    = 0;
  $$subtotalsellprice = 0;
  $$subtotallistprice = 0;
  $$subtotallastcost  = 0;

  print "<tr class=listsubtotal>";

  map { print "\n$column_data{$_}" } @{ $column_index };

  print qq|
  </tr>
|;

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button
  IC->get_part(\%myconfig, \%$form);

  $form->{"original_partnumber"} = $form->{"partnumber"};

  my $title      = 'Edit ' . ucfirst $form->{item};
  $form->{title} = $locale->text($title);

  &link_part;
  &display_form;

  $lxdebug->leave_sub();
}

sub link_part {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  IC->create_links("IC", \%myconfig, \%$form);

  # currencies
  map({ $form->{selectcurrency} .= "<option>$_\n" } $::form->get_all_currencies());

  # parts and assemblies have the same links
  my $item = $form->{item};
  if ($form->{item} eq 'assembly') {
    $item = 'part';
  }

  # build the popup menus
  $form->{taxaccounts} = "";
  foreach my $key (keys %{ $form->{IC_links} }) {
    foreach my $ref (@{ $form->{IC_links}{$key} }) {

      # if this is a tax field
      if ($key =~ /IC_tax/) {
        if ($key =~ /\Q$item\E/) {
          $form->{taxaccounts} .= "$ref->{accno} ";
          $form->{"IC_tax_$ref->{accno}_description"} =
            "$ref->{accno}--$ref->{description}";

          if ($form->{id}) {
            if ($form->{amount}{ $ref->{accno} }) {
              $form->{"IC_tax_$ref->{accno}"} = "checked";
            }
          } else {
            $form->{"IC_tax_$ref->{accno}"} = "checked";
          }
        }
      } else {

        $form->{"select$key"} .=
          "<option $ref->{selected}>$ref->{accno}--$ref->{description}\n";
        if ($form->{amount}{$key} eq $ref->{accno}) {
          $form->{$key} = "$ref->{accno}--$ref->{description}";
        }

      }
    }
  }
  chop $form->{taxaccounts};

  if (($form->{item} eq "part") || ($form->{item} eq "assembly")) {
    $form->{selectIC_income}  = $form->{selectIC_sale};
    $form->{selectIC_expense} = $form->{selectIC_cogs};
    $form->{IC_income}        = $form->{IC_sale};
    $form->{IC_expense}       = $form->{IC_cogs};
  }

  delete $form->{IC_links};
  delete $form->{amount};

  $form->get_partsgroup(\%myconfig, { all => 1 });

  $form->{partsgroup} = "$form->{partsgroup}--$form->{partsgroup_id}";

  if (@{ $form->{all_partsgroup} }) {
    $form->{selectpartsgroup} = qq|<option>\n|;
    map { $form->{selectpartsgroup} .= qq|<option value="$_->{partsgroup}--$_->{id}">$_->{partsgroup}\n| } @{ $form->{all_partsgroup} };
  }

  if ($form->{item} eq 'assembly') {

    foreach my $i (1 .. $form->{assembly_rows}) {
      if ($form->{"partsgroup_id_$i"}) {
        $form->{"partsgroup_$i"} =
          qq|$form->{"partsgroup_$i"}--$form->{"partsgroup_id_$i"}|;
      }
    }
    $form->get_partsgroup(\%myconfig);

    if (@{ $form->{all_partsgroup} }) {
      $form->{selectassemblypartsgroup} = qq|<option>\n|;

      map {
        $form->{selectassemblypartsgroup} .=
          qq|<option value="$_->{partsgroup}--$_->{id}">$_->{partsgroup}\n|
      } @{ $form->{all_partsgroup} };
    }
  }
  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  $form->{pg_keys}          = sub { "$_[0]->{partsgroup}--$_[0]->{id}" };
  $form->{description_area} = ($form->{rows} = $form->numtextrows($form->{description}, 40)) > 1;
  $form->{notes_rows}       =  max 4, $form->numtextrows($form->{notes}, 40), $form->numtextrows($form->{formel}, 40);

  map { $form->{"is_$_"}  = ($form->{item} eq $_) } qw(part service assembly);
  map { $form->{$_}       =~ s/"/&quot;/g;        } qw(unit);

  $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS',
                   'partsgroup'    => 'all_partsgroup',
                   'vendors'       => 'ALL_VENDORS',
                   'warehouses'    => { 'key'    => 'WAREHOUSES',
                                        'bins'   => 'BINS', });
  # leerer wert für Lager und Lagerplatz korrekt einstellt
  # ID 0 sollte in Ordnung sein, da der Zähler sowieso höher ist
  my $no_default_bin_entry = { 'id' => '0', description => '--', 'BINS' => [ { id => '0', description => ''} ] };
  push @ { $form->{WAREHOUSES} }, $no_default_bin_entry;
  if (my $max = scalar @{ $form->{WAREHOUSES} }) {
    my ($default_warehouse_id, $default_bin_id);
    if ($form->{action} eq 'add') { # default only for new entries
      $default_warehouse_id = $::instance_conf->get_warehouse_id;
      $default_bin_id       = $::instance_conf->get_bin_id;
    }
    $form->{warehouse_id} ||= $default_warehouse_id || $form->{WAREHOUSES}->[$max -1]->{id};
    $form->{bin_id}       ||= $default_bin_id       ||  $form->{WAREHOUSES}->[$max -1]->{BINS}->[0]->{id};
  }

  $form->{LANGUAGES}        = SL::DB::Manager::Language->get_all_sorted;
  $form->{translations_map} = { map { ($_->{language_id} => $_) } @{ $form->{translations} || [] } };

  IC->retrieve_buchungsgruppen(\%myconfig, $form);
  @{ $form->{BUCHUNGSGRUPPEN} } = grep { $_->{id} eq $form->{buchungsgruppen_id} || ($form->{id} && $form->{orphaned}) || !$form->{id} } @{ $form->{BUCHUNGSGRUPPEN} };

  if (($form->{partnumber} ne '') && !SL::TransNumber->new(number => $form->{partnumber}, type => $form->{item}, id => $form->{id})->is_unique) {
    flash('info', $::locale->text('This partnumber is not unique. You should change it.'));
  }

  my $units = AM->retrieve_units(\%myconfig, $form);
  $form->{ALL_UNITS} = [ map +{ name => $_ }, sort { $units->{$a}{sortkey} <=> $units->{$b}{sortkey} } keys %$units ];

  $form->{defaults} = AM->get_defaults();

  $form->{CUSTOM_VARIABLES} = CVar->get_custom_variables('module' => 'IC', 'trans_id' => $form->{id});

  my ($null, $partsgroup_id) = split /--/, $form->{partsgroup};

  CVar->render_inputs('variables' => $form->{CUSTOM_VARIABLES}, show_disabled_message => 1, partsgroup_id => $partsgroup_id)
    if (scalar @{ $form->{CUSTOM_VARIABLES} });

  $::request->layout->use_javascript("${_}.js") for qw(ckeditor/ckeditor ckeditor/adapters/jquery kivi.PriceRule);
  $::request->layout->add_javascripts_inline("\$(function(){kivi.PriceRule.load_price_rules_for_part(@{[ $::form->{id} * 1 ]})});") if $::form->{id};
  $form->header;
  #print $form->parse_html_template('ic/form_header', { ALL_PRICE_FACTORS => $form->{ALL_PRICE_FACTORS},
  #                                                     ALL_UNITS         => $form->{ALL_UNITS},
  #                                                     BUCHUNGSGRUPPEN   => $form->{BUCHUNGSGRUPPEN},
  #                                                     payment_terms     => $form->{payment_terms},
  #                                                     all_partsgroup    => $form->{all_partsgroup}});

  $form->{show_edit_buttons} = $main::auth->check_right($::myconfig{login}, 'part_service_assembly_edit');

  print $form->parse_html_template('ic/form_header');
  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  print $form->parse_html_template('ic/form_footer');

  $lxdebug->leave_sub();
}

sub makemodel_row {
  $lxdebug->enter_sub();
  my ($numrows) = @_;
  #hli
  my @mm_data = grep { any { $_ ne '' } @$_{qw(make model)} } map +{ make => $form->{"make_$_"}, model => $form->{"model_$_"}, lastcost => $form->{"lastcost_$_"}, lastupdate => $form->{"lastupdate_$_"}, sortorder => $form->{"sortorder_$_"} }, 1 .. $numrows;
  delete @{$form}{grep { m/^make_\d+/ || m/^model_\d+/ } keys %{ $form }};
  print $form->parse_html_template('ic/makemodel', { MM_DATA => [ @mm_data, {} ], mm_rows => scalar @mm_data + 1 });

  $lxdebug->leave_sub();
}

sub assembly_row {
  $lxdebug->enter_sub();
  my ($numrows) = @_;
  my (@column_index);
  my ($nochange, $callback, $previousform, $linetotal, $line_purchase_price, $href);

  @column_index = qw(runningnumber qty unit bom partnumber description partsgroup lastcost total);

  if ($form->{previousform}) {
    $nochange     = 1;
    @column_index = qw(qty unit bom partnumber description partsgroup total);
  } else {

    # change callback
    $form->{old_callback} = $form->{callback};
    $callback             = $form->{callback};
    $form->{callback}     = "$form->{script}?action=display_form";

    # delete action
    map { delete $form->{$_} } qw(action header);

    # save form variables in a previousform variable
    my %form_to_save = map   { ($_ => m/^ (?: listprice | sellprice | lastcost ) $/x ? $form->format_amount(\%myconfig, $form->{$_}) : $form->{$_}) }
                       keys %{ $form };
    $previousform    = $::auth->save_form_in_session(form => \%form_to_save);

    $form->{callback} = $callback;
    $form->{assemblytotal} = 0;
    $form->{assembly_purchase_price_total} = 0;
    $form->{weight}        = 0;
  }

  my %header = (
   runningnumber => { text =>  $locale->text('No.'),              nowrap => 1, width => '5%',  align => 'left',},
   qty           => { text =>  $locale->text('Qty'),              nowrap => 1, width => '10%', align => 'left',},
   unit          => { text =>  $locale->text('Unit'),             nowrap => 1, width => '5%',  align => 'left',},
   partnumber    => { text =>  $locale->text('Part Number'),      nowrap => 1, width => '20%', align => 'left',},
   description   => { text =>  $locale->text('Part Description'), nowrap => 1, width => '50%', align => 'left',},
   lastcost      => { text =>  $locale->text('Purchase Prices'),  nowrap => 1, width => '50%', align => 'right',},
   total         => { text =>  $locale->text('Sale Prices'),      nowrap => 1,                 align => 'right',},
   bom           => { text =>  $locale->text('BOM'),                                           align => 'center',},
   partsgroup    => { text =>  $locale->text('Group'),                                         align => 'left',},
  );

  my @ROWS;

  for my $i (1 .. $numrows) {
    my (%row, @row_hiddens);

    $form->{"partnumber_$i"} =~ s/\"/&quot;/g;

    $linetotal           = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"} / ($form->{"price_factor_$i"} || 1), 4);
    $line_purchase_price = $form->round_amount($form->{"lastcost_$i"} *  $form->{"qty_$i"} / ($form->{"price_factor_$i"} || 1), 4);
    $form->{assemblytotal}                  += $linetotal;
    $form->{assembly_purchase_price_total}  += $line_purchase_price;
    $form->{"qty_$i"}    = $form->format_amount(\%myconfig, $form->{"qty_$i"});
    $linetotal           = $form->format_amount(\%myconfig, $linetotal, 2);
    $line_purchase_price = $form->format_amount(\%myconfig, $line_purchase_price, 2);
    $href                = build_std_url("action=edit", qq|id=$form->{"id_$i"}|, "rowcount=$numrows", "currow=$i", "previousform=$previousform");
    map { $row{$_}{data} = "" } qw(qty unit partnumber description bom partsgroup runningnumber);

    # last row
    if (($i >= 1) && ($i == $numrows)) {
      if (!$form->{previousform}) {
        $row{partnumber}{data}  = qq|<input name="partnumber_$i" size=15 value="$form->{"partnumber_$i"}">|;
        $row{qty}{data}         = qq|<input name="qty_$i" size=5 value="$form->{"qty_$i"}">|;
        $row{description}{data} = qq|<input name="description_$i" size=40 value="$form->{"description_$i"}">|;
        $row{partsgroup}{data}  = qq|<input name="partsgroup_$i" size=10 value="$form->{"partsgroup_$i"}">|;
      }
    # other rows
    } else {
      if ($form->{previousform}) {
        push @row_hiddens,          qw(qty bom);
        $row{partnumber}{data}    = $form->{"partnumber_$i"};
        $row{qty}{data}           = $form->{"qty_$i"};
        $row{bom}{data}           = $form->{"bom_$i"} ? "x" : "&nbsp;";
        $row{qty}{align}          = 'right';
      } else {
        $row{partnumber}{data}    = qq|$form->{"partnumber_$i"}|;
        $row{partnumber}{link}     = $href;
        $row{qty}{data}           = qq|<input name="qty_$i" size=5 value="$form->{"qty_$i"}">|;
        $row{runningnumber}{data} = qq|<input name="runningnumber_$i" size=3 value="$i">|;
        $row{bom}{data}   = sprintf qq|<input name="bom_$i" type=checkbox class=checkbox value=1 %s>|,
                                       $form->{"bom_$i"} ? 'checked' : '';
      }
      push @row_hiddens,        qw(unit description partnumber partsgroup);
      $row{unit}{data}        = $form->{"unit_$i"};
      #Bei der Artikelbeschreibung und Warengruppe können Sonderzeichen verwendet
      #werden, die den HTML Code stören. Daher sollen diese im Template escaped werden
      #dies geschieht, wenn die Variable escape gesetzt ist
      $row{description}{data}   = $form->{"description_$i"};
      $row{description}{escape} = 1;
      $row{partsgroup}{data}    = $form->{"partsgroup_$i"};
      $row{partsgroup}{escape}  = 1;
      $row{bom}{align}          = 'center';
    }

    $row{lastcost}{data}      = $line_purchase_price;
    $row{total}{data}         = $linetotal;
    $row{lastcost}{align}     = 'right';
    $row{total}{align}        = 'right';
    $row{deliverydate}{align} = 'right';

    push @row_hiddens, qw(id sellprice lastcost weight price_factor_id price_factor);
    $row{hiddens} = [ map +{ name => "${_}_$i", value => $form->{"${_}_$i"} }, @row_hiddens ];

    push @ROWS, \%row;
  }

  print $form->parse_html_template('ic/assembly_row', { COLUMNS => \@column_index, ROWS => \@ROWS, HEADER => \%header });

  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  # update checks whether pricegroups, makemodels or assembly items have been changed/added
  # new items might have been added (and the original form might have been stored and restored)
  # so at the end the ic form is run through check_form in io.pl
  # The various combination of events can lead to problems with the order of parse_amount and format_amount
  # Currently check_form parses some variables in assembly mode, but not in article or service mode
  # This will only ever really be sanely resolved with a rewrite...

  # parse pricegroups. and no, don't rely on check_form for this...
  map { $form->{"price_$_"} = $form->parse_amount(\%myconfig, $form->{"price_$_"}) } 1 .. $form->{price_rows};

  unless ($form->{item} eq 'assembly') {
    # for assemblies check_form will parse sellprice and listprice, but not for parts or services
    $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) for qw(sellprice listprice ve gv);
  };

  if ($form->{item} eq 'part') {
    $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) for qw(weight rop);
  }

  # same for makemodel lastcosts
  # but parse_amount not necessary for assembly component lastcosts
  unless ($form->{item} eq "assembly") {
    map { $form->{"lastcost_$_"} = $form->parse_amount(\%myconfig, $form->{"lastcost_$_"}) } 1 .. $form->{"makemodel_rows"};
    $form->{lastcost} = $form->parse_amount(\%myconfig, $form->{lastcost});
  }

  if ($form->{item} eq "assembly") {
    my $i = $form->{assembly_rows};

    # if last row is empty check the form otherwise retrieve item
    if (   ($form->{"partnumber_$i"} eq "")
        && ($form->{"description_$i"} eq "")
        && ($form->{"partsgroup_$i"}  eq "")) {
      # no new assembly item was added

      &check_form;

    } else {
      # search db for newly added assemblyitems, via partnumber or description
      IC->assembly_item(\%myconfig, \%$form);

      # form->{item_list} contains the possible matches, next check whether the
      # match is unique or we need to call the page to select the item
      my $rows = scalar @{ $form->{item_list} };

      if ($rows) {
        $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});

        if ($rows > 1) {
          $form->{makemodel_rows}--;
          select_item(mode => 'IC', pre_entered_qty => $form->parse_amount(\%myconfig, $form->{"qty_$i"}));
          $::dispatcher->end_request;
        } else {
          map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g }
            qw(partnumber description unit partsgroup);
          map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} }
            keys %{ $form->{item_list}[0] };
          $form->{"runningnumber_$i"} = $form->{assembly_rows};
          $form->{assembly_rows}++;

          &check_form;

        }

      } else {

        $form->{rowcount} = $i;
        $form->{assembly_rows}++;

        &new_item;

      }
    }

  } elsif (($form->{item} eq 'part') || ($form->{item} eq 'service')) {
    &check_form;
  }

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');
  $::form->mtime_ischanged('parts');
  my ($parts_id, %newform, $amount, $callback);

  # check if there is a part number - commented out, cause there is an automatic allocation of numbers
  # $form->isblank("partnumber", $locale->text(ucfirst $form->{item}." Part Number missing!"));

  # check if there is a description
  $form->isblank("description", $locale->text("Part Description missing!"));

  $form->error($locale->text("Inventory quantity must be zero before you can set this $form->{item} obsolete!"))
    if $form->{obsolete} && $form->{onhand} * 1 && $form->{item} ne 'service';

  if (!$form->{buchungsgruppen_id}) {
    $form->error($locale->text("Parts must have an entry type.") . " " .
     $locale->text("If you see this message, you most likely just setup your LX-Office and haven't added any entry types. If this is the case, the option is accessible for administrators in the System menu.")
    );
  }

  $form->error($locale->text('Description must not be empty!')) unless $form->{description};
  $form->error($locale->text('Partnumber must not be set to empty!')) if $form->{id} && !$form->{partnumber};

  # undef warehouse_id if the empty value is selected
  if ( ($form->{warehouse_id} == 0) && ($form->{bin_id} == 0) ) {
    undef $form->{warehouse_id};
    undef $form->{bin_id};
  }
  # save part
  if (IC->save(\%myconfig, \%$form) == 3) {
    $form->error($locale->text('Partnumber not unique!'));
  }
  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers}  = qq|partnumber_| . $form->{partnumber};
    $form->{what_done} = "part";
    $form->{addition}  = "SAVED";
    $form->save_history;
  }
  # /saving the history
  $parts_id = $form->{id};

  my $i;
  # load previous variables
  if ($form->{previousform}) {

    # save the new form variables before splitting previousform
    map { $newform{$_} = $form->{$_} } keys %$form;

    # don't trample on previous variables
    map { delete $form->{$_} } keys %newform;

    my $ic_cvar_configs = CVar->get_configs(module => 'IC');
    my @ic_cvar_fields  = map { "cvar_$_->{name}" } @{ $ic_cvar_configs };

    # restore original values
    $::auth->restore_form_from_session($newform{previousform}, form => $form);
    $form->{taxaccounts} = $newform{taxaccount2};

    if ($form->{item} eq 'assembly') {

      # undo number formatting
      map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
        qw(weight listprice sellprice rop);

      $form->{assembly_rows}--;
      if ($newform{currow}) {
        $i = $newform{currow};
      } else {
        $i = $form->{assembly_rows};
      }
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"} > 0);

      $form->{sellprice} -= $form->{"sellprice_$i"} * $form->{"qty_$i"};
      $form->{weight}    -= $form->{"weight_$i"} * $form->{"qty_$i"};

      # change/add values for assembly item
      map { $form->{"${_}_$i"} = $newform{$_} } qw(partnumber description bin unit weight listprice sellprice inventory_accno income_accno expense_accno price_factor_id);
      map { $form->{"ic_${_}_$i"} = $newform{$_} } @ic_cvar_fields;

      # das ist __voll__ bekloppt, dass so auszurechnen jb 22.5.09
      #$form->{sellprice} += $form->{"sellprice_$i"} * $form->{"qty_$i"};
      $form->{weight}    += $form->{"weight_$i"} * $form->{"qty_$i"};

    } else {

      # set values for last invoice/order item
      $i = $form->{rowcount};
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"} > 0);

      map { $form->{"${_}_$i"} = $newform{$_} } qw(partnumber description bin unit listprice inventory_accno income_accno expense_accno sellprice lastcost price_factor_id);
      map { $form->{"ic_${_}_$i"} = $newform{$_} } @ic_cvar_fields;

      $form->{"longdescription_$i"} = $newform{notes};

      $form->{"sellprice_$i"} = $newform{lastcost} if ($form->{vendor_id});

      if ($form->{exchangerate} != 0) {
        $form->{"sellprice_$i"} /= $form->{exchangerate};
      }

      map { $form->{"taxaccounts_$i"} .= "$_ " } split / /, $newform{taxaccount};
      chop $form->{"taxaccounts_$i"};
      foreach my $item (qw(description rate taxnumber)) {
        my $index = $form->{"taxaccounts_$i"} . "_$item";
        $form->{$index} = $newform{$index};
      }

      # credit remaining calculation
      $amount = $form->{"sellprice_$i"} * (1 - $form->{"discount_$i"} / 100) * $form->{"qty_$i"};

      map { $form->{"${_}_base"} += $amount } (split / /, $form->{"taxaccounts_$i"});
      map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{"taxaccounts_$i"} if !$form->{taxincluded};

      $form->{creditremaining} -= $amount;

      # redo number formatting, because invoice parse them!
      map { $form->{"${_}_$i"} = $form->format_amount(\%myconfig, $form->{"${_}_$i"}) } qw(weight listprice sellprice lastcost rop);
    }

    $form->{"id_$i"} = $parts_id;

    # Get the actual price factor (not just the ID) for the marge calculation.
    $form->get_lists('price_factors' => 'ALL_PRICE_FACTORS');
    foreach my $pfac (@{ $form->{ALL_PRICE_FACTORS} }) {
      next if ($pfac->{id} != $newform{price_factor_id});
      $form->{"marge_price_factor_$i"} = $pfac->{factor};
      last;
    }
    delete $form->{ALL_PRICE_FACTORS};

    delete $form->{action};

    # restore original callback
    $callback = $form->unescape($form->{callback});
    $form->{callback} = $form->unescape($form->{old_callback});
    delete $form->{old_callback};

    $form->{makemodel_rows}--;

    # put callback together
    foreach my $key (keys %$form) {

      # do single escape for Apache 2.0
      my $value = $form->escape($form->{$key}, 1);
      $callback .= qq|&$key=$value|;
    }
    $form->{callback} = $callback;
  }

  # redirect
  $form->redirect;

  $lxdebug->leave_sub();
}

sub save_as_new {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers}  = qq|partnumber_| . $form->{partnumber};
    $form->{addition}  = "SAVED AS NEW";
    $form->{what_done} = "part";
    $form->save_history;
  }
  # /saving the history
  $form->{id} = 0;
  if ($form->{"original_partnumber"} &&
      ($form->{"partnumber"} eq $form->{"original_partnumber"})) {
    $form->{partnumber} = "";
  }
  &save;
  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_edit');

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers}  = qq|partnumber_| . $form->{partnumber};
    $form->{addition}  = "DELETED";
    $form->{what_done} = "part";
    $form->save_history;
  }
  # /saving the history
  my $rc = IC->delete(\%myconfig, \%$form);

  # redirect
  $form->redirect($locale->text('Item deleted!')) if ($rc > 0);
  $form->error($locale->text('Cannot delete item!'));

  $lxdebug->leave_sub();
}

sub price_row {
  $lxdebug->enter_sub();

  $auth->assert('part_service_assembly_details');

  my ($numrows) = @_;

  my @PRICES = map +{
    pricegroup    => $form->{"pricegroup_$_"},
    pricegroup_id => $form->{"pricegroup_id_$_"},
    price         => $form->{"price_$_"},
  }, 1 .. $numrows;

  print $form->parse_html_template('ic/price_row', { PRICES => \@PRICES });

  $lxdebug->leave_sub();
}

sub ajax_autocomplete {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $form->{column}          = 'description'     unless $form->{column} =~ /^partnumber|description$/;
  $form->{$form->{column}} = $form->{q}           || '';
  $form->{limit}           = ($form->{limit} * 1) || 10;
  $form->{searchitems}   ||= '';

  my @results = IC->all_parts(\%myconfig, $form);

  print $form->ajax_response_header(),
        $form->parse_html_template('ic/ajax_autocomplete');

  $main::lxdebug->leave_sub();
}

sub display_form {
  $::lxdebug->enter_sub;

  $auth->assert('part_service_assembly_edit');

  relink_accounts();

  $::form->language_payment(\%::myconfig);

  Common::webdav_folder($::form);

  form_header();
  price_row($::form->{price_rows});
  makemodel_row(++$::form->{makemodel_rows}) if $::form->{item} =~ /^(part|service)$/;
  assembly_row(++$::form->{assembly_rows})   if $::form->{item} eq 'assembly';

  form_footer();

  $::lxdebug->leave_sub;
}

sub back_to_record {
  _check_io_auth();


  delete @{$::form}{qw(action action_add action_back_to_record back_sub description item notes partnumber sellprice taxaccount2 unit vc)};

  $::auth->restore_form_from_session($::form->{previousform}, clobber => 1);
  $::form->{rowcount}--;
  $::form->{action}   = 'display_form';
  $::form->{callback} = $::form->{script} . '?' . join('&', map { $::form->escape($_) . '=' . $::form->escape($::form->{$_}) } sort keys %{ $::form });
  $::form->redirect;
}

sub continue { call_sub($form->{"nextsub"}); }

sub dispatcher {
  my $action = first { $::form->{"action_${_}"} } qw(add back_to_record);
  $::form->error($::locale->text('No action defined.')) unless $action;

  $::form->{dispatched_action} = $action;
  call_sub($action);
}
