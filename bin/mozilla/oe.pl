#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger, Accounting
# Copyright (c) 1998-2003
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
# Order entry module
# Quotation module
#======================================================================

use POSIX qw(strftime);

use SL::DO;
use SL::FU;
use SL::OE;
use SL::IR;
use SL::IS;
use SL::PE;
use SL::ReportGenerator;
use List::Util qw(max reduce sum);
use Data::Dumper;

require "bin/mozilla/io.pl";
require "bin/mozilla/arap.pl";
require "bin/mozilla/reportgenerator.pl";

1;

# end of main

# For locales.pl:
# $locale->text('Edit the purchase_order');
# $locale->text('Edit the sales_order');
# $locale->text('Edit the request_quotation');
# $locale->text('Edit the sales_quotation');

# $locale->text('Workflow purchase_order');
# $locale->text('Workflow sales_order');
# $locale->text('Workflow request_quotation');
# $locale->text('Workflow sales_quotation');

my $oe_access_map = {
  'sales_order'       => 'sales_order_edit',
  'purchase_order'    => 'purchase_order_edit',
  'request_quotation' => 'request_quotation_edit',
  'sales_quotation'   => 'sales_quotation_edit',
};

sub check_oe_access {
  my $right   = $oe_access_map->{$form->{type}};
  $right    ||= 'DOES_NOT_EXIST';

  $auth->assert($right);
}

sub set_headings {
  $lxdebug->enter_sub();

  check_oe_access();

  my ($action) = @_;

  if ($form->{type} eq 'purchase_order') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Purchase Order') :
      $locale->text('Add Purchase Order');
    $form->{heading} = $locale->text('Purchase Order');
    $form->{vc}      = 'vendor';
  }
  if ($form->{type} eq 'sales_order') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Sales Order') :
      $locale->text('Add Sales Order');
    $form->{heading} = $locale->text('Sales Order');
    $form->{vc}      = 'customer';
  }
  if ($form->{type} eq 'request_quotation') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Request for Quotation') :
      $locale->text('Add Request for Quotation');
    $form->{heading} = $locale->text('Request for Quotation');
    $form->{vc}      = 'vendor';
  }
  if ($form->{type} eq 'sales_quotation') {
    $form->{title}   = $action eq "edit" ?
      $locale->text('Edit Quotation') :
      $locale->text('Add Quotation');
    $form->{heading} = $locale->text('Quotation');
    $form->{vc}      = 'customer';
  }

  $lxdebug->leave_sub();
}

sub add {
  $lxdebug->enter_sub();

  check_oe_access();

  set_headings("add");

  $form->{callback} =
    "$form->{script}?action=add&type=$form->{type}&vc=$form->{vc}"
    unless $form->{callback};

  &order_links;
  &prepare_order;
  &display_form;

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  check_oe_access();

  # show history button
  $form->{javascript} = qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  #/show hhistory button

  $form->{simple_save} = 0;

  set_headings("edit");

  # editing without stuff to edit? try adding it first
  if ($form->{rowcount} && !$form->{print_and_save}) {
    map { $id++ if $form->{"multi_id_$_"} } (1 .. $form->{rowcount});
    if (!$id) {

      # reset rowcount
      undef $form->{rowcount};
      &add;
      $lxdebug->leave_sub();
      return;
    }
  } elsif (!$form->{id}) {
    &add;
    $lxdebug->leave_sub();
    return;
  }

  if ($form->{print_and_save}) {
    $form->{action}   = "print";
    $form->{resubmit} = 1;
    $language_id = $form->{language_id};
    $printer_id = $form->{printer_id};
  }

  set_headings("edit");

  &order_links;

  $form->{rowcount} = 0;
  foreach $ref (@{ $form->{form_details} }) {
    $form->{rowcount}++;
    map { $form->{"${_}_$form->{rowcount}"} = $ref->{$_} } keys %{$ref};
  }

  &prepare_order;

  if ($form->{print_and_save}) {
    $form->{language_id} = $language_id;
    $form->{printer_id} = $printer_id;
  }

  &display_form;

  $lxdebug->leave_sub();
}

sub order_links {
  $lxdebug->enter_sub();

  check_oe_access();

  # get customer/vendor
  $form->all_vc(\%myconfig, $form->{vc}, ($form->{vc} eq 'customer') ? "AR" : "AP");

  # retrieve order/quotation
  $form->{webdav}   = $webdav;
  $form->{jsscript} = 1;

  my $editing = $form->{id};
  $form->backup_vars(qw(payment_id language_id taxzone_id salesman_id taxincluded cp_id intnotes));

  OE->retrieve(\%myconfig, \%$form);

  # if multiple rowcounts (== collective order) then check if the
  # there were more than one customer (in that case OE::retrieve removes
  # the content from the field)
  $form->error($locale->text('Collective Orders only work for orders from one customer!'))
    if          $form->{rowcount}  && $form->{type}     eq 'sales_order'
     && defined $form->{customer}  && $form->{customer} eq '';

  $form->{"$form->{vc}_id"} ||= $form->{"all_$form->{vc}"}->[0]->{id} if $form->{"all_$form->{vc}"};

  $form->{shipto} = 1 if $form->{id};

  # get customer / vendor
  IR->get_vendor(\%myconfig, \%$form)   if $form->{type} =~ /(purchase_order|request_quotation)/;
  IS->get_customer(\%myconfig, \%$form) if $form->{type} =~ /sales_(order|quotation)/;

  $form->restore_vars(qw(payment_id language_id taxzone_id intnotes cp_id));
  $form->restore_vars(qw(taxincluded)) if $form->{id};
  $form->restore_vars(qw(salesman_id)) if $editing;
  $form->{forex}       = $form->{exchangerate};
  $form->{employee}    = "$form->{employee}--$form->{employee_id}";

  # build vendor/customer drop down comatibility... don't ask
  if (@{ $form->{"all_$form->{vc}"} }) {
    $form->{"select$form->{vc}"} = 1;
    $form->{$form->{vc}}         = qq|$form->{$form->{vc}}--$form->{"$form->{vc}_id"}|;
  }

  $form->{"old$form->{vc}"}  = $form->{$form->{vc}};
  $form->{"old$form->{vc}"} .= qq|--$form->{"$form->{vc}_id"}| unless ($form->{"old$form->{vc}"} =~ m/--\d+$/);

  $lxdebug->leave_sub();
}

