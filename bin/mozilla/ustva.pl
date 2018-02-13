#=====================================================================
# kivitendo ERP
# Copyright (c) 2004 by Udo Spallek, Aachen
#
#  Author: Udo Spallek
#   Email: udono@gmx.net
#     Web: http://www.lx-office.org
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
# German Tax authority Module and later ELSTER Interface
# 08.01.14  ELSTER Interface software (taxbird/winston) removed
#======================================================================

use strict;
use utf8;

require "bin/mozilla/common.pl";

#use strict;
#no strict 'refs';
#use diagnostics;
#use warnings; # FATAL=> 'all';
#use vars qw($locale $form %myconfig);
#our ($myconfig);
#use CGI::Carp "fatalsToBrowser";

use List::Util qw(first);

use SL::DB::Default;
use SL::RP;
use SL::USTVA;
use SL::User;
use SL::Locale::String qw(t8);
1;

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

#############################

sub report {
  $::lxdebug->enter_sub();

  my $form     = $::form;
  my $locale   = $::locale;
  my %myconfig = %::myconfig;

  $::auth->assert('advance_turnover_tax_return');

  my $defaults   = SL::DB::Default->get;
  $form->{title} = $locale->text('UStVA');
  $form->{kz10}  = '';                       #Berichtigte Anmeldung? Ja =1 Nein=0

  my $year = substr($form->datetonum($form->current_date(\%myconfig), \%myconfig ),
             0, 4);

  my $department = '';
  my $hide = '';

  setup_ustva_report_action_bar();
  $form->header;

  # Einlesen der Finanzamtdaten
  my $ustva = USTVA->new();
  $ustva->get_config();
  $ustva->get_finanzamt();

  # Hier Einlesen der user-config
  # steuernummer entfernt für prerelease
  my @a = qw(
    signature      name
    tel            fax           email         co_chief       co_department
    co_custom1     co_custom2    co_custom3    co_custom4     co_custom5
    co_name1       co_name2      co_street     co_street1     co_zip
    co_city        co_city1      co_country    co_tel         co_tel1
    co_tel2        co_fax        co_fax1       co_email       co_email1
    co_url         co_url1       co_bankname
    co_bankname1   co_bankname2  co_bankname3  co_blz         co_blz1
    co_blz2        co_blz3       co_accountnr  co_accountnr1  co_accountnr2
    co_accountnr3
  );

  $form->{$_} = $myconfig{$_} for @a;

  my $openings = $form->{fa_oeffnungszeiten};
  $openings =~ s/\\\\n/<br>/g;

  my $company_given = ($form->{company} ne '')
    ? qq|<h3>$form->{company}</h3>\n|
    : qq|<a href="controller.pl?action=ClientConfig/edit">|
      . $locale->text('No Company Name given') . qq|!</a><br>|;


  # Anpassungen der Variablennamen auf pre 2.1.1 Namen
  # klären, ob $form->{company_street|_address} gesetzt sind
  if ($form->{address} ne '') {
    my $temp = $form->{address};
    $temp =~ s/\n/<br \/>/;
    ($form->{co_street}, $form->{co_city}) = split("<br \/>", $temp);
    $form->{co_city} =~ s/\n//g;
  }


  my $address_given =
    ($form->{co_street} && ($form->{co_zip} || $form->{co_city}))
    ? qq|$form->{co_street}<br>|
        . qq|$form->{co_street1}<br>|
        . qq|$form->{co_zip} $form->{co_city}|
    : qq|<a href="controller.pl?action=ClientConfig/edit">|
        . $locale->text('No Company Address given')
        . qq|!</a>\n|;

  $form->{co_email} = $form->{email} unless $form->{co_email};
  $form->{co_tel}   = $form->{tel}   unless $form->{co_tel};
  $form->{co_fax}   = $form->{fax}   unless $form->{co_fax};
  $form->{co_url}   = $form->{urlx}  unless $form->{co_url};

  my $taxnumber_given = ($form->{taxnumber} ne '') ? $form->{taxnumber} : qq|<a href="ustva.pl?action=config_step1">Keine Steuernummer hinterlegt!</a><br>|;
  my $fa_name_given = ($form->{fa_name} ne '') ? $form->{fa_name} : qq|<a href="ustva.pl?action=config_step1">Kein Finanzamt hinterlegt!</a><br>|;
  my $ustva_vorauswahl = &ustva_vorauswahl();

  my @all_years = $form->all_years(\%myconfig);

  my $select_year = qq|<select name=year title="|
    . $locale->text('Year') . qq|">|;
  foreach my $key (@all_years) {
    $select_year .= qq|<option |;
    $select_year .= qq|selected| if ($key eq $form->{year});
    $select_year .= qq| >$key</option>|;
  }
  $select_year   .=  qq|</select>|;

  my $_checked = '';
  $_checked = "checked" if ($form->{kz10} eq '1');
  my $checkbox_kz_10 = qq|<input name="FA_10" id=FA_10 class=checkbox|
    . qq| type=checkbox value="1" $_checked title = "|
    . $locale->text('Amended Advance Turnover Tax Return').'(Nr. 10)'
    . qq|">|
    . $locale->text('Amended Advance Turnover Tax Return');

  $_checked = "checked" if ($form->{kz22} eq '1');
  my $checkbox_kz_22 = qq|<input name="FA_22" id=FA_22 class=checkbox|
    . qq| type=checkbox value="1" $_checked title = "|
    . $locale->text('Receipts attached/extra').'(Nr. 22)'
    . qq|">|
    . $locale->text('Receipts attached/extra');

  $_checked = "checked" if ($form->{kz29} eq '1');
  my $checkbox_kz_29 = qq|<input name="FA_29" id=FA_29 class=checkbox|
    . qq| type=checkbox value="1" $_checked title = "|
    . $locale->text('Accounting desired').'(Nr. 29)'
    . qq|">|
    . $locale->text('Accounting desired');

  $_checked = "checked" if ($form->{kz26} eq '1');
  my $checkbox_kz_26 = qq|<input name="FA_26" id=FA_26 class=checkbox|
    . qq| type=checkbox value="1" $_checked title = "|
    . $locale->text('Direct debit revoked').'(Nr. 26)'
    . qq|">|
    . $locale->text('Direct debit revoked');

  my $method_local = ($form->{accounting_method} eq 'accrual') ? $locale->text('accrual')
                   : ($form->{accounting_method} eq 'cash')    ? $locale->text('cash')
                   : '';

  my $period_local = ( $form->{fa_voranmeld} eq 'month')   ? $locale->text('month')
                   : ( $form->{fa_voranmeld} eq 'quarter') ? $locale->text('quarter')
                   : '';

  my @tax_office_banks_ref = (
    { BLZ             => $form->{fa_blz_1},
      Kontonummer     => $form->{fa_kontonummer_1},
      Bankbezeichnung => $form->{fa_bankbezeichnung_1}
    },
    { BLZ             => $form->{fa_blz_2},
      Kontonummer     => $form->{fa_kontonummer_2},
      Bankbezeichnung => $form->{fa_bankbezeichnung_2}
    }
  );

  $ustva->get_coa($form); # fetches coa and modifies some form variables

  my $template_ref = {
    openings         => $openings,
    company_given    => $company_given,
    address_given    => $address_given,
    taxnumber_given  => $taxnumber_given,
    fa_name_given    => $fa_name_given,
    taxnumber        => $defaults->taxnumber,
    select_year      => $select_year,
    period_local     => $period_local,
    method_local     => $method_local,
    ustva_vorauswahl => $ustva_vorauswahl,
    checkbox_kz_10   => $checkbox_kz_10,
    checkbox_kz_22   => $checkbox_kz_22,
    checkbox_kz_29   => $checkbox_kz_29,
    checkbox_kz_26   => $checkbox_kz_26,
    tax_office_banks => \@tax_office_banks_ref,
    select_options   => &show_options,

  };

  print($form->parse_html_template('ustva/report', $template_ref));

  $::lxdebug->leave_sub();
}



