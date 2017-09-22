#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2002
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
# Payment module
#
#======================================================================

use SL::CP;
use SL::IS;
use SL::IR;
use SL::AR;
use SL::AP;
use Data::Dumper;
use SL::Locale::String qw(t8);
use strict;
#use warnings;

require "bin/mozilla/common.pl";

our ($form, %myconfig, $lxdebug, $locale, $auth);

1;

# end of main

sub payment {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my (@curr);

  $form->{ARAP} = ($form->{type} eq 'receipt') ? "AR" : "AP";
  $form->{arap} = lc $form->{ARAP};

  CP->paymentaccounts(\%myconfig, \%$form);

  # Standard Konto für Umlaufvermögen
  my $accno_arap = IS->get_standard_accno_current_assets(\%myconfig, \%$form);
  # Entsprechend präventiv die Auswahlliste für Kontonummer
  # auch mit value= zusammenbauen (s.a. oben bugfix 1771)
  # Wichtig: Auch das Template anpassen, damit hidden input korrekt die "
  # escaped.
  $form->{selectaccount} = "";
  $form->{"select$form->{ARAP}"} = "";

  map { $form->{selectaccount} .= "<option value=\"$_->{accno}--$_->{description}\">$_->{accno}--$_->{description}</option>\n";
        $form->{account}        = "$_->{accno}--$_->{description}" if ($_->{accno} eq $accno_arap) } @{ $form->{PR}{"$form->{ARAP}_paid"} };

  # currencies
  # oldcurrency ist zwar noch hier als fragment enthalten, wird aber bei
  # der aktualisierung der form auch nicht mitübernommen. das konzept
  # old_$FOO habe ich auch noch nicht verstanden ...
  # Ok. Wenn currency übernommen werden, dann in callback-string über-
  # geben und hier reinparsen, oder besser multibox oder html auslagern?
  # Antwort: form->currency wird mit oldcurrency oder curr[0] überschrieben
  # Wofür macht das Sinn?
  @curr = $form->get_all_currencies();
  $form->{defaultcurrency} = $form->{currency} = $form->{oldcurrency} =
    $form->get_default_currency(\%myconfig);

  # Entsprechend präventiv die Auswahlliste für Währungen
  # auch mit value= zusammenbauen (s.a. oben bugfix 1771)
  $form->{selectcurrency} = "";
  map { $form->{selectcurrency} .= "<option value=\"$_\">$_</option>\n" } @curr;


  &form_header;
  &form_footer;

  $lxdebug->leave_sub();
}

sub form_header {
  $lxdebug->enter_sub;

  $auth->assert('cash');

  $::request->layout->add_javascripts("kivi.CustomerVendor.js");

  my ($arap, $exchangerate);

  if (!$form->{ $form->{vc} . '_id' }) {
    map { $form->{"addr$_"} = "" } (1 .. 4);
  }

  # bugfix 1771
  # geändert von <option>asdf--2929
  # nach:
  #              <option value="asdf--2929">asdf--2929</option>
  # offen: $form->{ARAP} kann raus?
  for my $item ("account", "currency", $form->{ARAP}) {
    $form->{$item} = H($form->{$item});
    $form->{"select$item"} =~ s/ selected//;
    $form->{"select$item"} =~ s/option value="\Q$form->{$item}\E">\Q$form->{$item}\E/option selected value="$form->{$item}">$form->{$item}/;
  }

  $form->{openinvoices} = 1;

  # $locale->text('AR')
  # $locale->text('AP')

  setup_cp_form_action_bar(can_post => !!$form->{rowcount});

  $form->header;

  $arap = lc $form->{ARAP};

  print $::form->parse_html_template('cp/form_header', {
    is_customer => $form->{vc}   eq 'customer',
    is_receipt  => $form->{type} eq 'receipt',
    arap        => $arap,
  });

  $lxdebug->leave_sub;
}

sub list_invoices {
  $::lxdebug->enter_sub;
  $::auth->assert('cash');

  my @columns = qw(amount due paid invnumber id transdate checked);
  my (@invoices, %total);
  for my $i (1 .. $::form->{rowcount}) {
    push @invoices, +{ map { $_ => $::form->{"$_\_$i"} } @columns };
    $total{$_} += $invoices[-1]{$_} = $::form->parse_amount(\%::myconfig, $invoices[-1]{$_}) for qw(amount due paid);
  }

  print $::form->parse_html_template('cp/invoices', {
    invoices => \@invoices,
    totals   => \%total,
  });

  $::lxdebug->leave_sub;
}