sub prepare_order {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{formname} ||= $form->{type};

  # format discounts if values come from db. either as single id, or as a collective order
  my $format_discounts = $form->{id} || $form->{convert_from_oe_ids};

  for my $i (1 .. $form->{rowcount}) {
    $form->{"reqdate_$i"} ||= $form->{"deliverydate_$i"};
    $form->{"discount_$i"}  = $form->format_amount(\%myconfig, $form->{"discount_$i"} * ($format_discounts ? 100 : 1));
    $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"});
    $form->{"qty_$i"}       = $form->format_amount(\%myconfig, $form->{"qty_$i"});
  }

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub();
  my @custom_hiddens;

  check_oe_access();

  # Container for template variables. Unfortunately this has to be visible in form_footer too, so not my.
  our %TMPL_VAR = ();

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  $form->{employee_id} = $form->{old_employee_id} if $form->{old_employee_id};
  $form->{salesman_id} = $form->{old_salesman_id} if $form->{old_salesman_id};

  # use JavaScript Calendar or not
  $form->{jsscript} = 1;

  # openclosed checkboxes
  my @tmp;
  push @tmp, sprintf qq|<input name="delivered" id="delivered" type="checkbox" class="checkbox" value="1" %s><label for="delivered">%s</label>|,
                        $form->{"delivered"} ? "checked" : "",  $locale->text('Delivered') if $form->{"type"} =~ /_order$/;
  push @tmp, sprintf qq|<input name="closed" id="closed" type="checkbox" class="checkbox" value="1" %s><label for="closed">%s</label>|,
                        $form->{"closed"}    ? "checked" : "",  $locale->text('Closed')    if $form->{id};
  $TMPL_VAR{openclosed} = sprintf qq|<tr><td colspan=%d align=center>%s</td></tr>\n|, 2 * scalar @tmp, join "\n", @tmp if @tmp;

  # project ids
  my @old_project_ids = ($form->{"globalproject_id"}, grep { $_ } map { $form->{"project_id_$_"} } 1..$form->{"rowcount"});

  my $vc = $form->{vc} eq "customer" ? "customers" : "vendors";
  $form->get_lists("contacts"      => "ALL_CONTACTS",
                   "shipto"        => "ALL_SHIPTO",
                   "projects"      => { "key"      => "ALL_PROJECTS",
                                        "all"      => 0,
                                        "old_id"   => \@old_project_ids },
                   "employees"     => "ALL_EMPLOYEES",
                   "salesmen"      => "ALL_SALESMEN",
                   "taxzones"      => "ALL_TAXZONES",
                   "payments"      => "ALL_PAYMENTS",
                   "currencies"    => "ALL_CURRENCIES",
                   "departments"   => "ALL_DEPARTMENTS",
                   $vc             => { key   => "ALL_" . uc($vc),
                                        limit => $myconfig{vclimit} + 1 },
                   "price_factors" => "ALL_PRICE_FACTORS");

  # label subs
  $TMPL_VAR{sales_employee_labels} = sub { $_[0]->{name} || $_[0]->{login} };
  $TMPL_VAR{shipto_labels}         = sub { join "; ", grep { $_ } map { $_[0]->{"shipto${_}" } } qw(name department_1 street city) };
  $TMPL_VAR{contact_labels}        = sub { join(', ', $_[0]->{"cp_name"}, $_[0]->{"cp_givenname"}) . ($_[0]->{cp_abteilung} ? " ($_[0]->{cp_abteilung})" : "") };
  $TMPL_VAR{department_labels}     = sub { "$_[0]->{description}--$_[0]->{id}" };

  # vendor/customer
  $TMPL_VAR{vc_keys} = sub { "$_[0]->{name}--$_[0]->{id}" };
  $TMPL_VAR{vclimit} = $myconfig{vclimit};
  $TMPL_VAR{vc_select} = "customer_or_vendor_selection_window('$form->{vc}', '', @{[ $form->{vc} eq 'vendor' ? 1 : 0 ]}, 0)";
  push @custom_hiddens, "$form->{vc}_id";
  push @custom_hiddens, "old$form->{vc}";
  push @custom_hiddens, "select$form->{vc}";

  # currencies and exchangerate
  @values = map { $_ } @{ $form->{ALL_CURRENCIES} };
  %labels = map { $_ => $_ } @{ $form->{ALL_CURRENCIES} };
  $form->{currency}            = $form->{defaultcurrency} unless $form->{currency};
  $TMPL_VAR{show_exchangerate} = $form->{currency} ne $form->{defaultcurrency};
  $TMPL_VAR{currencies}        = NTI($cgi->popup_menu('-name' => 'currency', '-default' => $form->{"currency"},
                                                      '-values' => \@values, '-labels' => \%labels)) if scalar @values;
  push @custom_hiddens, "forex";
  push @custom_hiddens, "exchangerate" if $form->{forex};

  # credit remaining
  $creditwarning = (($form->{creditlimit} != 0) && ($form->{creditremaining} < 0) && !$form->{update}) ? 1 : 0;
  $TMPL_VAR{is_credit_remaining_negativ} = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  # business
  $TMPL_VAR{business_label} = ($form->{vc} eq "customer" ? $locale->text('Customer type') : $locale->text('Vendor type'));

  push @custom_hiddens, "customer_klass" if $form->{vc} eq 'customer';

  $credittext = $locale->text('Credit Limit exceeded!!!');

  my $follow_up_vc                =  $form->{ $form->{vc} eq 'customer' ? 'customer' : 'vendor' };
  $follow_up_vc                   =~ s/--.*?//;
  $TMPL_VAR{follow_up_trans_info} =  ($form->{type} =~ /_quotation$/ ? $form->{quonumber} : $form->{ordnumber}) . " ($follow_up_vc)";

  if ($form->{id}) {
    my $follow_ups = FU->follow_ups('trans_id' => $form->{id});

    if (scalar @{ $follow_ups }) {
      $TMPL_VAR{num_follow_ups}     = scalar                    @{ $follow_ups };
      $TMPL_VAR{num_due_follow_ups} = sum map { $_->{due} * 1 } @{ $follow_ups };
    }
  }

  $onload = ($form->{resubmit} && ($form->{format} eq "html")) ? "window.open('about:blank','Beleg'); document.oe.target = 'Beleg';document.oe.submit()"
          : ($form->{resubmit})                                ? "document.oe.submit()"
          : ($creditwarning)                                   ? "alert('$credittext')"
          :                                                      "focus()";

  $onload .= qq|;setupDateFormat('|. $myconfig{dateformat} .qq|', '|. $locale->text("Falsches Datumsformat!") .qq|')|;
  $onload .= qq|;setupPoints('|.   $myconfig{numberformat} .qq|', '|. $locale->text("wrongformat") .qq|')|;
  $TMPL_VAR{onload} = $onload;

  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_form_details.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_history.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_vc_details.js"></script>|;

  $form->header;

  $TMPL_VAR{HIDDENS} = [ map { name => $_, value => $form->{$_} },
     qw(id action type vc formname media format proforma queued printed emailed
        title creditlimit creditremaining tradediscount business
        max_dunning_level dunning_amount shiptoname shiptostreet shiptozipcode
        shiptocity shiptocountry shiptocontact shiptophone shiptofax
        shiptodepartment_1 shiptodepartment_2 shiptoemail
        message email subject cc bcc taxpart taxservice taxaccounts cursor_fokus),
        @custom_hiddens,
        map { $_.'_rate', $_.'_description' } split / /, $form->{taxaccounts} ];  # deleted: discount

  %TMPL_VAR = (
     %TMPL_VAR,
     is_sales        => scalar ($form->{type} =~ /^sales_/),              # these vars are exported, so that the template
     is_order        => scalar ($form->{type} =~ /_order$/),              # may determine what to show
     is_sales_quo    => scalar ($form->{type} =~ /sales_quotation$/),
     is_req_quo      => scalar ($form->{type} =~ /request_quotation$/),
     is_sales_ord    => scalar ($form->{type} =~ /sales_order$/),
     is_pur_ord      => scalar ($form->{type} =~ /purchase_order$/),
  );

  print $form->parse_html_template("oe/form_header", { %TMPL_VAR });

  $lxdebug->leave_sub();
}

sub form_footer {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{invtotal} = $form->{invsubtotal};

  $rows    = max 2, $form->numtextrows($form->{notes}, 25, 8);
  $introws = max 2, $form->numtextrows($form->{intnotes}, 35, 8);
  $rows    = max $rows, $introws;

  $TMPL_VAR{notes}    = qq|<textarea name=notes rows=$rows cols=25 wrap=soft>| . H($form->{notes}) . qq|</textarea>|;
  $TMPL_VAR{intnotes} = qq|<textarea name=intnotes rows=$introws cols=35 wrap=soft>| . H($form->{intnotes}) . qq|</textarea>|;

  if (!$form->{taxincluded}) {

    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{invtotal} += $form->{"${item}_total"} = $form->round_amount( $form->{"${item}_base"} * $form->{"${item}_rate"}, 2);
        $form->{"${item}_total"} = $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);

        $TMPL_VAR{tax} .= qq|
	      <tr>
		<th align=right>$form->{"${item}_description"}&nbsp;| . $form->{"${item}_rate"} * 100 .qq|%</th>
		<td align=right>$form->{"${item}_total"}</td>
	      </tr> |;
      }
    }

