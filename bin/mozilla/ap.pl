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
# Accounts Payables
#
#======================================================================

use POSIX qw(strftime);
use List::Util qw(sum);

use SL::AP;
use SL::FU;
use SL::IR;
use SL::IS;
use SL::PE;
use SL::ReportGenerator;
use SL::DB::Default;

require "bin/mozilla/arap.pl";
require "bin/mozilla/common.pl";
require "bin/mozilla/drafts.pl";
require "bin/mozilla/reportgenerator.pl";

use strict;

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

sub add {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger');

  return $main::lxdebug->leave_sub() if (load_draft_maybe());

  $form->{title} = "Add";

  $form->{callback} = "ap.pl?action=add&DONT_LOAD_DRAFT=1" unless $form->{callback};

  AP->get_transdate(\%myconfig, $form);
  $form->{initial_transdate} = $form->{transdate};
  create_links(dont_save => 1);
  $form->{transdate} = $form->{initial_transdate};
  &display_form;

  $main::lxdebug->leave_sub();
}

sub edit {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('general_ledger');

  $form->{title} = "Edit";

  create_links();
  &display_form;

  $main::lxdebug->leave_sub();
}

sub display_form {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('general_ledger');

  &form_header;
  &form_footer;

  $main::lxdebug->leave_sub();
}

sub create_links {
  $main::lxdebug->enter_sub();

  my %params   = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger');

  $form->create_links("AP", \%myconfig, "vendor");
  my %saved;
  if (!$params{dont_save}) {
    %saved = map { ($_ => $form->{$_}) } qw(direct_debit taxincluded);
    $saved{duedate} = $form->{duedate} if $form->{duedate};
  }

  IR->get_vendor(\%myconfig, \%$form);

  $form->{$_}        = $saved{$_} for keys %saved;
  $form->{oldvendor} = "$form->{vendor}--$form->{vendor_id}";
  $form->{rowcount}  = 1;

  # build the popup menus
  $form->{taxincluded} = ($form->{id}) ? $form->{taxincluded} : "checked";

  # currencies
  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  map { my $quoted = H($_); $form->{selectcurrency} .= "<option value=\"${quoted}\">${quoted}\n" } $form->get_all_currencies(\%myconfig);

  # vendors
  if (@{ $form->{all_vendor} || [] }) {
    $form->{vendor} = qq|$form->{vendor}--$form->{vendor_id}|;
    map { my $quoted = H($_->{name} . "--" . $_->{id}); $form->{selectvendor} .= "<option value=\"${quoted}\">${quoted}\n" }
      (@{ $form->{all_vendor} });
  }

  # departments
  if (@{ $form->{all_departments} || [] }) {
    $form->{department}       = "$form->{department}--$form->{department_id}";
    $form->{selectdepartment} = "<option>\n" . join('', map { my $quoted = H("$_->{description}--$_->{id}"); "<option value=\"${quoted}\">${quoted}\n"} @{ $form->{all_departments} || [] });
  }

  $form->{employee} = "$form->{employee}--$form->{employee_id}";

  AP->setup_form($form);

  $form->{locked} =
    ($form->datetonum($form->{transdate}, \%myconfig) <=
     $form->datetonum($form->{closedto}, \%myconfig));

  $main::lxdebug->leave_sub();
}