sub help {
  $::lxdebug->enter_sub();

  $::auth->assert('advance_turnover_tax_return');

  # parse help documents under doc
  $::form->{templates} = 'doc';
  $::form->{help}      = 'ustva';
  $::form->{type}      = 'help';
  $::form->{format}    = 'html';
  generate_ustva();

  $::lxdebug->leave_sub();
}

sub show {
  $::lxdebug->enter_sub();

  $::auth->assert('advance_turnover_tax_return');

  #generate_ustva();
  $::lxdebug->leave_sub();
  call_sub($::form->{"nextsub"});
}

sub ustva_vorauswahl {
  $::lxdebug->enter_sub();

  my $form     = $::form;
  my $locale   = $::locale;
  my %myconfig = %::myconfig;

  $::auth->assert('advance_turnover_tax_return');

  my $select_vorauswahl;

  #Aktuelles Datum zerlegen:
  my $date = $form->datetonum($form->current_date(\%myconfig), \%myconfig);

  #$locale->date($myconfig, $form->current_date($myconfig), 0)=~ /(\d\d).(\d\d).(\d\d\d\d)/;
  $form->{day}   = substr($date, 6, 2);
  $form->{month} = substr($date, 4, 2);
  $form->{year}  = substr($date, 0, 4);
  $::lxdebug->message(LXDebug->DEBUG1, qq|
    Actual date from Database: $date\n
    Actual year from Database: $form->{year}\n
    Actual day from Database: $form->{day}\n
    Actual month from Database: $form->{month}\n|);

  my $sel    = '';
  my $yymmdd = '';

  # Testdaten erzeugen:
  #$form->{day}= '11';
  #$form->{month}= '01';
  #$form->{year}= 2004;
  $select_vorauswahl = qq|
     <input type="hidden" name="day" value="$form->{day}">
     <input type="hidden" name="month" value="$form->{month}">
     <input type="hidden" name="yymmdd" value="$yymmdd">
     <input type="hidden" name="sel" value="$sel">
  |;

  if ($form->{fa_voranmeld} eq 'month') {

    # Vorauswahl bei monatlichem Voranmeldungszeitraum

    my %liste = ('01' => $locale->text('January'),
                 '02' => $locale->text('February'),
                 '03' => $locale->text('March'),
                 '04' => $locale->text('April'),
                 '05' => $locale->text('May'),
                 '06' => $locale->text('June'),
                 '07' => $locale->text('July'),
                 '08' => $locale->text('August'),
                 '09' => $locale->text('September'),
                 '10' => $locale->text('October'),
                 '11' => $locale->text('November'),
                 '12' => $locale->text('December'),
                 '13' => $locale->text('Yearly'),
                );

    my $yy = $form->{year} * 10000;
    $yymmdd = "$form->{year}$form->{month}$form->{day}" * 1;
    $sel    = '';
    my $dfv = '';

    # Offset für Dauerfristverlängerung
    $dfv = '100' if ($form->{fa_dauerfrist} eq '1');

  SWITCH: {
      $yymmdd <= ($yy + 110 + $dfv) && do {
        $form->{year} = $form->{year} - 1;
        $sel = '12';
        last SWITCH;
      };
      $yymmdd <= ($yy + 210 + $dfv) && do {
        $sel = '01';
        last SWITCH;
      };
      $yymmdd <= ($yy + 310 + $dfv) && do {
        $sel = '02';
        last SWITCH;
      };
      $yymmdd <= ($yy + 410 + $dfv) && do {
        $sel = '03';
        last SWITCH;
      };
      $yymmdd <= ($yy + 510 + $dfv) && do {
        $sel = '04';
        last SWITCH;
      };
      $yymmdd <= ($yy + 610 + $dfv) && do {
        $sel = '05';
        last SWITCH;
      };
      $yymmdd <= ($yy + 710 + $dfv) && do {
        $sel = '06';
        last SWITCH;
      };
      $yymmdd <= ($yy + 810 + $dfv) && do {
        $sel = '07';
        last SWITCH;
      };
      $yymmdd <= ($yy + 910 + $dfv) && do {
        $sel = '08';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1010 + $dfv) && do {
        $sel = '09';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1110 + $dfv) && do {
        $sel = '10';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1210) && do {
        $sel = '11';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1231) && do {
        $sel = '12';
        last SWITCH;
      };

    }
    $select_vorauswahl .= qq|<select id="zeitraum" name="period" title="|
  . $locale->text('Select a period') . qq|" >|;

    my $key = '';
    foreach $key (sort keys %liste) {
      my $selected = '';
      $selected = 'selected' if ($sel eq $key);
      $select_vorauswahl .= qq|
         <option value="$key" $selected> $liste{$key}</option>
      |;
    }
    $select_vorauswahl .= qq|</select>|;

  } elsif ($form->{fa_voranmeld} eq 'quarter') {

    # Vorauswahl bei quartalsweisem Voranmeldungszeitraum
    my %liste = ('41'  => $locale->text('1. Quarter'),
                 '42'  => $locale->text('2. Quarter'),
                 '43'  => $locale->text('3. Quarter'),
                 '44'  => $locale->text('4. Quarter'),
                 '13' => $locale->text('Yearly'),);

    my $yy = $form->{year} * 10000;
    $yymmdd = "$form->{year}$form->{month}$form->{day}" * 1;
    $sel    = '';
    my $dfv = '';    # Offset für Dauerfristverlängerung
    $dfv = '100' if ($form->{fa_dauerfrist} eq '1');

  SWITCH: {
      $yymmdd <= ($yy + 110 + $dfv) && do {
        $form->{year} = $form->{year} - 1;
        $sel = '44';
        last SWITCH;
      };
      $yymmdd <= ($yy + 410 + $dfv) && do {
        $sel = '41';
        last SWITCH;
      };
      $yymmdd <= ($yy + 710 + $dfv) && do {
        $sel = '42';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1010 + $dfv) && do {
        $sel = '43';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1231) && do {
        $sel = '44';
      };
    }

    $select_vorauswahl .= qq|<select id="zeitraum" name="period" title="|
      . $locale->text('Select a period') . qq|" >|;
    my $key = '';
    foreach $key (sort keys %liste) {
      my $selected = '';
      $selected = 'selected' if ($sel eq $key);
      $select_vorauswahl .= qq|
         <option value="$key" $selected>$liste{$key}</option>
     |;
    }
    $select_vorauswahl .= qq|\n</select>
   |;

  } else {

    # keine Vorauswahl bei Voranmeldungszeitraum
    $select_vorauswahl .= qq|<select id="zeitraum" name="period" title="|
      . $locale->text('Select a period') . qq|" >|;

    my %listea = ('41' => '1. Quarter',
                  '42' => '2. Quarter',
                  '43' => '3. Quarter',
                  '44' => '4. Quarter',);

    my %listeb = ('01' => 'January',
                  '02' => 'February',
                  '03' => 'March',
                  '04' => 'April',
                  '05' => 'May',
                  '06' => 'June',
                  '07' => 'July',
                  '08' => 'August',
                  '09' => 'September',
                  '10' => 'October',
                  '11' => 'November',
                  '12' => 'December',
                  '13' => 'Yearly',);
    my $key = '';
    foreach $key (sort keys %listea) {
      $select_vorauswahl .= qq|
         <option value="$key">|
        . $locale->text("$listea{$key}")
        . qq|</option>\n|;
    }

    foreach $key (sort keys %listeb) {
      $select_vorauswahl .= qq|
         <option value="$key">|
        . $locale->text("$listeb{$key}")
        . qq|</option>\n|;
    }
    $select_vorauswahl .= qq|</select>|;
  }
  $::lxdebug->leave_sub();

  return $select_vorauswahl;
}