#    $form->{invsubtotal} = $form->format_amount(\%myconfig, $form->{invsubtotal}, 2, 0); # template does this

  } else {
    foreach $item (split / /, $form->{taxaccounts}) {
      if ($form->{"${item}_base"}) {
        $form->{"${item}_total"} = $form->round_amount( ($form->{"${item}_base"} * $form->{"${item}_rate"} / (1 + $form->{"${item}_rate"})), 2);
        $form->{"${item}_netto"} = $form->round_amount( ($form->{"${item}_base"} - $form->{"${item}_total"}), 2);
        $form->{"${item}_total"} = $form->format_amount(\%myconfig, $form->{"${item}_total"}, 2);
        $form->{"${item}_netto"} = $form->format_amount(\%myconfig, $form->{"${item}_netto"}, 2);

        $TMPL_VAR{tax} .= qq|
	      <tr>
		<th align=right>Enthaltene $form->{"${item}_description"}&nbsp;| . $form->{"${item}_rate"} * 100 .qq|%</th>
		<td align=right>$form->{"${item}_total"}</td>
	      </tr>
	      <tr>
	        <th align=right>Nettobetrag</th>
		<td align=right>$form->{"${item}_netto"}</td>
	      </tr> |;
      }
    }
  }

  $form->{oldinvtotal} = $form->{invtotal};

  print $form->parse_html_template("oe/form_footer", {
     %TMPL_VAR,
     webdav          => $webdav,
     print_options   => print_options(inline => 1),
     label_edit      => $locale->text("Edit the $form->{type}"),
     label_workflow  => $locale->text("Workflow $form->{type}"),
  });

  $lxdebug->leave_sub();
}

sub update {
  $lxdebug->enter_sub();

  my ($recursive_call) = shift;

  check_oe_access();

#  $main::lxdebug->message(0, Dumper($form));

  set_headings($form->{"id"} ? "edit" : "add");

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate) unless $recursive_call;
  $form->{update} = 1;

  $payment_id = $form->{payment_id} if $form->{payment_id};

  &check_name($form->{vc});

  $form->{payment_id} = $payment_id if $form->{payment_id} eq "";

  $buysell              = 'buy';
  $buysell              = 'sell' if ($form->{vc} eq 'vendor');
  $form->{forex}        = $form->check_exchangerate(\%myconfig, $form->{currency}, $form->{transdate}, $buysell);
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  $exchangerate = $form->{exchangerate} || 1;

##################### process items ######################################
  # for pricegroups
  $i = $form->{rowcount};
  if (   ($form->{"partnumber_$i"} eq "")
      && ($form->{"description_$i"} eq "")
      && ($form->{"partsgroup_$i"}  eq "")) {

    $form->{creditremaining} += ($form->{oldinvtotal} - $form->{oldtotalpaid});

    &check_form;
  } else {

    if ($form->{type} =~ /^sales/) {
      IS->retrieve_item(\%myconfig, \%$form);
    } else {
      IR->retrieve_item(\%myconfig, \%$form);
    }

    my $rows = scalar @{ $form->{item_list} };

    # hier ist das problem fuer bug 817 $form->{discount} wird nicht durchgeschliffen
    # ferner fallunterscheidung fuer verkauf oder einkauf s.a. bug 736	jb 04.05.2009 
    # select discount as vendor_discount from vendor || 
    # select discount as customer_discount from customer
    $form->{"discount_$i"} = $form->format_amount(\%myconfig, $form->{"$form->{vc}_discount"} * 100);

    if ($rows) {
      $form->{"qty_$i"} = 1 unless ($form->{"qty_$i"});

      if ($rows > 1) {

        &select_item;
        exit;

      } else {

        $sellprice             = $form->parse_amount(\%myconfig, $form->{"sellprice_$i"});
        $form->{"discount_$i"} = 0 if $form->{"not_discountable_$i"};
        map { $form->{item_list}[$i]{$_} =~ s/\"/&quot;/g }    qw(partnumber description unit);
        map { $form->{"${_}_$i"} = $form->{item_list}[0]{$_} } keys %{ $form->{item_list}[0] };
        $form->{payment_id} = $form->{"part_payment_id_$i"} if $form->{"part_payment_id_$i"} ne "";

        $form->{"marge_price_factor_$i"} = $form->{item_list}->[0]->{price_factor};

        ($sellprice || $form->{"sellprice_$i"}) =~ /\.(\d+)/;
        $decimalplaces = max 2, length $1;

        if ($sellprice) {
          $form->{"sellprice_$i"} = $sellprice;
        } else {
          $form->{"sellprice_$i"} *= (1 - $form->{tradediscount});
          $form->{"sellprice_$i"} /= $exchangerate;   # if there is an exchange rate adjust sellprice
        }

        $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * (1 - $form->{"discount_$i"} / 100);
        map { $form->{"${_}_base"} = 0 }                                 split / /, $form->{taxaccounts};
        map { $form->{"${_}_base"} += $amount }                          split / /, $form->{"taxaccounts_$i"};
        map { $amount += ($form->{"${_}_base"} * $form->{"${_}_rate"}) } split / /, $form->{taxaccounts} if !$form->{taxincluded};

        $form->{creditremaining} -= $amount;

        $form->{"sellprice_$i"} = $form->format_amount(\%myconfig, $form->{"sellprice_$i"}, $decimalplaces);
        $form->{"qty_$i"}       = $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);

        # get pricegroups for parts
        IS->get_pricegroups_for_parts(\%myconfig, \%$form);

        # build up html code for prices_$i
        &set_pricegroup($i);
      }

      display_form();
    } else {

      # ok, so this is a new part
      # ask if it is a part or service item

      if (   $form->{"partsgroup_$i"}
          && ($form->{"partsnumber_$i"} eq "")
          && ($form->{"description_$i"} eq "")) {
        $form->{rowcount}--;
        $form->{"discount_$i"} = "";

        display_form();
      } else {
        $form->{"id_$i"}   = 0;
        new_item();
      }
    }
  }
##################### process items ######################################


  $lxdebug->leave_sub();
}