sub form_header {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;
  my $cgi      = $::request->{cgi};

  $main::auth->assert('general_ledger');

  $form->{title_} = $form->{title};
  $form->{title} = $form->{title} eq 'Add' ? $locale->text('Add Accounts Payables Transaction') : $locale->text('Edit Accounts Payables Transaction');

  # type=submit $locale->text('Add Accounts Payables Transaction')
  # type=submit $locale->text('Edit Accounts Payables Transaction')

  # set option selected
  foreach my $item (qw(vendor currency department)) {
    my $to_replace         =  H($form->{$item});
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/>\Q${to_replace}\E/ selected>${to_replace}/;
  }
  my $readonly = $form->{id} ? "readonly" : "";

  $form->{radier} = ($::instance_conf->get_ap_changeable == 2)
                      ? ($form->current_date(\%myconfig) eq $form->{gldate})
                      : ($::instance_conf->get_ap_changeable == 1);
  $readonly       = $form->{radier} ? "" : $readonly;

  $form->{readonly} = $readonly;

  $form->{forex} = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate}, 'sell');
  if ( $form->{forex} ) {
    $form->{exchangerate} = $form->{forex};
  }

  # format amounts
  $form->{exchangerate}    = $form->{exchangerate} ? $form->format_amount(\%myconfig, $form->{exchangerate}) : '';
  $form->{creditlimit}     = $form->format_amount(\%myconfig, $form->{creditlimit}, 0, "0");
  $form->{creditremaining} = $form->format_amount(\%myconfig, $form->{creditremaining}, 0, "0");

  my $rows;
  if (($rows = $form->numtextrows($form->{notes}, 50)) < 2) {
    $rows = 2;
  }
  $form->{textarea_rows} = $rows;

  $form->{creditremaining_plus} = ($form->{creditremaining} =~ /-/) ? "0" : "1";

  my @old_project_ids = ();
  map(
    {
      if ($form->{"project_id_$_"}) {
        push(@old_project_ids, $form->{"project_id_$_"});
      }
    }
    (1..$form->{"rowcount"})
  );

  $form->get_lists("projects"  => { "key"       => "ALL_PROJECTS",
                                    "all"       => 0,
                                    "old_id"    => \@old_project_ids },
                   "charts"    => { "key"       => "ALL_CHARTS",
                                    "transdate" => $form->{transdate} },
                   "taxcharts" => { "key"       => "ALL_TAXCHARTS",
                                    "module"    => "AP" },);

  map(
    { $_->{link_split} = [ split(/:/, $_->{link}) ]; }
    @{ $form->{ALL_CHARTS} }
  );

  my %project_labels = ();
  foreach my $item (@{ $form->{"ALL_PROJECTS"} }) {
    $project_labels{$item->{id}} = $item->{projectnumber};
  }

  my %charts;
  my $taxchart_init;

  foreach my $item (@{ $form->{ALL_CHARTS} }) {
    if ( grep({ $_ eq 'AP_amount' } @{ $item->{link_split} }) ) {
      if ( $taxchart_init eq '' ) {
        $taxchart_init = $item->{tax_id};
      }

      push(@{ $form->{ALL_CHARTS_AP_amount} }, $item);
    }
    elsif ( grep({ $_ eq 'AP' } @{ $item->{link_split} }) ) {
      push(@{ $form->{ALL_CHARTS_AP} }, $item);
    }
    elsif ( grep({ $_ eq 'AP_paid' } @{ $item->{link_split} }) ) {
      push(@{ $form->{ALL_CHARTS_AP_paid} }, $item);
    }

    $charts{$item->{accno}} = $item;
  }

  my %taxcharts = ();
  foreach my $item (@{ $form->{ALL_TAXCHARTS} }) {
    my $key = $item->{id} .'--'. $item->{rate};

    if ( $taxchart_init eq $item->{id} ) {
      $taxchart_init = $key;
    }

    $taxcharts{$item->{id}} = $item;
  }

  my $follow_up_vc         =  $form->{vendor};
  $follow_up_vc            =~ s/--.*?//;
  my $follow_up_trans_info =  "$form->{invnumber} ($follow_up_vc)";

  $form->{javascript} .= qq|<script type="text/javascript" src="js/common.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/show_vc_details.js"></script>|;
  $form->{javascript} .= qq|<script type="text/javascript" src="js/follow_up.js"></script>|;

  $form->header();

  for my $i (1 .. $form->{rowcount}) {

    # format amounts
    $form->{"amount_$i"} = $form->format_amount(\%myconfig, $form->{"amount_$i"}, 2);
    $form->{"tax_$i"} = $form->format_amount(\%myconfig, $form->{"tax_$i"}, 2);

    my $selected_accno_full;
    my ($accno_row) = split(/--/, $form->{"AP_amount_$i"});
    my $item = $charts{$accno_row};
    $selected_accno_full = "$item->{accno}--$item->{tax_id}";

    my $selected_taxchart = $form->{"taxchart_$i"};
    my ($selected_accno, $selected_tax_id) = split(/--/, $selected_accno_full);
    my ($previous_accno, $previous_tax_id) = split(/--/, $form->{"previous_AP_amount_$i"});

    if ($previous_accno &&
        ($previous_accno eq $selected_accno) &&
        ($previous_tax_id ne $selected_tax_id)) {
      my $item = $taxcharts{$selected_tax_id};
      $selected_taxchart = "$item->{id}--$item->{rate}";
    }

    $selected_taxchart = $taxchart_init unless ($form->{"taxchart_$i"});

    $form->{'selected_accno_full_'. $i} = $selected_accno_full;

    $form->{'selected_taxchart_'. $i} = $selected_taxchart;
  }

  $form->{AP_amount_value_title_sub} = sub {
    my $item = shift;
    return [
      $item->{accno} .'--'. $item->{tax_id},
      $item->{accno} .'--'. $item->{description},
    ];
  };

  $form->{taxchart_value_title_sub} = sub {
    my $item = shift;
    return [
      $item->{id} .'--'. $item->{rate},
      $item->{taxdescription} .' '. ($item->{rate} * 100) .' %',
    ];
  };

  $form->{AP_paid_value_title_sub} = sub {
    my $item = shift;
    return [
      $item->{accno},
      $item->{accno} .'--'. $item->{description}
    ];
  };

  $form->{APselected_value_title_sub} = sub {
    my $item = shift;
    return [
      $item->{accno},
      $item->{accno} .'--'. $item->{description}
    ];
  };

  $form->{invtotal_unformatted} = $form->{invtotal};
  $form->{invtotal} = $form->format_amount(\%myconfig, $form->{invtotal}, 2);

  $form->{totalpaid} = 0;

  if ( $form->{'paid_'. $form->{paidaccounts}} ) {
    $form->{paidaccounts}++;
  }
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{totalpaid} += $form->{"paid_$i"};

    # format amounts
    if ($form->{"paid_$i"}) {
      $form->{"paid_$i"} = $form->format_amount(\%myconfig, $form->{"paid_$i"}, 2);
    }
    if ($form->{"exchangerate_$i"} == 0) {
      $form->{"exchangerate_$i"} = "";
    } else {
      $form->{"exchangerate_$i"} =
        $form->format_amount(\%myconfig, $form->{"exchangerate_$i"});
    }

    my $changeable = 1;
    if (SL::DB::Default->get->payments_changeable == 0) {
      # never
      $changeable = ($form->{"acc_trans_id_$i"})? 0 : 1;
    }
    if (SL::DB::Default->get->payments_changeable == 2) {
      # on the same day
      $changeable = (($form->{"gldate_$i"} eq '') || $form->current_date(\%myconfig) eq $form->{"gldate_$i"});
    }

    $form->{'paidaccount_changeable_'. $i} = $changeable;

    $form->{'labelpaid_project_id_'. $i} = $project_labels{$form->{'paid_project_id_'. $i}};
  }

  $form->{paid_missing} = $form->{invtotal_unformatted} - $form->{totalpaid};

  print $form->parse_html_template('ap/form_header');

  $main::lxdebug->leave_sub();
}