sub form_footer {
  $::lxdebug->enter_sub;
  $::auth->assert('cash');

  print $::form->parse_html_template('cp/form_footer');

  $::lxdebug->leave_sub;
}

sub update {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my ($buysell, $updated, $exchangerate, $amount);

  if ($form->{vc} eq 'customer') {
    $buysell = "buy";
  } else {
    $buysell = "sell";
  }

  # search by invoicenumber,
  if ($form->{invnumber}) {
    $form->{open} ='Y'; # only open invoices
    if ($form->{ARAP} eq 'AR'){
      # ar_transactions automatically searches by $form->{customer_id} or else
      # $form->{customer} if available, and these variables will always be set
      # so we have to empty these values first
      $form->{customer_id} = '';
      $form->{customer} = '';
      AR->ar_transactions(\%myconfig, \%$form);

      # if you search for invoice '11' ar_transactions will also match invoices
      # 112, 211, ... due to the LIKE

      # so there is now an extra loop that tries to match the invoice number
      # exactly among all returned results, and then passes the customer_id instead of the name
      # because the name may not be unique

      my $found_exact_invnumber_match = 0;
      foreach my $i ( @{ $form->{AR} } ) {
        next unless $i->{invnumber} eq $form->{invnumber};
        # found exactly matching invnumber
        $form->{customer_id} = $i->{customer_id};
        $found_exact_invnumber_match = 1;
      };

      unless ( $found_exact_invnumber_match ) {
        # use first returned entry, may not be the correct one if invnumber doesn't
        # match uniquely
        $form->{customer_id} = $form->{AR}[0]{customer_id};
      };
    } else {
      # s.o. nur für zahlungsausgang
      AP->ap_transactions(\%myconfig, \%$form);
      $form->{vendor_id} = $form->{AP}[0]{vendor_id};
    }
  }

  # determine customer/vendor
  my $vc = $form->{vc};
  if (($form->{"previous_${vc}_id"} || $form->{"${vc}_id"}) != $form->{"${vc}_id"}) {
    IS->get_customer(\%myconfig, \%$form);
  }

  $form->{oldcurrency} = $form->{currency};

  # get open invoices from ar/ap using a.${vc}_id, i.e. customer_id
  CP->get_openinvoices(\%myconfig, \%$form) if $form->{"${vc}_id"};

  if (!$form->{forex}) {        # read exchangerate from input field (not hidden)
    $form->{exchangerate} = $form->parse_amount(\%myconfig, $form->{exchangerate});
  }
  $form->{forex}        = $form->check_exchangerate( \%myconfig, $form->{currency}, $form->{datepaid}, $buysell);
  $form->{exchangerate} = $form->{forex} if $form->{forex};

  $amount = $form->{amount} = $form->parse_amount(\%myconfig, $form->{amount});

  if ($form->{"${vc}_id"}) {
    $form->{rowcount} = 0;

    $form->{queued} = "";

    my $i = 0;
    foreach my $ref (@{ $form->{PR} }) {
      $i++;
      $form->{"id_$i"}        = $ref->{id};
      $form->{"invnumber_$i"} = $ref->{invnumber};
      $form->{"transdate_$i"} = $ref->{transdate};
      $ref->{exchangerate} = 1 unless $ref->{exchangerate};
      $form->{"amount_$i"} = $ref->{amount} / $ref->{exchangerate};
      $form->{"due_$i"}    =
        ($ref->{amount} - $ref->{paid}) / $ref->{exchangerate};
      $form->{"checked_$i"} = "";
      $form->{"paid_$i"}    = "";

      # need to format
      map {
        $form->{"${_}_$i"} =
          $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2)
      } qw(amount due);

    }
    $form->{rowcount} = $i;
  }

  # recalculate

  # Modified from $amount = $form->{amount} by J.Zach to update amount to total
  # payment amount in Zahlungsausgang
  $amount = 0;
  for my $i (1 .. $form->{rowcount}) {

    map {
      $form->{"${_}_$i"} =
        $form->parse_amount(\%myconfig, $form->{"${_}_$i"})
    } qw(amount due paid);

    if ($form->{"checked_$i"}) {

      # calculate paid_$i
      if (!$form->{"paid_$i"}) {
        $form->{"paid_$i"} = $form->{"due_$i"};
      }

      # Modified by J.Zach, see abovev
      $amount += $form->{"paid_$i"};

    } else {
      $form->{"paid_$i"} = "";
    }

    map {
      $form->{"${_}_$i"} =
        $form->format_amount(\%myconfig, $form->{"${_}_$i"}, 2)
    } qw(amount due paid);

  }

  # Line added by J.Zach, see above
  $form->{amount}=$amount;

  &form_header;
  list_invoices() if $form->{"${vc}_id"};
  &form_footer;

  $lxdebug->leave_sub();
}