sub search {
  $lxdebug->enter_sub();

  check_oe_access();

  if ($form->{type} eq 'purchase_order') {
    $form->{title} = $locale->text('Purchase Orders');
    $form->{vc}    = 'vendor';
    $ordlabel      = $locale->text('Order Number');
    $ordnumber     = 'ordnumber';
    $employee      = $locale->text('Employee');
  }

  if ($form->{type} eq 'request_quotation') {
    $form->{title} = $locale->text('Request for Quotations');
    $form->{vc}    = 'vendor';
    $ordlabel      = $locale->text('RFQ Number');
    $ordnumber     = 'quonumber';
    $employee      = $locale->text('Employee');
  }

  if ($form->{type} eq 'sales_order') {
    $form->{title} = $locale->text('Sales Orders');
    $form->{vc}    = 'customer';
    $ordlabel      = $locale->text('Order Number');
    $ordnumber     = 'ordnumber';
    $employee      = $locale->text('Employee');
  }

  if ($form->{type} eq 'sales_quotation') {
    $form->{title} = $locale->text('Quotations');
    $form->{vc}    = 'customer';
    $ordlabel      = $locale->text('Quotation Number');
    $ordnumber     = 'quonumber';
    $employee      = $locale->text('Employee');
  }

  # setup vendor / customer selection
  $form->all_vc(\%myconfig, $form->{vc},
                ($form->{vc} eq 'customer') ? "AR" : "AP");

  # departments
  if (@{ $form->{all_departments} }) {
    $form->{selectdepartment} = "<option>\n";

    map {
      $form->{selectdepartment} .=
        "<option>$_->{description}--$_->{id}</option>\n"
    } (@{ $form->{all_departments} });
  }

  $department = qq|
        <tr>
	  <th align=right nowrap>| . $locale->text('Department') . qq|</th>
	  <td colspan=3><select name=department>$form->{selectdepartment}</select></td>
	</tr>
| if $form->{selectdepartment};

  my $delivered;
  if (($form->{"type"} eq "sales_order") ||
      ($form->{"type"} eq "purchase_order")) {
    $delivered = qq|
        <tr>
          <td><input name="notdelivered" id="notdelivered" class="checkbox" type="checkbox" value="1" checked>
            <label for="notdelivered">|. $locale->text('Not delivered') . qq|</label></td>
          <td><input name="delivered" id="delivered" class="checkbox" type="checkbox" value="1" checked>
            <label for="delivered">| . $locale->text('Delivered') . qq|</label></td>
        </tr>
|;
  }

  # use JavaScript Calendar or not
  $form->{jsscript} = 1;
  $jsscript = "";

  $button1 = qq|
     <td><input name=transdatefrom id=transdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
     <input type=button name=transdatefrom id="trigger3" value=|
    . $locale->text('button') . qq|></td>
    |;
  $button2 = qq|
     <td><input name=transdateto id=transdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
     <input type=button name=transdateto name=transdateto id="trigger4" value=|
    . $locale->text('button') . qq|></td>
   |;
  $button3 = qq|
     <td><input name=reqdatefrom id=reqdatefrom size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
     <input type=button name=reqdatefrom id="trigger5" value=|
    . $locale->text('button') . qq|></td>
    |;
  $button4 = qq|
     <td><input name=reqdateto id=reqdateto size=11 title="$myconfig{dateformat}" onBlur=\"check_right_date_format(this)\">
     <input type=button name=reqdateto name=reqdateto id="trigger6" value=|
    . $locale->text('button') . qq|></td>
   |;
 
  #write Trigger
  $jsscript =
   Form->write_trigger(\%myconfig, "4", "transdatefrom", "BR", "trigger3",
                       "transdateto", "BL", "trigger4",
                       "reqdatefrom", "BR", "trigger5", "reqdateto", "BL", "trigger6");

  my $vc = $form->{vc} eq "customer" ? "customers" : "vendors";

  $form->get_lists("projects"  => { "key" => "ALL_PROJECTS",
                                    "all" => 1 },
                   "employees" => "ALL_EMPLOYEES",
                   "salesmen"  => "ALL_SALESMEN",
                   $vc         => "ALL_" . uc($vc)
                  );

  my %labels = ();
  my @values = ("");
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"projectnumber"};
  }
  my $projectnumber =
    NTI($cgi->popup_menu('-name' => 'project_id', '-values' => \@values,
                         '-labels' => \%labels));

  #employees
  %labels = ();
  @values = ("");
  foreach my $item (@{ $form->{"ALL_EMPLOYEES"} }) {
    push(@values, $item->{"id"});
    $labels{$item->{"id"}} = $item->{"name"} ne "" ? $item->{"name"} : $item->{"login"};
  }

  #salesmen
  my %labels_salesmen = ();
  my @values_salesmen = ('');
  foreach my $item (@{ $form->{"ALL_SALESMEN"} }) {
    push(@values_salesmen, $item->{"id"});
    $labels_salesmen{$item->{"id"}} = $item->{"name"} ne "" ? $item->{"name"} : $item->{"login"};
  }

  my $employee_block = qq|
    <tr>
      <th align="right">| . $locale->text('Employee') . qq|</th>
      <td>| .  NTI($cgi->popup_menu('-name'   => 'employee_id', '-values' => \@values, '-labels' => \%labels)) . qq|</td>
    </tr>
    <tr>
      <th align="right">| . $locale->text('Salesman') . qq|</th>
      <td>| .
        NTI($cgi->popup_menu('-name'   => 'salesman_id',
                             '-values' => \@values_salesmen,
                             '-labels' => \%labels_salesmen)) . qq|
      </td>
    </tr>|;

  %labels = ();
  @values = ("");

  foreach my $item (@{ $form->{($form->{vc} eq "customer" ? "ALL_CUSTOMERS" : "ALL_VENDORS")}}) {
    push(@values, $item->{name}.qq|--|.$item->{"id"});
    $labels{$item->{name}.qq|--|.$item->{"id"}} = $item->{"name"};
  }

  my $vc_label = $form->{vc} eq "customer" ? $locale->text('Customer') : $locale->text('Vendor');
  $vc =
    $myconfig{vclimit} <=  scalar(@values)
    ? qq|<input type="text" value="| . H(($form->{"old$form->{vc}"} =~ /^(.*)\-\-.*$/)) . qq|" name="$form->{vc}">|
    : NTI($cgi->popup_menu('-name' => "$form->{vc}",
                           '-default' => $form->{"old$form->{vc}"},
                           '-onChange' => 'document.getElementById(\'update_button\').click();',
                           '-values' => \@values,
                           '-labels' => \%labels));
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
          <th align=right>$vc_label</th>
          <td colspan=3>$vc</td>
        </tr>
$department
        <tr>
          <th align=right>$ordlabel</th>
          <td colspan=3><input name="$ordnumber" size=20></td>
        </tr>
$employee_block
        <tr>
          <th align="right">| . $locale->text('Transaction description') . qq|</th>
          <td colspan="3"><input name="transaction_description" size=20></td>
        </tr>
        <tr>
          <th align="right">| . $locale->text("Project Number") . qq|</th>
          <td colspan="3">$projectnumber</td>
        </tr>
        <tr>
          <th align=right>| . $locale->text('Order Date') . " " . $locale->text('From') . qq|</th> $button1
          <th align=right>| . $locale->text('Bis') . qq|</th> $button2
        </tr>
        <input type=hidden name=sort value=transdate>
        <tr>
          <th align=right>| . $locale->text('Delivery Date') . " " . $locale->text('From') . qq|</th> $button3
          <th align=right>| . $locale->text('Bis') . qq|</th> $button4
        </tr>
        <input type=hidden name=sort value=reqdate>
        <tr>
          <th align=right>| . $locale->text('Include in Report') . qq|</th>
          <td colspan=5>
	    <table>
        <tr>
          <td><input type="checkbox" name="open" value="1" id="open" checked> <label for="open">| . $locale->text("Open") . qq|</td>
          <td><input type="checkbox" name="closed" value="1" id="closed"> <label for="closed">| . $locale->text("Closed") . qq|</td>
        </tr>
        $delivered
	      <tr>
		<td><input name="l_id" class=checkbox type=checkbox value=Y> | . $locale->text('ID') . qq|</td>
		<td><input name="l_$ordnumber" class=checkbox type=checkbox value=Y checked> $ordlabel</td>
	      </tr>
	      <tr>
		<td><input name="l_transdate" class=checkbox type=checkbox value=Y checked> | . $locale->text('Date') . qq|</td>
		<td><input name="l_reqdate" class=checkbox type=checkbox value=Y checked> | . $locale->text('Required by') . qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_name" class=checkbox type=checkbox value=Y checked> $vc_label</td>
	        <td><input name="l_employee" class=checkbox type=checkbox value=Y checked> $employee</td>

		<td><input name="l_shipvia" class=checkbox type=checkbox value=Y> | . $locale->text('Ship via') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_netamount" class=checkbox type=checkbox value=Y> | . $locale->text('Amount') . qq|</td>
		<td><input name="l_tax" class=checkbox type=checkbox value=Y> | . $locale->text('Tax') . qq|</td>
		<td><input name="l_amount" class=checkbox type=checkbox value=Y checked> | . $locale->text('Total') . qq|</td>
	      </tr>
	      <tr>
		<td><input name="l_marge_total" class=checkbox type=checkbox value=Y> | .             $locale->text('Ertrag') . qq|</td>
		<td><input name="l_marge_percent" class=checkbox type=checkbox value=Y> | .             $locale->text('Ertrag prozentual') . qq|</td>
	      </tr>
	      <tr>
          <td><input name="l_globalprojectnumber" class=checkbox type=checkbox value=Y> | . $locale->text('Project Number') . qq|</td>
          <td><input name="l_transaction_description" class=checkbox type=checkbox value=Y> | . $locale->text('Transaction description') . qq|</td>
	      </tr>
	      <tr>
	        <td><input name="l_subtotal" class=checkbox type=checkbox value=Y> | . $locale->text('Subtotal') . qq|</td>
                <td><input name="l_salesman" class="checkbox" type="checkbox" value="Y"> | . $locale->text('Salesman') . qq|</td>
	      </tr>
	    </table>
          </td>
        </tr>
      </table>
    </td>
  </tr>
  <tr><td colspan=4><hr size=3 noshade></td></tr>