sub form_footer {
  $::lxdebug->enter_sub;
  $::auth->assert('general_ledger');

  my $num_due;
  my $num_follow_ups;
  if ($::form->{id}) {
    my $follow_ups = FU->follow_ups('trans_id' => $::form->{id});

    if (@{ $follow_ups }) {
      $num_due        = sum map { $_->{due} * 1 } @{ $follow_ups };
      $num_follow_ups = scalar @{ $follow_ups }
    }
  }

  my $transdate = $::form->datetonum($::form->{transdate}, \%::myconfig);
  my $closedto  = $::form->datetonum($::form->{closedto},  \%::myconfig);

  my $storno = $::form->{id}
            && !IS->has_storno(\%::myconfig, $::form, 'ap')
            && !IS->is_storno( \%::myconfig, $::form, 'ap', $::form->{id})
            && ($::form->{totalpaid} == 0 || $::form->{totalpaid} eq '');

  $::form->header;
  print $::form->parse_html_template('ap/form_footer', {
    num_due           => $num_due,
    num_follow_ups    => $num_follow_ups,
    show_post_draft   => ($transdate > $closedto) && !$::form->{id},
    show_storno       => $storno,
  });

  $::lxdebug->leave_sub;
}

sub mark_as_paid {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger');

  &mark_as_paid_common(\%myconfig,"ap");

  $main::lxdebug->leave_sub();
}

