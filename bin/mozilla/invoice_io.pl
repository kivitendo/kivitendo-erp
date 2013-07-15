#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#############################################################################
# Veraendert 2005-01-05 - Marco Welter <mawe@linux-studio.de> - Neue Optik  #
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
# common routines used in is, ir but not in oe
#
#######################################################################

use CGI;
use List::Util qw(max);

use SL::Common;
use SL::CT;
use SL::IC;

require "bin/mozilla/common.pl";

use strict;

# any custom scripts for this one
if (-f "bin/mozilla/custom_invoice_io.pl") {
  eval { require "bin/mozilla/custom_invoice_io.pl"; };
}
if (-f "bin/mozilla/$main::form->{login}_invoice_io.pl") {
  eval { require "bin/mozilla/$main::form->{login}_invoice_io.pl"; };
}

1;

# end of main

# this is for our long dates
# $locale->text('January')
# $locale->text('February')
# $locale->text('March')
# $locale->text('April')
# $locale->text('May ')
# $locale->text('June')
# $locale->text('July')
# $locale->text('August')
# $locale->text('September')
# $locale->text('October')
# $locale->text('November')
# $locale->text('December')

# this is for our short month
# $locale->text('Jan')
# $locale->text('Feb')
# $locale->text('Mar')
# $locale->text('Apr')
# $locale->text('May')
# $locale->text('Jun')
# $locale->text('Jul')
# $locale->text('Aug')
# $locale->text('Sep')
# $locale->text('Oct')
# $locale->text('Nov')
# $locale->text('Dec')
use SL::IS;
use SL::PE;
use SL::AM;
use Data::Dumper;

sub set_pricegroup {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  my $rowcount = shift;
  for my $j (1 .. $rowcount) {
    my $pricegroup_old = $form->{"pricegroup_old_$j"};
    if ($form->{PRICES}{$j}) {
      my $len    = 0;
      my $prices = '<option value="--">' . $locale->text("none (pricegroup)") . '</option>';
      my $price  = 0;
      foreach my $item (@{ $form->{PRICES}{$j} }) {

        #$price = $form->round_amount($myconfig,  $item->{price}, 5);
        #$price = $form->format_amount($myconfig, $item->{price}, 2);
        my $price         = $item->{price};
        my $pricegroup_id = $item->{pricegroup_id};
        my $pricegroup    = $item->{pricegroup};

        # build drop down list for pricegroups
        $prices .=
          qq|<option value="$price--$pricegroup_id"$item->{selected}>$pricegroup</option>\n|;

        $len += 1;

        #        map {
        #               $form->{"${_}_$j"} =
        #               $form->format_amount(\%myconfig, $form->{"${_}_$j"})
        #              } qw(sellprice price_new price_old);

        # set new selectedpricegroup_id and prices for "Preis"
        if ($item->{selected} && ($pricegroup_id != 0)) {
          $form->{"pricegroup_old_$j"} = $pricegroup_id;
          $form->{"price_new_$j"}      = $price;
          # edit: don't change the sellprice here
          # $form->{"sellprice_$j"}      = $price;   # this must only be updated for existing articles, not new ones
        }
        if ($pricegroup_id == 0) {
          $form->{"price_new_$j"} = $form->{"sellprice_$j"};
        }
      }
      $form->{"prices_$j"} = $prices;
    }
  }
  $main::lxdebug->leave_sub();
}

sub display_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('part_service_assembly_edit   | vendor_invoice_edit       | sales_order_edit    | invoice_edit |' .
                'request_quotation_edit       | sales_quotation_edit      | purchase_order_edit | '.
                'purchase_delivery_order_edit | sales_delivery_order_edit | part_service_assembly_details');

  relink_accounts();
  retrieve_partunits() if ($form->{type} =~ /_delivery_order$/);

  my $new_rowcount = $form->{"rowcount"} * 1 + 1;
  $form->{"project_id_${new_rowcount}"} = $form->{"globalproject_id"};

  $form->language_payment(\%myconfig);

  # if we have a display_form
  if ($form->{display_form}) {
    call_sub($form->{"display_form"});
    ::end_of_request();
  }

  Common::webdav_folder($form);

  #   if (   $form->{print_and_post}
  #       && $form->{second_run}
  #       && ($form->{action} eq "display_form")) {
  #     for (keys %$form) { $old_form->{$_} = $form->{$_} }
  #     $old_form->{rowcount}++;
  #
  #     #$form->{rowcount}--;
  #     #$form->{rowcount}--;
  #
  #     $form->{print_and_post} = 0;
  #
  #     &print_form($old_form);
  #     ::end_of_request();
  #   }
  #
  #   $form->{action}   = "";
  #   $form->{resubmit} = 0;
  #
  #   if ($form->{print_and_post} && !$form->{second_run}) {
  #     $form->{second_run} = 1;
  #     $form->{action}     = "display_form";
  #     $form->{rowcount}--;
  #     my $rowcount = $form->{rowcount};
  #
  #     # get pricegroups for parts
  #     IS->get_pricegroups_for_parts(\%myconfig, \%$form);
  #
  #     # build up html code for prices_$i
  #     set_pricegroup($rowcount);
  #
  #     $form->{resubmit} = 1;
  #
  #   }
  &form_header;

  {
    no strict 'refs';

    my $numrows    = ++$form->{rowcount};
    my $subroutine = "display_row";

    if ($form->{item} =~ /(part|service)/) {
      #set preisgruppenanzahl
      $numrows    = $form->{price_rows};
      $subroutine = "price_row";

      &{$subroutine}($numrows);

      $numrows    = ++$form->{makemodel_rows};
      $subroutine = "makemodel_row";
    }
    if ($form->{item} eq 'assembly') {
      $numrows    = $form->{price_rows};
      $subroutine = "price_row";

      &{$subroutine}($numrows);

      $numrows    = ++$form->{makemodel_rows};
      $subroutine = "makemodel_row";

      # assemblies are built from components, they aren't purchased from a vendor
      # also the lastcost_$i from makemodel conflicted with the component lastcost_$i
      # so we don't need the makemodel rows for assemblies
      # create makemodel rows
      # &{$subroutine}($numrows);

      $numrows    = ++$form->{assembly_rows};
      $subroutine = "assembly_row";
    }

    # create rows
    &{$subroutine}($numrows) if $numrows;
  }

  &form_footer;

  $main::lxdebug->leave_sub();
}