#sub config {
#  $::lxdebug->enter_sub();
#  config_step1();
#  $::lxdebug->leave_sub();
#}

sub show_options {
  $::lxdebug->enter_sub();

  $::auth->assert('advance_turnover_tax_return');

  #  $form->{PD}{$form->{type}} = "selected";
  #  $form->{DF}{$form->{format}} = "selected";
  #  $form->{OP}{$form->{media}} = "selected";
  #  $form->{SM}{$form->{sendmode}} = "selected";
  my $type   = qq|      <input type=hidden name="type" value="ustva">|;
  my $media  = qq|      <input type=hidden name="media" value="screen">|;
  my $format =
      qq|       <option value=html selected>|
    . $::locale->text('HTML')
    . qq|</option>|;

  #my $disabled= qq|disabled="disabled"|;
  #$disabled='' if ($form->{elster} eq '1' );
  #if ($::form->{elster} eq '1') {
  if ( 1 ) {
    $format .=
        qq|<option value=elstertaxbird>|
      . $::locale->text('ELSTER Export (via Geierlein)')
      . qq|</option>|;
  }

  my $show_options = qq|
    $type
    $media
    <select name=format title = "|
    . $::locale->text('Choose Outputformat') . qq|">$format</select>
  |;
  $::lxdebug->leave_sub();

  return $show_options;
}