sub update {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger');

  my $display = shift;

  $form->{invtotal} = 0;

  delete @{ $form }{ grep { m/^tax_\d+$/ } keys %{ $form } };

  map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) }
    qw(exchangerate creditlimit creditremaining);

  my @flds  = qw(amount AP_amount projectnumber oldprojectnumber project_id taxchart);
  my $count = 0;
  my (@a, $j, $totaltax);
  for my $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} =
      $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    $form->{"tax_$i"} = $form->parse_amount(\%myconfig, $form->{"tax_$i"});
    if ($form->{"amount_$i"}) {
      push @a, {};
      $j = $#a;
      my ($taxkey, $rate) = split(/--/, $form->{"taxchart_$i"});
      if ($taxkey > 1) {
        if ($form->{taxincluded}) {
          $form->{"tax_$i"} = $form->{"amount_$i"} / ($rate + 1) * $rate;
        } else {
          $form->{"tax_$i"} = $form->{"amount_$i"} * $rate;
        }
      } else {
        $form->{"tax_$i"} = 0;
      }
      $form->{"tax_$i"} = $form->round_amount($form->{"tax_$i"}, 2);

      $totaltax += $form->{"tax_$i"};
      map { $a[$j]->{$_} = $form->{"${_}_$i"} } @flds;
      $count++;
    }
  }
  $form->redo_rows(\@flds, \@a, $count, $form->{rowcount});

  map { $form->{invtotal} += $form->{"amount_$_"} } (1 .. $form->{rowcount});

  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{transdate}, 'sell');
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  $form->{invdate} = $form->{transdate};
  my %saved_variables = map +( $_ => $form->{$_} ), qw(AP AP_amount_1 taxchart_1 notes);

  my $vendor_changed = &check_name("vendor");

  $form->{AP} = $saved_variables{AP};
  if ($saved_variables{AP_amount_1} =~ m/.--./) {
    map { $form->{$_} = $saved_variables{$_} } qw(AP_amount_1 taxchart_1);
  } else {
    delete $form->{taxchart_1};
  }

  $form->{rowcount} = $count + 1;

  $form->{invtotal} =
    ($form->{taxincluded}) ? $form->{invtotal} : $form->{invtotal} + $totaltax;

  my $totalpaid;
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      map {
        $form->{"${_}_$i"} =
          $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
      } qw(paid exchangerate);

      $totalpaid += $form->{"paid_$i"};

      $form->{"forex_$i"}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');
      $form->{"exchangerate_$i"} = $form->{"forex_$i"} if $form->{"forex_$i"};
    }
  }

  $form->{creditremaining} -=
    ($form->{invtotal} - $totalpaid + $form->{oldtotalpaid} -
     $form->{oldinvtotal});
  $form->{oldinvtotal}  = $form->{invtotal};
  $form->{oldtotalpaid} = $totalpaid;

  &display_form;

  $main::lxdebug->leave_sub();
}