</table>

$jsscript

<br>
<input type=hidden name=nextsub value=orders>
<input type=hidden name=vc value=$form->{vc}>
<input type=hidden name=type value=$form->{type}>

<input class=submit type=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub create_subtotal_row {
  $lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class) = @_;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } @{ $subtotal_columns };

  $row->{tax}->{data} = $form->format_amount(\%myconfig, $totals->{amount} - $totals->{netamount}, 2);

  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $lxdebug->leave_sub();

  return $row;
}

sub orders {
  $lxdebug->enter_sub();

  check_oe_access();

  $ordnumber = ($form->{type} =~ /_order$/) ? "ordnumber" : "quonumber";

  ($form->{ $form->{vc} }, $form->{"${form->{vc}}_id"}) = split(/--/, $form->{ $form->{vc} });

  report_generator_set_default_sort('transdate', 1);

  OE->transactions(\%myconfig, \%$form);

  $form->{rowcount} = scalar @{ $form->{OE} };

  my @columns = (
    "transdate",               "reqdate",
    "id",                      $ordnumber,
    "name",                    "netamount",
    "tax",                     "amount",
    "curr",                    "employee",
    "salesman",
    "shipvia",                 "globalprojectnumber",
    "transaction_description", "open",
    "delivered", "marge_total", "marge_percent"
  );

  # only show checkboxes if gotten here via sales_order form.
  my $allow_multiple_orders = $form->{type} eq 'sales_order';
  if ($allow_multiple_orders) {
    unshift @columns, "ids";
  }

  $form->{l_open}      = $form->{l_closed} = "Y" if ($form->{open}      && $form->{closed});
  $form->{l_delivered} = "Y"                     if ($form->{delivered} && $form->{notdelivered});

  my $attachment_basename;
  if ($form->{vc} eq 'vendor') {
    if ($form->{type} eq 'purchase_order') {
      $form->{title}       = $locale->text('Purchase Orders');
      $attachment_basename = $locale->text('purchase_order_list');
    } else {
      $form->{title}       = $locale->text('Request for Quotations');
      $attachment_basename = $locale->text('rfq_list');
    }

  } else {
    if ($form->{type} eq 'sales_order') {
      $form->{title}       = $locale->text('Sales Orders');
      $attachment_basename = $locale->text('sales_order_list');
    } else {
      $form->{title}       = $locale->text('Quotations');
      $attachment_basename = $locale->text('quotation_list');
    }
  }

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, "l_subtotal", $form->{vc}, qw(l_closed l_notdelivered open closed delivered notdelivered ordnumber quonumber
                                                        transaction_description transdatefrom transdateto type vc employee_id salesman_id
                                                        reqdatefrom reqdateto);

  my $href = build_std_url('action=orders', grep { $form->{$_} } @hidden_variables);

  my %column_defs = (
    'ids'                     => { 'text' => '', },
    'transdate'               => { 'text' => $locale->text('Date'), },
    'reqdate'                 => { 'text' => $locale->text('Required by'), },
    'id'                      => { 'text' => $locale->text('ID'), },
    'ordnumber'               => { 'text' => $locale->text('Order'), },
    'quonumber'               => { 'text' => $form->{type} eq "request_quotation" ? $locale->text('RFQ') : $locale->text('Quotation'), },
    'name'                    => { 'text' => $form->{vc} eq 'customer' ? $locale->text('Customer') : $locale->text('Vendor'), },
    'netamount'               => { 'text' => $locale->text('Amount'), },
    'tax'                     => { 'text' => $locale->text('Tax'), },
    'amount'                  => { 'text' => $locale->text('Total'), },
    'curr'                    => { 'text' => $locale->text('Curr'), },
    'employee'                => { 'text' => $locale->text('Employee'), },
    'salesman'                => { 'text' => $locale->text('Salesman'), },
    'shipvia'                 => { 'text' => $locale->text('Ship via'), },
    'globalprojectnumber'     => { 'text' => $locale->text('Project Number'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
    'open'                    => { 'text' => $locale->text('Open'), },
    'delivered'               => { 'text' => $locale->text('Delivered'), },
    'marge_total'             => { 'text' => $locale->text('Ertrag'), },
    'marge_percent'           => { 'text' => $locale->text('Ertrag prozentual'), }
  );

  foreach my $name (qw(id transdate reqdate quonumber ordnumber name employee salesman shipvia transaction_description)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  my %column_alignment = map { $_ => 'right' } qw(netamount tax amount curr);

  $form->{"l_type"} = "Y";
  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;
  $column_defs{ids}->{visible} = $allow_multiple_orders ? 'HTML' : 0;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options('orders', @hidden_variables, qw(sort sortdir));
  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my @options;
  my ($department) = split m/--/, $form->{department};

  push @options, $locale->text('Customer')                . " : $form->{customer}"                        if $form->{customer};
  push @options, $locale->text('Vendor')                  . " : $form->{vendor}"                          if $form->{vendor};
  push @options, $locale->text('Department')              . " : $department"                              if $form->{department};
  push @options, $locale->text('Order Number')            . " : $form->{ordnumber}"                       if $form->{ordnumber};
  push @options, $locale->text('Notes')                   . " : $form->{notes}"                           if $form->{notes};
  push @options, $locale->text('Transaction description') . " : $form->{transaction_description}"         if $form->{transaction_description};
  if ( $form->{transdatefrom} or $form->{transdateto} ) {
    push @options, $locale->text('Order Date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{transdatefrom}, 1)     if $form->{transdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{transdateto},   1)     if $form->{transdateto};
  };
  if ( $form->{reqdatefrom} or $form->{reqdateto} ) {
    push @options, $locale->text('Delivery Date');
    push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{reqdatefrom}, 1)       if $form->{reqdatefrom};
    push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{reqdateto},   1)       if $form->{reqdateto};
  };
  push @options, $locale->text('Open')                                                                    if $form->{open};
  push @options, $locale->text('Closed')                                                                  if $form->{closed};
  push @options, $locale->text('Delivered')                                                               if $form->{delivered};
  push @options, $locale->text('Not delivered')                                                           if $form->{notdelivered};

  $report->set_options('top_info_text'        => join("\n", @options),
                       'raw_top_info_text'    => $form->parse_html_template('oe/orders_top'),
                       'raw_bottom_info_text' => $form->parse_html_template('oe/orders_bottom', { 'SHOW_CONTINUE_BUTTON' => $allow_multiple_orders }),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $attachment_basename . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  $callback = $form->escape($href);

  my @subtotal_columns = qw(netamount amount marge_total marge_percent);

  my %totals    = map { $_ => 0 } @subtotal_columns;
  my %subtotals = map { $_ => 0 } @subtotal_columns;

  my $idx = 0;

  my $edit_url = build_std_url('action=edit', 'type', 'vc');

  foreach $oe (@{ $form->{OE} }) {
    map { $oe->{$_} *= $oe->{exchangerate} } @subtotal_columns;

    $oe->{tax}       = $oe->{amount} - $oe->{netamount};
    $oe->{open}      = $oe->{closed}    ? $locale->text('No')  : $locale->text('Yes');
    $oe->{delivered} = $oe->{delivered} ? $locale->text('Yes') : $locale->text('No');

    map { $subtotals{$_} += $oe->{$_};
          $totals{$_}    += $oe->{$_} } @subtotal_columns;

    $subtotals{marge_percent} = $subtotals{netamount} ? ($subtotals{marge_total} * 100 / $subtotals{netamount}) : 0;
    $totals{marge_percent}    = $totals{netamount}    ? ($totals{marge_total}    * 100 / $totals{netamount}   ) : 0;

    map { $oe->{$_} = $form->format_amount(\%myconfig, $oe->{$_}, 2) } qw(netamount tax amount marge_total marge_percent);

    my $row = { };

    foreach my $column (@columns) {
      next if ($column eq 'ids');
      $row->{$column} = {
        'data'  => $oe->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{ids} = {
      'raw_data' =>   $cgi->hidden('-name' => "trans_id_${idx}", '-value' => $oe->{id})
                    . $cgi->checkbox('-name' => "multi_id_${idx}", '-value' => 1, '-label' => ''),
      'valign'   => 'center',
      'align'    => 'center',
    };

    $row->{$ordnumber}->{link} = $edit_url . "&id=" . E($oe->{id}) . "&callback=${callback}";

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{OE} } - 1))
            || ($oe->{ $form->{sort} } ne $form->{OE}->[$idx + 1]->{ $form->{sort} }))) {
      push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, \@subtotal_columns, 'listsubtotal');
    }

    $report->add_data($row_set);

    $idx++;
  }

  $report->add_separator();
  $report->add_data(create_subtotal_row(\%totals, \@columns, \%column_alignment, \@subtotal_columns, 'listtotal'));

  $report->generate_with_headers();

  $lxdebug->leave_sub();
}