sub generate_ustva {
  $::lxdebug->enter_sub();

  my $form     = $::form;
  my $locale   = $::locale;
  my %myconfig = %::myconfig;

  $::auth->assert('advance_turnover_tax_return');

  my $defaults = SL::DB::Default->get;
  $form->error($::locale->text('No print templates have been created for this client yet. Please do so in the client configuration.')) if !$defaults->templates;
  $form->{templates} = $defaults->templates;


  my $ustva = USTVA->new();
  $ustva->get_config();
  $ustva->get_finanzamt();

  # Setze Anmeldungszeitraum

  $ustva->set_FromTo(\%$form);

  # Get the USTVA
  $ustva->ustva(\%myconfig, \%$form);

  # reformat Dates to dateformat
  $form->{fromdate} = $locale->date(\%myconfig, $form->{fromdate}, 0, 0, 0);

  $form->{todate} = $form->current_date(\%myconfig) unless $form->{todate};
  $form->{todate} = $locale->date(\%myconfig, $form->{todate}, 0, 0, 0);

  $form->{longperiod} =
    $locale->date(\%myconfig, $form->current_date(\%myconfig), 1, 0, 0);

  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {

    $form->{todate} = $form->current_date(\%myconfig)  unless ($form->{todate});

    my $longtodate  = $locale->date(\%myconfig, $form->{todate}, 1, 0, 0);
    my $shorttodate = $locale->date(\%myconfig, $form->{todate}, 0, 0, 0);

    my $longfromdate  = $locale->date(\%myconfig, $form->{fromdate}, 1, 0, 0);
    my $shortfromdate = $locale->date(\%myconfig, $form->{fromdate}, 0, 0, 0);

    $form->{this_period} = "$shortfromdate<br>\n$shorttodate";
    $form->{longperiod}      =
        $locale->text('for Period')
      . qq|<br>\n$longfromdate |
      . $locale->text('to (date)')
      . qq| $longtodate|;
  }

  if ($form->{comparefromdate} || $form->{comparetodate}) {
    my $longcomparefromdate =
      $locale->date(\%myconfig, $form->{comparefromdate}, 1, 0, 0);
    my $shortcomparefromdate =
      $locale->date(\%myconfig, $form->{comparefromdate}, 0, 0, 0);

    my $longcomparetodate =
      $locale->date(\%myconfig, $form->{comparetodate}, 1, 0, 0);
    my $shortcomparetodate =
      $locale->date(\%myconfig, $form->{comparetodate}, 0, 0, 0);

    $form->{last_period} = "$shortcomparefromdate<br>\n$shortcomparetodate";
    $form->{longperiod} .=
        "<br>\n$longcomparefromdate "
      . $locale->text('to (date)')
      . qq| $longcomparetodate|;
  }

  $form->{Datum_heute} =
    $locale->date(\%myconfig, $form->current_date(\%myconfig), 0, 0, 0);

  # setup variables for the form
  my @a = qw(tel fax email
    co_chief co_department co_custom1 co_custom2 co_custom3 co_custom4 co_custom5
    co_name1 co_name2  co_street co_street1 co_zip co_city co_city1 co_country co_tel co_tel1 co_tel2
    co_fax co_fax1 co_email co_email1 co_url co_url1
    co_bankname co_bankname1 co_bankname2 co_bankname3 co_blz co_blz1
    co_blz2 co_blz3 co_accountnr co_accountnr1 co_accountnr2 co_accountnr3);

  $form->{$_} = $myconfig{$_} for @a;
  $form->{$_} = $defaults->$_ for qw(company address co_ustid duns);

  if ($form->{address} ne '') {
    my $temp = $form->{address};
    $temp =~ s/\n/<br \/>/;
    ($form->{co_street}, $form->{co_city}) = split("<br \/>", $temp,2);
    $form->{co_city} =~ s/\\n//g;
  }

  ################################
  #
  # Nation specific customisations
  #
  ################################

  # Germany

  if ( $form->{coa} eq 'Germany-DATEV-SKR03EU' or $form->{coa} eq 'Germany-DATEV-SKR04EU') {

   $form->{id} = [];
   $form->{amount} = [];

   if ( $form->{format} eq 'pdf' or $form->{format} eq 'postscript') {

      $form->{IN} = "$form->{type}-$form->{year}.tex";
      $form->{padding} = "~~";
      $form->{bold}    = "\textbf{";
      $form->{endbold} = "}";
      $form->{br}      = '\\\\';

      # Zahlenformatierung für Latex USTVA Formulare

      foreach my $number (@{$::form->{category_euro}}) {
        $form->{$number} = $form->format_amount(\%myconfig, $form->{$number}, '0', '');
      }

      my ${decimal_comma} = ( $myconfig{numberformat} eq '1.000,00'
           or $myconfig{numberformat} eq '1000,00' ) ? ',':'.';

      foreach my $number (@{$::form->{category_cent}}) {
        $form->{$number} = $form->format_amount(\%myconfig, $form->{$number}, '2', '');
        $form->{$number} =~ s/${decimal_comma}/~~/g;
      }

    } elsif ( $form->{format} eq 'html') { # Formatierungen für HTML Ausgabe

      $form->{IN} = $form->{type} . '.html';
      $form->{padding} = "&nbsp;&nbsp;";
      $form->{bold}    = "<b>";
      $form->{endbold} = "</b>";
      $form->{br}      = "<br>";
      $form->{address} =~ s/\\n/\n/g;

      foreach my $number (@{$::form->{category_cent}}) {
        $form->{$number} = $form->format_amount(\%myconfig, $form->{$number}, '2', '0');
      }

      foreach my $number (@{$::form->{category_euro}}) {
        $form->{$number} = $form->format_amount(\%myconfig, $form->{$number}, '0', '0');
      }
    } elsif ( $form->{format} eq '' ){ # No format error.

      $form->header;
      USTVA::error( $locale->text('Application Error. No Format given' ) . "!");
      $::dispatcher->end_request;

    } else { # All other Formats are wrong
      $form->header;
      USTVA::error( $locale->text('Application Error. Wrong Format') . ": " . $form->{format} );
      $::dispatcher->end_request;
    }


  } else  # Outputformat for generic output
  {

    $form->{USTVA} = [];

    if ( $form->{format} eq 'generic') { # Formatierungen für HTML Ausgabe

      my $rec_ref = {};
      for my $kennziffer (@{$::form->{category_cent}}, @{$::form->{category_euro}}) {
        $rec_ref = {};
        $rec_ref->{id} = $kennziffer;
        $rec_ref->{amount} = $form->format_amount(\%myconfig, $form->{$kennziffer}, 2, '0');

        $::lxdebug->message($LXDebug::DEBUG, "Kennziffer $kennziffer: '$form->{$kennziffer}'" );
        $::lxdebug->dump($LXDebug::DEBUG, $rec_ref );
        push @ { $form->{USTVA} }, $rec_ref;
      }

    }

  }

  if ( $form->{period} eq '13' and $form->{format} ne 'html') {
    $form->header;
    USTVA::info(
      $locale->text(
      'Yearly taxreport not yet implemented')
      . '!');
  }

  $form->{templates} = "doc" if ( $form->{type} eq 'help' );

  if ($form->{format} eq 'generic'){

    $form->header();

    my $template_ref = {
        taxnumber => $defaults->taxnumber,
    };

    print($form->parse_html_template('ustva/generic_taxreport', $template_ref));

  } elsif ( $form->{format} eq 'elstertaxbird' ) {
   $form->parse_template(\%myconfig);
  } else
  {
   # add a prefix for ustva pos numbers, i.e.: 81 ->  post_ustva_81
   $form->{"pos_ustva_$_"} = $form->{$_} for grep { m{^\d+} } keys %{ $form };
   $form->{title} = $locale->text('Advance turnover tax return');

   $form->header;
   print $form->parse_html_template('ustva/ustva');


  }

  $::lxdebug->leave_sub();
}