sub post_payment {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger');

  $form->{defaultcurrency} = $form->get_default_currency(\%myconfig);

  my $invdate = $form->datetonum($form->{transdate}, \%myconfig);

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"}, \%myconfig));

      if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency})) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($invdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }
    }
  }

  ($form->{AP})      = split /--/, $form->{AP};
  ($form->{AP_paid}) = split /--/, $form->{AP_paid};
  $form->redirect($locale->text('Payment posted!'))
      if (AP->post_payment(\%myconfig, \%$form));
    $form->error($locale->text('Cannot post payment!'));


  $main::lxdebug->leave_sub();
}


sub post {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger');

  my ($inline) = @_;

  # check if there is a vendor, invoice and due date
  $form->isblank("transdate", $locale->text("Invoice Date missing!"));
  $form->isblank("duedate",   $locale->text("Due Date missing!"));
  $form->isblank("vendor",    $locale->text('Vendor missing!'));

  if ($myconfig{mandatory_departments} && !$form->{department}) {
    $form->{saved_message} = $::locale->text('You have to specify a department.');
    update();
    exit;
  }

  my $closedto  = $form->datetonum($form->{closedto},  \%myconfig);
  my $transdate = $form->datetonum($form->{transdate}, \%myconfig);

  $form->error($locale->text('Cannot post transaction above the maximum future booking date!'))
    if ($form->date_max_future($form->{"transdate"}, \%myconfig));
  $form->error($locale->text('Cannot post transaction for a closed period!')) if ($form->date_closed($form->{"transdate"}, \%myconfig));

  my $zero_amount_posting = 1;
  for my $i (1 .. $form->{rowcount}) {
    if ($form->parse_amount(\%myconfig, $form->{"amount_$i"})) {
      $zero_amount_posting = 0;
      last;
    }
  }

  $form->error($locale->text('Zero amount posting!')) if $zero_amount_posting;

  $form->isblank("exchangerate", $locale->text('Exchangerate missing!'))
    if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency}));
  delete($form->{AP});

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      my $datepaid = $form->datetonum($form->{"datepaid_$i"}, \%myconfig);

      $form->isblank("datepaid_$i", $locale->text('Payment date missing!'));

      $form->error($locale->text('Cannot post payment for a closed period!'))
        if ($form->date_closed($form->{"datepaid_$i"}, \%myconfig));

      if ($form->{defaultcurrency} && ($form->{currency} ne $form->{defaultcurrency})) {
        $form->{"exchangerate_$i"} = $form->{exchangerate}
          if ($transdate == $datepaid);
        $form->isblank("exchangerate_$i",
                       $locale->text('Exchangerate for payment missing!'));
      }

    }
  }

  # if old vendor ne vendor redo form
  my ($vendor) = split /--/, $form->{vendor};
  if ($form->{oldvendor} ne "$vendor--$form->{vendor_id}") {
    &update;
    ::end_of_request();
  }
  my ($debitaccno,    $debittaxkey)    = split /--/, $form->{AP_amountselected};
  my ($taxkey,        $NULL)           = split /--/, $form->{taxchartselected};
  my ($payablesaccno, $payablestaxkey) = split /--/, $form->{APselected};
#  $form->{AP_amount_1}  = $debitaccno;
  $form->{AP_payables}  = $payablesaccno;
  $form->{taxkey}       = $taxkey;
  $form->{storno}       = 0;

  $form->{id} = 0 if $form->{postasnew};

  if (AP->post_transaction(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition} && $form->{id} ne "") {
      $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
      $form->{addition} = "POSTED";
      $form->save_history;
    }
    # /saving the history
    remove_draft() if $form->{remove_draft};
    # Dieser Text wird niemals ausgegeben: Probleme beim redirect?
    $form->redirect($locale->text('Transaction posted!')) unless $inline;
  } else {
    $form->error($locale->text('Cannot post transaction!'));
  }

  $main::lxdebug->leave_sub();
}