sub check_delivered_flag {
  $lxdebug->enter_sub();

  check_oe_access();

  if (($form->{type} ne 'sales_order') && ($form->{type} ne 'purchase_order')) {
    return $lxdebug->leave_sub();
  }

  my $all_delivered = 0;

  foreach my $i (1 .. $form->{rowcount}) {
    next if (!$form->{"id_$i"});

    if ($form->parse_amount(\%myconfig, $form->{"qty_$i"}) == $form->parse_amount(\%myconfig, $form->{"ship_$i"})) {
      $all_delivered = 1;
      next;
    }

    $all_delivered = 0;
    last;
  }

  $form->{delivered} = 1 if $all_delivered;

  $lxdebug->leave_sub();
}

sub save_and_close {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  if ($form->{type} =~ /_order$/) {
    $form->isblank("transdate", $locale->text('Order Date missing!'));
  } else {
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
  }

  my $idx = $form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber";
  $form->{$idx} =~ s/^\s*//g;
  $form->{$idx} =~ s/\s*$//g;

  $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc}, $locale->text($msg . " missing!"));

  # $locale->text('Customer missing!');
  # $locale->text('Vendor missing!');

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  &validate_items;

  if($form->{payment_id}) {
    $payment_id = $form->{payment_id};
  }

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    if($form->{payment_id} eq "") {
      $form->{payment_id} = $payment_id;
    }
    &update;
    exit;
  }

  $form->{id} = 0 if $form->{saveasnew};

  # this is for the internal notes section for the [email] Subject
  if ($form->{type} =~ /_order$/) {
    if ($form->{type} eq 'sales_order') {
      $form->{label} = $locale->text('Sales Order');

      $numberfld = "sonumber";
      $ordnumber = "ordnumber";
    } else {
      $form->{label} = $locale->text('Purchase Order');

      $numberfld = "ponumber";
      $ordnumber = "ordnumber";
    }

    $err = $locale->text('Cannot save order!');

    check_delivered_flag();

  } else {
    if ($form->{type} eq 'sales_quotation') {
      $form->{label} = $locale->text('Quotation');

      $numberfld = "sqnumber";
      $ordnumber = "quonumber";
    } else {
      $form->{label} = $locale->text('Request for Quotation');

      $numberfld = "rfqnumber";
      $ordnumber = "quonumber";
    }

    $err = $locale->text('Cannot save quotation!');

  }

  # get new number in sequence if no number is given or if saveasnew was requested
  if (!$form->{$ordnumber} || $form->{saveasnew}) {
    $form->{$ordnumber} = $form->update_defaults(\%myconfig, $numberfld);
  }

  relink_accounts();

  $form->error($err) if (!OE->save(\%myconfig, \%$form));

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->redirect($form->{label} . " $form->{$ordnumber} " .
                  $locale->text('saved!'));

  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);


  if ($form->{type} =~ /_order$/) {
    $form->isblank("transdate", $locale->text('Order Date missing!'));
  } else {
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
  }

  my $idx = $form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber";
  $form->{$idx} =~ s/^\s*//g;
  $form->{$idx} =~ s/\s*$//g;

  $msg = ucfirst $form->{vc};
  $form->isblank($form->{vc}, $locale->text($msg . " missing!"));

  # $locale->text('Customer missing!');
  # $locale->text('Vendor missing!');

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{currency} ne $form->{defaultcurrency});

  &validate_items;

  if($form->{payment_id}) {
    $payment_id = $form->{payment_id};
  }

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    if($form->{payment_id} eq "") {
      $form->{payment_id} = $payment_id;
    }
    &update;
    exit;
  }

  $form->{id} = 0 if $form->{saveasnew};

  # this is for the internal notes section for the [email] Subject
  if ($form->{type} =~ /_order$/) {
    if ($form->{type} eq 'sales_order') {
      $form->{label} = $locale->text('Sales Order');

      $numberfld = "sonumber";
      $ordnumber = "ordnumber";
    } else {
      $form->{label} = $locale->text('Purchase Order');

      $numberfld = "ponumber";
      $ordnumber = "ordnumber";
    }

    $err = $locale->text('Cannot save order!');

    check_delivered_flag();

  } else {
    if ($form->{type} eq 'sales_quotation') {
      $form->{label} = $locale->text('Quotation');

      $numberfld = "sqnumber";
      $ordnumber = "quonumber";
    } else {
      $form->{label} = $locale->text('Request for Quotation');

      $numberfld = "rfqnumber";
      $ordnumber = "quonumber";
    }

    $err = $locale->text('Cannot save quotation!');

  }

  $form->{$ordnumber} = $form->update_defaults(\%myconfig, $numberfld)
    unless $form->{$ordnumber};

  relink_accounts();

  OE->save(\%myconfig, \%$form);

  # saving the history
  if(!exists $form->{addition}) {
    $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
  	$form->{addition} = "SAVED";
  	$form->save_history($form->dbconnect(\%myconfig));
  }
  # /saving the history

  $form->{simple_save} = 1;
  if(!$form->{print_and_save}) {
    set_headings("edit");
    &update;
    exit;
  }
  $lxdebug->leave_sub();
}

sub delete {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->header;

  if ($form->{type} =~ /_order$/) {
    $msg       = $locale->text('Are you sure you want to delete Order Number');
    $ordnumber = 'ordnumber';
  } else {
    $msg = $locale->text('Are you sure you want to delete Quotation Number');
    $ordnumber = 'quonumber';
  }

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header);

  foreach $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>| . $locale->text('Confirm!') . qq|</h2>

<h4>$msg $form->{$ordnumber}</h4>
<p>
<input type="hidden" name="yes_nextsub" value="delete_order_quotation">
<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
<button class=submit type=button onclick="history.back()">|
    . $locale->text('No') . qq|</button>
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub delete_order_quotation {
  $lxdebug->enter_sub();

  check_oe_access();

  if ($form->{type} =~ /_order$/) {
    $msg = $locale->text('Order deleted!');
    $err = $locale->text('Cannot delete order!');
  } else {
    $msg = $locale->text('Quotation deleted!');
    $err = $locale->text('Cannot delete quotation!');
  }
  if (OE->delete(\%myconfig, \%$form, $spool)){
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers} = qq|ordnumber_| . $form->{ordnumber};
  	  $form->{addition} = "DELETED";
  	  $form->save_history($form->dbconnect(\%myconfig));
    }
    # /saving the history
    $form->info($msg);
    exit();
  }
  $form->error($err);

  $lxdebug->leave_sub();
}