sub config_step1 {
  $::lxdebug->enter_sub();

  $::auth->assert('advance_turnover_tax_return');

$::form->{title} = $::locale->text('Tax Office Preferences');

  # edit all taxauthority prefs

  setup_ustva_config_step1_action_bar();

  $::form->header;

  my $ustva = USTVA->new();
  $ustva->get_config();
  $ustva->get_finanzamt();

  my $land = $::form->{fa_land_nr};
  my $amt  = $::form->{fa_bufa_nr};


  $::form->{title} = $::locale->text('Tax Office Preferences');


  my $select_tax_office               = $ustva->fa_auswahl($land, $amt, $ustva->query_finanzamt(\%::myconfig, $::form));
  my $method_local = ($::form->{accounting_method} eq 'accrual') ? $::locale->text('accrual')
                   : ($::form->{accounting_method} eq 'cash')    ? $::locale->text('cash')
                   : '';

  my $checked_monthly                 = $::form->{fa_voranmeld}  eq 'month'   ? "checked"            : '';
  my $checked_quarterly               = $::form->{fa_voranmeld}  eq 'quarter' ? "checked"            : '';
  my $checked_dauerfristverlaengerung = $::form->{da_dauerfrist} eq '1'       ? "checked"            : '';

  my $_hidden_variables_ref;

  my %_hidden_local_variables = (
    'saved'       => $::locale->text('Check Details'),
  );

  foreach my $variable (keys %_hidden_local_variables) {
    push @{ $_hidden_variables_ref },
        { 'variable' => $variable, 'value' => $_hidden_local_variables{$variable} };
  }

  my @_hidden_form_variables = $ustva->get_fiamt_vars();
  push @_hidden_form_variables ,qw(fa_bufa_nr taxnumber accounting_method coa);

  foreach my $variable (@_hidden_form_variables) {
    push @{ $_hidden_variables_ref},
        { 'variable' => $variable, 'value' => $::form->{$variable} };
  }

  $ustva->get_coa($::form); # fetches coa and modifies some form variables

  # Variablen für das Template zur Verfügung stellen
  my $template_ref = {
     select_tax_office               => $select_tax_office,
     method_local                    => $method_local,
     checked_monthly                 => $checked_monthly,
     checked_quarterly               => $checked_quarterly,
     checked_dauerfristverlaengerung => $checked_dauerfristverlaengerung,
     hidden_variables                => $_hidden_variables_ref,

  };

  # Ausgabe des Templates
  print($::form->parse_html_template('ustva/config_step1', $template_ref));

  $::lxdebug->leave_sub();
}