sub post {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  &check_form;

  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->error($locale->text('Exchangerate missing!'))
      unless $form->{exchangerate};
  }

  # Beim Aktualisieren wird das Konto übernommen
  # und jetzt auch Beleg und Datum
  $form->{callback} = "cp.pl?action=payment&vc=$form->{vc}&type=$form->{type}&account=$form->{account}&$form->{currency}" .
                      "&datepaid=$form->{datepaid}&source=$form->{source}";

  my $msg1 = $::form->{type} eq 'receipt' ? $::locale->text("Receipt posted!") : $::locale->text("Payment posted!");
  my $msg2 = $::form->{type} eq 'receipt' ? $::locale->text("Cannot post Receipt!") : $::locale->text("Cannot post Payment!");

  # Die Nachrichten (Receipt posted!) werden nicht angezeigt.
  # Entweder wieder aktivieren oder komplett rausnehmen
  $form->redirect($msg1) if (CP->process_payment(\%::myconfig, $::form));
  $form->error($msg2);

  $lxdebug->leave_sub();
}

sub check_form {
  $lxdebug->enter_sub();

  $auth->assert('cash');

  my ($closedto, $datepaid, $amount);

  my $vc = $form->{vc};
  if (($form->{"previous_${vc}_id"} || $form->{"${vc}_id"}) != $form->{"${vc}_id"}) {
    IS->get_customer(\%myconfig, $form) if $vc eq 'customer';
    IR->get_vendor(\%myconfig, $form)   if $vc eq 'vendor';
  }

  if ($form->{currency} ne $form->{oldcurrency}) {
    &update;
    $::dispatcher->end_request;
  }
  $form->error($locale->text('Date missing!')) unless $form->{datepaid};
  my $selected_check = 1;
  for my $i (1 .. $form->{rowcount}) {
    next unless $form->{"checked_$i"};
    if (abs($form->parse_amount(\%myconfig, $form->{"paid_$i"}, 2)) < 0.01) {
      $form->error($locale->text('Row #1: amount has to be different from zero.', $i));
    }
    undef $selected_check;
  }
  $form->error($locale->text('No transaction selected!')) if $selected_check;

  $closedto = $form->datetonum($form->{closedto}, \%myconfig);
  $datepaid = $form->datetonum($form->{datepaid}, \%myconfig);

  $form->error($locale->text('Cannot process payment for a closed period!'))
    if ($form->date_closed($form->{"datepaid"}, \%myconfig));

  $amount = $form->parse_amount(\%myconfig, $form->{amount});
  $form->{amount} = $amount;

  for my $i (1 .. $form->{rowcount}) {
    if ($form->parse_amount(\%myconfig, $form->{"paid_$i"})) {
      $amount -= $form->parse_amount(\%myconfig, $form->{"paid_$i"});

      push(@{ $form->{paid}      ||= [] }, $form->{"paid_$i"});
      push(@{ $form->{due}       ||= [] }, $form->{"due_$i"});
      push(@{ $form->{invnumber} ||= [] }, $form->{"invnumber_$i"});
      push(@{ $form->{invdate}   ||= [] }, $form->{"transdate_$i"});
    }
  }

  if ($form->round_amount($amount, 2) != 0) {
    push(@{ $form->{paid} }, $form->format_amount(\%myconfig, $amount, 2));
    push(@{ $form->{due} }, $form->format_amount(\%myconfig, 0, "0"));
    push(@{ $form->{invnumber} },
         ($form->{ARAP} eq 'AR')
         ? $locale->text('Deposit')
         : $locale->text('Prepayment'));
    push(@{ $form->{invdate} }, $form->{datepaid});
  }

  $lxdebug->leave_sub();
}

sub setup_cp_form_action_bar {
  my (%params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#form', { action => "update" } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Post'),
        submit => [ '#form', { action => "post" } ],
      ],
    );
  }
}