sub invoice {
  $lxdebug->enter_sub();

  check_oe_access();
  $auth->assert($form->{type} eq 'purchase_order' || $form->{type} eq 'request_quotation' ? 'vendor_invoice_edit' : 'invoice_edit');

  $form->{old_employee_id} = $form->{employee_id};
  $form->{old_salesman_id} = $form->{salesman_id};

  if ($form->{type} =~ /_order$/) {

    # these checks only apply if the items don't bring their own ordnumbers/transdates.
    # The if clause ensures that by searching for empty ordnumber_#/transdate_# fields.
    $form->isblank("ordnumber", $locale->text('Order Number missing!'))
      if (+{ map { $form->{"ordnumber_$_"}, 1 } (1 .. $form->{rowcount} - 1) }->{''});
    $form->isblank("transdate", $locale->text('Order Date missing!'))
      if (+{ map { $form->{"transdate_$_"}, 1 } (1 .. $form->{rowcount} - 1) }->{''});

    # also copy deliverydate from the order
    $form->{deliverydate} = $form->{reqdate} if $form->{reqdate};
    $form->{orddate}      = $form->{transdate};
  } else {
    $form->isblank("quonumber", $locale->text('Quotation Number missing!'));
    $form->isblank("transdate", $locale->text('Quotation Date missing!'));
    $form->{ordnumber}    = "";
    $form->{quodate}      = $form->{transdate};
  }

  $payment_id = $form->{payment_id} if $form->{payment_id};

  # if the name changed get new values
  if (&check_name($form->{vc})) {
    $form->{payment_id} = $payment_id if $form->{payment_id} eq "";
    &update;
    exit;
  }

  $form->{cp_id} *= 1;

  for $i (1 .. $form->{rowcount}) {
    for (qw(ship qty sellprice listprice basefactor)) {
      $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"}) if $form->{"${_}_${i}"};
    }
  }

  if (   $form->{type} =~ /_order/
      && $form->{currency} ne $form->{defaultcurrency}) {

    # check if we need a new exchangerate
    $buysell = ($form->{type} eq 'sales_order') ? "buy" : "sell";

    $orddate      = $form->current_date(\%myconfig);
    $exchangerate = $form->check_exchangerate(\%myconfig, $form->{currency}, $orddate, $buysell);

    if (!$exchangerate) {
      &backorder_exchangerate($orddate, $buysell);
      exit;
    }
  }

  $form->{convert_from_oe_ids} = $form->{id};
  $form->{transdate}           = $form->{invdate} = $form->current_date(\%myconfig);
  $form->{duedate}             = $form->current_date(\%myconfig, $form->{invdate}, $form->{terms} * 1);
  $form->{shipto}              = 1;
  $form->{defaultcurrency}     = $form->get_default_currency(\%myconfig);

  delete @{$form}{qw(id closed)};
  $form->{rowcount}--;

  if ($form->{type} =~ /_order$/) {
    $form->{exchangerate} = $exchangerate;
    &create_backorder;
  }

  if (   $form->{type} eq 'purchase_order'
      || $form->{type} eq 'request_quotation') {
    $form->{title}  = $locale->text('Add Vendor Invoice');
    $form->{script} = 'ir.pl';
    $script         = "ir";
    $buysell        = 'sell';
  }

  if (   $form->{type} eq 'sales_order'
      || $form->{type} eq 'sales_quotation') {
    $form->{title}  = $locale->text('Add Sales Invoice');
    $form->{script} = 'is.pl';
    $script         = "is";
    $buysell        = 'buy';
  }

  # bo creates the id, reset it
  map { delete $form->{$_} } qw(id subject message cc bcc printed emailed queued);
  $form->{ $form->{vc} } =~ s/--.*//g;
  $form->{type} = "invoice";

  # locale messages
  $locale = new Locale "$myconfig{countrycode}", "$script";

  require "bin/mozilla/$form->{script}";

  map { $form->{"select$_"} = "" } ($form->{vc}, currency);

  $currency = $form->{currency};
  &invoice_links;

  $form->{currency}     = $currency;
  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{invdate}, $buysell);
  $form->{exchangerate} = $form->{forex} || '';

  $form->{creditremaining} -= ($form->{oldinvtotal} - $form->{ordtotal});

  &prepare_invoice;

  # format amounts
  for $i (1 .. $form->{rowcount}) {
    $form->{"discount_$i"} =
      $form->format_amount(\%myconfig, $form->{"discount_$i"});

    ($dec) = ($form->{"sellprice_$i"} =~ /\.(\d+)/);
    $dec           = length $dec;
    $decimalplaces = ($dec > 2) ? $dec : 2;

    # copy delivery date from reqdate for order -> invoice conversion
    $form->{"deliverydate_$i"} = $form->{"reqdate_$i"}
      unless $form->{"deliverydate_$i"};

    $form->{"sellprice_$i"} =
      $form->format_amount(\%myconfig, $form->{"sellprice_$i"},
                           $decimalplaces);

    (my $dec_qty) = ($form->{"qty_$i"} =~ /\.(\d+)/);
    $dec_qty = length $dec_qty;
    $form->{"qty_$i"} =
      $form->format_amount(\%myconfig, $form->{"qty_$i"}, $dec_qty);

    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g }
      qw(partnumber description unit);

  }

  &display_form;

  $lxdebug->leave_sub();
}

sub backorder_exchangerate {
  $lxdebug->enter_sub();

  check_oe_access();

  my ($orddate, $buysell) = @_;

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
|;

  # delete action variable
  map { delete $form->{$_} } qw(action header exchangerate);

  foreach $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  $form->{title} = $locale->text('Add Exchangerate');

  print qq|

<input type=hidden name=exchangeratedate value=$orddate>
<input type=hidden name=buysell value=$buysell>

<table width=100%>
  <tr><th class=listtop>$form->{title}</th></tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
        <tr>
	  <th align=right>| . $locale->text('Currency') . qq|</th>
	  <td>$form->{currency}</td>
	</tr>
	<tr>
	  <th align=right>| . $locale->text('Date') . qq|</th>
	  <td>$orddate</td>
	</tr>
        <tr>
	  <th align=right>| . $locale->text('Exchangerate') . qq|</th>
	  <td><input name=exchangerate size=11></td>
        </tr>
      </table>
    </td>
  </tr>
</table>

<hr size=3 noshade>

<br>
<input type=hidden name=nextsub value=save_exchangerate>

<input name=action class=submit type=submit value="|
    . $locale->text('Continue') . qq|">

</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub save_exchangerate {
  $lxdebug->enter_sub();

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'));
  $form->{exchangerate} =
    $form->parse_amount(\%myconfig, $form->{exchangerate});
  $form->save_exchangerate(\%myconfig, $form->{currency},
                           $form->{exchangeratedate},
                           $form->{exchangerate}, $form->{buysell});

  &invoice;

  $lxdebug->leave_sub();
}

sub create_backorder {
  $lxdebug->enter_sub();

  $form->{shipped} = 1;

  # figure out if we need to create a backorder
  # items aren't saved if qty != 0

  for $i (1 .. $form->{rowcount}) {
    $totalqty  += $qty  = $form->{"qty_$i"};
    $totalship += $ship = $form->{"ship_$i"};

    $form->{"qty_$i"} = $qty - $ship;
  }

  if ($totalship == 0) {
    map { $form->{"ship_$_"} = $form->{"qty_$_"} } (1 .. $form->{rowcount});
    $form->{ordtotal} = 0;
    $form->{shipped}  = 0;
    return;
  }

  if ($totalqty == $totalship) {
    map { $form->{"qty_$_"} = $form->{"ship_$_"} } (1 .. $form->{rowcount});
    $form->{ordtotal} = 0;
    return;
  }

  @flds = (
    qw(partnumber description qty ship unit sellprice discount id inventory_accno bin income_accno expense_accno listprice assembly taxaccounts partsgroup)
  );

  for $i (1 .. $form->{rowcount}) {
    map {
      $form->{"${_}_$i"} =
        $form->format_amount(\%myconfig, $form->{"${_}_$i"})
    } qw(sellprice discount);
  }

  relink_accounts();

  OE->save(\%myconfig, \%$form);

  # rebuild rows for invoice
  @a     = ();
  $count = 0;

  for $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->{"ship_$i"};

    if ($form->{"qty_$i"}) {
      push @a, {};
      $j = $#a;
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }

  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});
  $form->{rowcount} = $count;

  $lxdebug->leave_sub();
}