sub post_as_new {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger');

  $form->{postasnew} = 1;
  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
    $form->{addition} = "POSTED AS NEW";
    $form->save_history;
  }
  # /saving the history
  &post;

  $main::lxdebug->leave_sub();
}

sub use_as_new {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  $main::auth->assert('general_ledger');

  map { delete $form->{$_} } qw(printed emailed queued invnumber invdate deliverydate id datepaid_1 gldate_1 acc_trans_id_1 source_1 memo_1 paid_1 exchangerate_1 AP_paid_1 storno);
  $form->{paidaccounts} = 1;
  $form->{rowcount}--;
  $form->{invdate} = $form->current_date(\%myconfig);
  &update;

  $main::lxdebug->leave_sub();
}

sub delete {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger');

  $form->{title} = $locale->text('Confirm!');

  $form->header;

  delete $form->{header};

  print qq|
<form method=post action=$form->{script}>
|;

  foreach my $key (keys %$form) {
    next if (($key eq 'login') || ($key eq 'password') || ('' ne ref $form->{$key}));
    $form->{$key} =~ s/\"/&quot;/g;
    print qq|<input type=hidden name=$key value="$form->{$key}">\n|;
  }

  print qq|
<h2 class=confirm>$form->{title}</h2>

<h4>|
    . $locale->text('Are you sure you want to delete Transaction')
    . qq| $form->{invnumber}</h4>

<input name=action class=submit type=submit value="|
    . $locale->text('Yes') . qq|">
</form>
|;

  $main::lxdebug->leave_sub();
}

sub yes {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger');

  if (AP->delete_transaction(\%myconfig, \%$form)) {
    # saving the history
    if(!exists $form->{addition}) {
      $form->{snumbers} = qq|invnumber_| . $form->{invnumber};
      $form->{addition} = "DELETED";
      $form->save_history;
    }
    # /saving the history
    $form->redirect($locale->text('Transaction deleted!'));
  }
  $form->error($locale->text('Cannot delete transaction!'));

  $main::lxdebug->leave_sub();
}

sub search {
  $main::lxdebug->enter_sub();

  $main::auth->assert('vendor_invoice_edit');

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  # setup customer selection
  $form->all_vc(\%myconfig, "vendor", "AP");

  $form->{title}    = $locale->text('AP Transactions');

  $form->get_lists("projects"     => { "key" => "ALL_PROJECTS", "all" => 1 },
                   "departments"  => "ALL_DEPARTMENTS",
                   "vendors"      => "ALL_VC");

  # constants and subs for template
  $form->{vc_keys}   = sub { "$_[0]->{name}--$_[0]->{id}" };

  $form->header;
  print $form->parse_html_template('ap/search', { %myconfig });

  $main::lxdebug->leave_sub();
}

sub create_subtotal_row {
  $main::lxdebug->enter_sub();

  my ($totals, $columns, $column_alignment, $subtotal_columns, $class) = @_;

  my $form     = $main::form;
  my %myconfig = %main::myconfig;

  my $row = { map { $_ => { 'data' => '', 'class' => $class, 'align' => $column_alignment->{$_}, } } @{ $columns } };

  map { $row->{$_}->{data} = $form->format_amount(\%myconfig, $totals->{$_}, 2) } @{ $subtotal_columns };

  $row->{tax}->{data} = $form->format_amount(\%myconfig, $totals->{amount} - $totals->{netamount}, 2);

  map { $totals->{$_} = 0 } @{ $subtotal_columns };

  $main::lxdebug->leave_sub();

  return $row;
}