sub config_step2 {
  $::lxdebug->enter_sub();

  my $form     = $::form;
  my $locale   = $::locale;
  my %myconfig = %::myconfig;

  $::auth->assert('advance_turnover_tax_return');

  setup_ustva_config_step2_action_bar();

  $form->header();

  my $fa_land_nr         = '';
  my $fa_bufa_nr         = '';

  my $ustva = USTVA->new();
  $ustva->get_config() if ($form->{saved} eq $locale->text('saved'));
  my $coa = $::form->{coa};
  $form->{"COA_$coa"}  = '1';
  $form->{COA_Germany} = '1' if ($coa =~ m/^germany/i);
  $ustva->get_finanzamt();


  # Auf Übergabefehler checken
  USTVA::info(  $locale->text('Missing Tax Authoritys Preferences') . "\n"
              . $locale->text('USTVA-Hint: Tax Authoritys'))
    if (   $form->{fa_bufa_nr_new} eq 'Auswahl'
        || $form->{fa_land_nr_new} eq 'Auswahl');
  USTVA::info(  $locale->text('Missing Method!') . "\n"
              . $locale->text('USTVA-Hint: Method'))
    if ($form->{accounting_method} eq '');

  # Klären, ob Variablen bereits befüllt sind UND ob veränderungen auf
  # der vorherigen Maske stattfanden: $change = 1(in der edit sub,
  # mittels get_config)

#  $::lxdebug->message(LXDebug->DEBUG2,"land old=".$form->{fa_land_nr}." new=".$form->{fa_land_nr_new});
#  $::lxdebug->message(LXDebug->DEBUG2,"bufa old=".$form->{fa_bufa_nr}." new=".$form->{fa_bufa_nr_new});
  my $change = $form->{fa_land_nr} eq $form->{fa_land_nr_new}
    && $form->{fa_bufa_nr} eq $form->{fa_bufa_nr_new} ? '0' : '1';
  $change = '0' if ($form->{saved} eq $locale->text('saved'));


  if ($change eq '1') {

    # Daten ändern
    $fa_land_nr           = $form->{fa_land_nr_new};
    $fa_bufa_nr           = $form->{fa_bufa_nr_new};
    $form->{fa_land_nr}   = $fa_land_nr;
    $form->{fa_bufa_nr}   = $fa_bufa_nr;
    $form->{taxnumber} = '';

    create_steuernummer();

    # rebuild elster_amt
    $ustva->get_finanzamt();

  } else {

    $fa_land_nr = $form->{fa_land_nr};
    $fa_bufa_nr = $form->{fa_bufa_nr};

  }
#  $::lxdebug->message(LXDebug->DEBUG2, "form stnr=".$form->{taxnumber}." fa_bufa_nr=".$fa_bufa_nr.
#                      " pattern=".$form->{elster_pattern}." fa_land_nr=".$fa_land_nr);
  my $stnr = $form->{taxnumber};
  $stnr =~ s/\D+//g;
  my $taxnumber      = $stnr eq '' ? $form->{taxnumber} : '';

  $form->{fa_oeffnungszeiten} =~ s/\\\\n/\n/g;


  $ustva->get_coa($form); # fetches coa and modifies some form variables

  my $input_steuernummer = $ustva->steuernummer_input(
                             $fa_land_nr,
                             $fa_bufa_nr,
                             $form->{taxnumber}
  );

#  $::lxdebug->message(LXDebug->DEBUG2, qq|$input_steuernummer|);


  my $_hidden_variables_ref;

  my %_hidden_local_variables = (
      'fa_land_nr'          => $fa_land_nr,
      'fa_bufa_nr'          => $fa_bufa_nr,
      'taxnumber'           => $stnr,
      'lastsub'             => 'config_step1',
      'nextsub'             => 'save',

  );

  foreach my $variable (keys %_hidden_local_variables) {
    push @{ $_hidden_variables_ref },
        { 'variable' => $variable, 'value' => $_hidden_local_variables{$variable} };
  }

  my @_hidden_form_variables = qw(
    fa_dauerfrist fa_steuerberater_city fa_steuerberater_name
    fa_steuerberater_street fa_steuerberater_tel
    fa_voranmeld fa_dauerfrist
    accounting_method
    type
    saved
  );

  foreach my $variable (@_hidden_form_variables) {
    push @{ $_hidden_variables_ref},
        { 'variable' => $variable, 'value' => $form->{$variable} };
  }

  my $template_ref = {
     input_steuernummer              => $input_steuernummer,
     readonly                        => '', #q|disabled="disabled"|,
     COA_Germany                     => $form->{COA_Germany},
     hidden_variables                => $_hidden_variables_ref,
  };

  # Ausgabe des Templates
  print($form->parse_html_template('ustva/config_step2', $template_ref));


  $::lxdebug->leave_sub();
}