sub save_as_new {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{saveasnew} = 1;
  $form->{closed}    = 0;
  map { delete $form->{$_} } qw(printed emailed queued);

  # Let Lx-Office assign a new order number if the user hasn't changed the
  # previous one. If it has been changed manually then use it as-is.
  my $idx = $form->{type} =~ /_quotation$/ ? "quonumber" : "ordnumber";
  $form->{$idx} =~ s/^\s*//g;
  $form->{$idx} =~ s/\s*$//g;
  if ($form->{saved_xyznumber} &&
      ($form->{saved_xyznumber} eq $form->{$idx})) {
    delete($form->{$idx});
  }

  &save;

  $lxdebug->leave_sub();
}

sub check_for_direct_delivery_yes {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{direct_delivery_checked} = 1;
  delete @{$form}{grep /^shipto/, keys %{ $form }};
  map { s/^CFDD_//; $form->{$_} = $form->{"CFDD_${_}"} } grep /^CFDD_/, keys %{ $form };
  $form->{shipto} = 1;
  purchase_order();
  $lxdebug->leave_sub();
}

sub check_for_direct_delivery_no {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{direct_delivery_checked} = 1;
  delete @{$form}{grep /^shipto/, keys %{ $form }};
  purchase_order();

  $lxdebug->leave_sub();
}

sub check_for_direct_delivery {
  $lxdebug->enter_sub();

  check_oe_access();

  if ($form->{direct_delivery_checked}
      || (!$form->{shiptoname} && !$form->{shiptostreet} && !$form->{shipto_id})) {
    $lxdebug->leave_sub();
    return;
  }

  if ($form->{shipto_id}) {
    Common->get_shipto_by_id(\%myconfig, $form, $form->{shipto_id}, "CFDD_");

  } else {
    map { $form->{"CFDD_${_}"} = $form->{$_ } } grep /^shipto/, keys %{ $form };
  }

  delete $form->{action};
  $form->{VARIABLES} = [ map { { "key" => $_, "value" => $form->{$_} } } grep { ($_ ne 'login') && ($_ ne 'password') && (ref $_ eq "") } keys %{ $form } ];

  $form->header();
  print $form->parse_html_template("oe/check_for_direct_delivery");

  $lxdebug->leave_sub();

  exit 0;
}

sub purchase_order {
  $lxdebug->enter_sub();

  check_oe_access();
  $auth->assert('purchase_order_edit');

  if ($form->{type} eq 'sales_order') {
    check_for_direct_delivery();
  }

  if ($form->{type} =~ /^sales_/) {
    delete($form->{ordnumber});
  }

  $form->{cp_id} *= 1;

  $form->{title} = $locale->text('Add Purchase Order');
  $form->{vc}    = "vendor";
  $form->{type}  = "purchase_order";

  &poso;

  $lxdebug->leave_sub();
}

sub sales_order {
  $lxdebug->enter_sub();

  check_oe_access();
  $auth->assert('sales_order_edit');

  if ($form->{type} eq "purchase_order") {
    delete($form->{ordnumber});
  }

  $form->{cp_id} *= 1;

  $form->{title}  = $locale->text('Add Sales Order');
  $form->{vc}     = "customer";
  $form->{type}   = "sales_order";

  &poso;

  $lxdebug->leave_sub();
}

sub poso {
  $lxdebug->enter_sub();

  check_oe_access();
  $auth->assert('purchase_order_edit | sales_order_edit');

  $form->{transdate} = $form->current_date(\%myconfig);
  delete $form->{duedate};

  $form->{convert_from_oe_ids} = $form->{id};
  $form->{closed}              = 0;

  $form->{old_employee_id}     = $form->{employee_id};
  $form->{old_salesman_id}     = $form->{salesman_id};

  # reset
  map { delete $form->{$_} } qw(id subject message cc bcc printed emailed queued customer vendor creditlimit creditremaining discount tradediscount oldinvtotal delivered
                                ordnumber);

  for $i (1 .. $form->{rowcount}) {
    map { $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"}) if ($form->{"${_}_${i}"}) } qw(ship qty sellprice listprice basefactor);
  }

  my %saved_vars = map { $_ => $form->{$_} } grep { $form->{$_} } qw(currency);

  &order_links;

  map { $form->{$_} = $saved_vars{$_} } keys %saved_vars;

  &prepare_order;

  # format amounts
  for $i (1 .. $form->{rowcount} - 1) {
    map { $form->{"${_}_$i"} =~ s/\"/&quot;/g } qw(partnumber description unit);
  }

  &update;

  $lxdebug->leave_sub();
}

sub delivery_order {
  $lxdebug->enter_sub();

  if ($form->{type} =~ /^sales/) {
    $auth->assert('sales_delivery_order_edit');

    $form->{vc}    = 'customer';
    $form->{type}  = 'sales_delivery_order';

  } else {
    $auth->assert('purchase_delivery_order_edit');

    $form->{vc}    = 'vendor';
    $form->{type}  = 'purchase_delivery_order';
  }

  require "bin/mozilla/do.pl";

  $form->{cp_id}               *= 1;
  $form->{convert_from_oe_ids}  = $form->{id};
  $form->{transdate}            = $form->current_date(\%myconfig);
  delete $form->{duedate};

  $form->{old_employee_id}  = $form->{employee_id};
  $form->{old_salesman_id}  = $form->{salesman_id};

  # reset
  delete @{$form}{qw(id subject message cc bcc printed emailed queued creditlimit creditremaining discount tradediscount oldinvtotal closed delivered)};

  for $i (1 .. $form->{rowcount}) {
    map { $form->{"${_}_${i}"} = $form->parse_amount(\%myconfig, $form->{"${_}_${i}"}) if ($form->{"${_}_${i}"}) } qw(ship qty sellprice listprice basefactor);
  }

  my %old_values = map { $_ => $form->{$_} } qw(customer_id oldcustomer customer vendor_id oldvendor vendor);

  order_links();

  prepare_order();

  map { $form->{$_} = $old_values{$_} if ($old_values{$_}) } keys %old_values;

  update();

  $lxdebug->leave_sub();
}

sub e_mail {
  $lxdebug->enter_sub();

  check_oe_access();

  $form->{print_and_save} = 1;

  $print_post = 1;

  my $saved_form = save_form();

  save();

  restore_form($saved_form, 0, qw(id ordnumber quonumber));

  edit_e_mail();

  $lxdebug->leave_sub();
}

sub yes {
  call_sub($form->{yes_nextsub});
}

sub no {
  call_sub($form->{no_nextsub});
}

######################################################################################################
# IO ENTKOPPLUNG
# ###############################################################################################
sub display_form {
  $lxdebug->enter_sub();

  check_oe_access();

  retrieve_partunits() if ($form->{type} =~ /_delivery_order$/);

  $form->{"taxaccounts"} =~ s/\s*$//;
  $form->{"taxaccounts"} =~ s/^\s*//;
  foreach my $accno (split(/\s*/, $form->{"taxaccounts"})) {
    map({ delete($form->{"${accno}_${_}"}); } qw(rate description taxnumber));
  }
  $form->{"taxaccounts"} = "";

  for my $i (1 .. $form->{"rowcount"}) {
    IC->retrieve_accounts(\%myconfig, $form, $form->{"id_$i"}, $i, 1) if $form->{"id_$i"};
  }

  $form->{rowcount}++;
  $form->{"project_id_$form->{rowcount}"} = $form->{globalproject_id};

  $form->language_payment(\%myconfig);

  Common::webdav_folder($form) if ($webdav);

  &form_header;

  # create rows
  display_row($form->{rowcount}) if $form->{rowcount};

  &form_footer;

  $lxdebug->leave_sub();
}

sub report_for_todo_list {
  $lxdebug->enter_sub();

  my $quotations = OE->transactions_for_todo_list();
  my $content;

  if (@{ $quotations }) {
    my $edit_url = build_std_url('script=oe.pl', 'action=edit');

    $content     = $form->parse_html_template('oe/report_for_todo_list', { 'QUOTATIONS' => $quotations,
                                                                           'edit_url'   => $edit_url });
  }

  $lxdebug->leave_sub();

  return $content;
}