sub ap_transactions {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('vendor_invoice_edit');

  ($form->{vendor}, $form->{vendor_id}) = split(/--/, $form->{vendor});

  report_generator_set_default_sort('transdate', 1);

  AP->ap_transactions(\%myconfig, \%$form);

  $form->{title} = $locale->text('AP Transactions');

  my $report = SL::ReportGenerator->new(\%myconfig, $form);

  my @columns =
    qw(transdate id type invnumber ordnumber name netamount tax amount paid datepaid
       due duedate transaction_description notes employee globalprojectnumber
       vendornumber country ustid taxzone payment_terms charts);

  my @hidden_variables = map { "l_${_}" } @columns;
  push @hidden_variables, "l_subtotal", qw(open closed vendor invnumber ordnumber transaction_description notes project_id transdatefrom transdateto department);

  my $href = build_std_url('action=ap_transactions', grep { $form->{$_} } @hidden_variables);

  my %column_defs = (
    'transdate'               => { 'text' => $locale->text('Date'), },
    'id'                      => { 'text' => $locale->text('ID'), },
    'type'                    => { 'text' => $locale->text('Type'), },
    'invnumber'               => { 'text' => $locale->text('Invoice'), },
    'ordnumber'               => { 'text' => $locale->text('Order'), },
    'name'                    => { 'text' => $locale->text('Vendor'), },
    'netamount'               => { 'text' => $locale->text('Amount'), },
    'tax'                     => { 'text' => $locale->text('Tax'), },
    'amount'                  => { 'text' => $locale->text('Total'), },
    'paid'                    => { 'text' => $locale->text('Paid'), },
    'datepaid'                => { 'text' => $locale->text('Date Paid'), },
    'due'                     => { 'text' => $locale->text('Amount Due'), },
    'duedate'                 => { 'text' => $locale->text('Due Date'), },
    'transaction_description' => { 'text' => $locale->text('Transaction description'), },
    'notes'                   => { 'text' => $locale->text('Notes'), },
    'employee'                => { 'text' => $locale->text('Employee'), },
    'globalprojectnumber'     => { 'text' => $locale->text('Document Project Number'), },
    'vendornumber'            => { 'text' => $locale->text('Vendor Number'), },
    'country'                 => { 'text' => $locale->text('Country'), },
    'ustid'                   => { 'text' => $locale->text('USt-IdNr.'), },
    'taxzone'                 => { 'text' => $locale->text('Steuersatz'), },
    'payment_terms'           => { 'text' => $locale->text('Payment Terms'), },
    'charts'                  => { 'text' => $locale->text('Buchungskonto'), },
  );

  foreach my $name (qw(id transdate duedate invnumber ordnumber name datepaid employee shippingpoint shipvia transaction_description)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  my %column_alignment = map { $_ => 'right' } qw(netamount tax amount paid due);

  $form->{"l_type"} = "Y";
  map { $column_defs{$_}->{visible} = $form->{"l_${_}"} ? 1 : 0 } @columns;

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  $report->set_export_options('ap_transactions', @hidden_variables, qw(sort sortdir));

  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my @options;
  push @options, $locale->text('Vendor')                  . " : $form->{vendor}"                         if ($form->{vendor});
  push @options, $locale->text('Department')              . " : " . (split /--/, $form->{department})[0] if ($form->{department});
  push @options, $locale->text('Invoice Number')          . " : $form->{invnumber}"                      if ($form->{invnumber});
  push @options, $locale->text('Order Number')            . " : $form->{ordnumber}"                      if ($form->{ordnumber});
  push @options, $locale->text('Notes')                   . " : $form->{notes}"                          if ($form->{notes});
  push @options, $locale->text('Transaction description') . " : $form->{transaction_description}"        if ($form->{transaction_description});
  push @options, $locale->text('From') . " " . $locale->date(\%myconfig, $form->{transdatefrom}, 1)      if ($form->{transdatefrom});
  push @options, $locale->text('Bis')  . " " . $locale->date(\%myconfig, $form->{transdateto},   1)      if ($form->{transdateto});
  push @options, $locale->text('Open')                                                                   if ($form->{open});
  push @options, $locale->text('Closed')                                                                 if ($form->{closed});

  $report->set_options('top_info_text'        => join("\n", @options),
                       'raw_bottom_info_text' => $form->parse_html_template('ap/ap_transactions_bottom'),
                       'output_format'        => 'HTML',
                       'title'                => $form->{title},
                       'attachment_basename'  => $locale->text('vendor_invoice_list') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  # add sort and escape callback, this one we use for the add sub
  $form->{callback} = $href .= "&sort=$form->{sort}";

  # escape callback for href
  my $callback = $form->escape($href);

  my @subtotal_columns = qw(netamount amount paid due);

  my %totals    = map { $_ => 0 } @subtotal_columns;
  my %subtotals = map { $_ => 0 } @subtotal_columns;

  my $idx = 0;

  foreach my $ap (@{ $form->{AP} }) {
    $ap->{tax} = $ap->{amount} - $ap->{netamount};
    $ap->{due} = $ap->{amount} - $ap->{paid};

    map { $subtotals{$_} += $ap->{$_};
          $totals{$_}    += $ap->{$_} } @subtotal_columns;

    map { $ap->{$_} = $form->format_amount(\%myconfig, $ap->{$_}, 2) } qw(netamount tax amount paid due);

    my $is_storno  = $ap->{storno} &&  $ap->{storno_id};
    my $has_storno = $ap->{storno} && !$ap->{storno_id};

    if ($ap->{invoice}) {
      $ap->{type} =
          $has_storno       ? $locale->text("Invoice with Storno (abbreviation)")
        : $is_storno        ? $locale->text("Storno (one letter abbreviation)")
        :                     $locale->text("Invoice (one letter abbreviation)");
    } else {
      $ap->{type} =
          $has_storno       ? $locale->text("AP Transaction with Storno (abbreviation)")
        : $is_storno        ? $locale->text("AP Transaction Storno (one letter abbreviation)")
        :                     $locale->text("AP Transaction (abbreviation)");
    }

    my $row = { };

    foreach my $column (@columns) {
      $row->{$column} = {
        'data'  => $ap->{$column},
        'align' => $column_alignment{$column},
      };
    }

    $row->{invnumber}->{link} = build_std_url("script=" . ($ap->{invoice} ? 'ir.pl' : 'ap.pl'), 'action=edit')
      . "&id=" . E($ap->{id}) . "&callback=${callback}";

    my $row_set = [ $row ];

    if (($form->{l_subtotal} eq 'Y')
        && (($idx == (scalar @{ $form->{AP} } - 1))
            || ($ap->{ $form->{sort} } ne $form->{AP}->[$idx + 1]->{ $form->{sort} }))) {
      push @{ $row_set }, create_subtotal_row(\%subtotals, \@columns, \%column_alignment, \@subtotal_columns, 'listsubtotal');
    }

    $report->add_data($row_set);

    $idx++;
  }

  $report->add_separator();
  $report->add_data(create_subtotal_row(\%totals, \@columns, \%column_alignment, \@subtotal_columns, 'listtotal'));

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub storno {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('general_ledger');

  if (IS->has_storno(\%myconfig, $form, 'ap')) {
    $form->{title} = $locale->text("Cancel Accounts Payables Transaction");
    $form->error($locale->text("Transaction has already been cancelled!"));
  }

  $form->error($locale->text('Cannot post storno for a closed period!'))
    if ( $form->date_closed($form->{transdate}, \%myconfig));

  AP->storno($form, \%myconfig, $form->{id});

  # saving the history
  if(!exists $form->{addition} && $form->{id} ne "") {
    $form->{snumbers} = "ordnumber_$form->{ordnumber}";
    $form->{addition} = "STORNO";
    $form->save_history;
  }
  # /saving the history

  $form->redirect(sprintf $locale->text("Transaction %d cancelled."), $form->{storno_id});

  $main::lxdebug->leave_sub();
}