sub create_steuernummer {
  $::lxdebug->enter_sub();

  $::auth->assert('advance_turnover_tax_return');

  my $part           = $::form->{part};
  my $patterncount   = $::form->{patterncount};
  my $delimiter      = $::form->{delimiter1};
  my $elster_pattern = $::form->{elster_pattern};

  # rebuild taxnumber
  # es gibt eine gespeicherte steuernummer $form->{taxnumber}
  # und die parts und delimiter

  my $h = 0;
  my $i = 0;

  my $taxnumber_new       = $part;

  for ($h = 1; $h < $patterncount; $h++) {
    $delimiter = $::form->{delimiter2} if $h > 1;
    $taxnumber_new .= qq|$delimiter|;
    for (my $i = 1; $i <= length($elster_pattern); $i++) {
      $taxnumber_new       .= $::form->{"part_$h\_$i"};
    }
  }
#  $::lxdebug->message(LXDebug->DEBUG2, "oldstnr=".$::form->{taxnumber}." newstnr=".$taxnumber_new);
  if ($::form->{taxnumber} ne $taxnumber_new) {
    $::form->{taxnumber}       = $taxnumber_new;
    $::form->{taxnumber_new}   = $taxnumber_new;
  } else {
    $::form->{taxnumber_new}       = '';
  }
  $::lxdebug->leave_sub();
}

sub save {
  $::lxdebug->enter_sub();

  $::auth->assert('advance_turnover_tax_return');

  #zuerst die steuernummer aus den part, parts_X_Y und delimiter herstellen
  create_steuernummer();

  # Textboxen formatieren: Linebreaks entfernen
  #
  $::form->{fa_oeffnungszeiten} =~ s/\r\n/\\n/g;

  #URL mit http:// davor?
  $::form->{fa_internet} =~ s/^http:\/\///;
  $::form->{fa_internet} = 'http://' . $::form->{fa_internet};

  # Hier kommt dann die Plausibilitätsprüfung der ELSTERSteuernummer TODO ??
  if (1) {
    my $ustva = USTVA->new();
    $ustva->save_config();

    #$::form->{elster} = '1';
    $::form->{saved} = $::locale->text('saved');

  } else {

    $::form->{saved} = $::locale->text('Choose a Tax Number');
  }

  config_step2();
  $::lxdebug->leave_sub();
}


sub continue {
  $::lxdebug->enter_sub();

  # allow Symbolic references just here:
  call_sub($::form->{"nextsub"});
  $::lxdebug->leave_sub();
}

sub back {
  $::lxdebug->enter_sub();
  call_sub($::form->{"lastsub"});
  $::lxdebug->leave_sub();
}

sub setup_ustva_report_action_bar {
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#form_do', { action => 'generate_ustva' } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Geierlein'),
        call     => [ 'sendGeierlein' ],
        disabled => !length($::lx_office_conf{paths}{geierlein_path} // '') ? t8('The Geierlein path has not been set in the configuration.') : undef,
        tooltip  => t8('Transfer data to Geierlein ELSTER application'),
      ],
    );
  }
}

sub setup_ustva_config_step1_action_bar {
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Continue'),
        submit    => [ '#form', { action => 'config_step2' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_ustva_config_step2_action_bar {
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Save'),
        submit    => [ '#form', { action => 'save' } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}
