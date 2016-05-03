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
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
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
use SL::PE;
use SL::RP;
use SL::USTVA;
use SL::User;
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
  $form->header;

  # Einlesen der Finanzamtdaten
  my $ustva = USTVA->new();
  $ustva->get_config($::lx_office_conf{paths}{userspath}, 'finanzamt.ini');

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
  $form->{$_} = $defaults->$_ for qw(company address co_ustid duns);

  my $openings = $form->{FA_Oeffnungszeiten};
  $openings =~ s/\\\\n/<br>/g;

  my $company_given = ($form->{company} ne '')
    ? qq|<h3>$form->{company}</h3>\n|
    : qq|<a href="am.pl?action=config">|
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
    : qq|<a href="am.pl?action=config|
        . qq|&level=Programm--Preferences">|
        . $locale->text('No Company Address given')
        . qq|!</a>\n|;

  $form->{co_email} = $form->{email} unless $form->{co_email};
  $form->{co_tel}   = $form->{tel}   unless $form->{co_tel};
  $form->{co_fax}   = $form->{fax}   unless $form->{co_fax};
  $form->{co_url}   = $form->{urlx}  unless $form->{co_url};

  my $taxnumber_given = ($form->{steuernummer} ne '') ? $form->{steuernummer} : qq|<a href="ustva.pl?action=config_step1">Keine Steuernummer hinterlegt!</a><br>|;

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
    . $locale->text('Amended Advance Turnover Tax Return (Nr. 10)')
    . qq|">|
    . $locale->text('Amended Advance Turnover Tax Return');

  my $method_local = ($form->{method} eq 'accrual') ? $locale->text('accrual')
                   : ($form->{method} eq 'cash')    ? $locale->text('cash')
                   : '';

  my $period_local = ( $form->{FA_voranmeld} eq 'month')   ? $locale->text('month')
                   : ( $form->{FA_voranmeld} eq 'quarter') ? $locale->text('quarter')
                   : '';

  my $tax_office_banks_ref = [
    { BLZ             => $form->{FA_BLZ_1},
      Kontonummer     => $form->{FA_Kontonummer_1},
      Bankbezeichnung => $form->{FA_Bankbezeichnung_1}
    },
    { BLZ             => $form->{FA_BLZ_2},
      Kontonummer     => $form->{FA_Kontonummer_2},
      Bankbezeichnung => $form->{FA_Bankbezeichnung_oertlich}
    }
  ];

  # Which COA is in use?

  $ustva->get_coa($form); # fetches coa and modifies some form variables

  my $template_ref = {
    openings         => $openings,
    company_given    => $company_given,
    address_given    => $address_given,
    taxnumber_given  => $taxnumber_given,
    taxnumber        => $defaults->taxnumber,
    select_year      => $select_year,
    period_local     => $period_local,
    method_local     => $method_local,
    ustva_vorauswahl => $ustva_vorauswahl,
    checkbox_kz_10   => $checkbox_kz_10,
    tax_office_banks => $tax_office_banks_ref,
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

  #&generate_ustva();
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
     <input type=hidden name=day value=$form->{day}>
     <input type=hidden name=month value=$form->{month}>
     <input type=hidden name=yymmdd value=$yymmdd>
     <input type=hidden name=sel value=$sel>
  |;

  if ($form->{FA_voranmeld} eq 'month') {

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
    $dfv = '100' if ($form->{FA_dauerfrist} eq '1');

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

  } elsif ($form->{FA_voranmeld} eq 'quarter') {

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
    $dfv = '100' if ($form->{FA_dauerfrist} eq '1');

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

sub debug {
  $::lxdebug->enter_sub();
  $::form->debug();
  $::lxdebug->leave_sub();
}

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

  # Aufruf von get_config zum Einlesen der Finanzamtdaten aus finanzamt.ini

  my $ustva = USTVA->new();
  $ustva->get_config($::lx_office_conf{paths}{userspath}, 'finanzamt.ini');

  # init some form vars
  my @anmeldungszeitraum =
    qw('0401' '0402' '0403'
       '0404' '0405' '0406'
       '0407' '0408' '0409'
       '0410' '0411' '0412'
       '0441' '0442' '0443' '0444');

  foreach my $item (@anmeldungszeitraum) {
    $form->{$item} = "";
  }

    #forgotten the year --> thisyear
    if ($form->{year} !~ m/^\d\d\d\d$/) {
      $form->{year} = substr(
                             $form->datetonum(
                                    $form->current_date(\%myconfig), \%myconfig
                             ),
                             0, 4);
      $::lxdebug->message(LXDebug->DEBUG1,
                        qq|Actual year from Database: $form->{year}\n|);
    }

    #
    # using dates in ISO-8601 format: yyyymmmdd  for Postgres...
    #

    #yearly report
    if ($form->{period} eq "13") {
      $form->{fromdate} = "$form->{year}0101";
      $form->{todate}   = "$form->{year}1231";
    }

    #Quater reports
    if ($form->{period} eq "41") {
      $form->{fromdate} = "$form->{year}0101";
      $form->{todate}   = "$form->{year}0331";
      $form->{'0441'}   = "X";
    }
    if ($form->{period} eq "42") {
      $form->{fromdate} = "$form->{year}0401";
      $form->{todate}   = "$form->{year}0630";
      $form->{'0442'}   = "X";
    }
    if ($form->{period} eq "43") {
      $form->{fromdate} = "$form->{year}0701";
      $form->{todate}   = "$form->{year}0930";
      $form->{'0443'}   = "X";
    }
    if ($form->{period} eq "44") {
      $form->{fromdate} = "$form->{year}1001";
      $form->{todate}   = "$form->{year}1231";
      $form->{'0444'}   = "X";
    }

    #Monthly reports
  SWITCH: {
      $form->{period} eq "01" && do {
        $form->{fromdate} = "$form->{year}0101";
        $form->{todate}   = "$form->{year}0131";
        $form->{'0401'}   = "X";
        last SWITCH;
      };
      $form->{period} eq "02" && do {
        $form->{fromdate} = "$form->{year}0201";

        #this works from 1901 to 2099, 1900 and 2100 fail.
        my $leap = ($form->{year} % 4 == 0) ? "29" : "28";
        $form->{todate} = "$form->{year}02$leap";
        $form->{"0402"} = "X";
        last SWITCH;
      };
      $form->{period} eq "03" && do {
        $form->{fromdate} = "$form->{year}0301";
        $form->{todate}   = "$form->{year}0331";
        $form->{"0403"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "04" && do {
        $form->{fromdate} = "$form->{year}0401";
        $form->{todate}   = "$form->{year}0430";
        $form->{"0404"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "05" && do {
        $form->{fromdate} = "$form->{year}0501";
        $form->{todate}   = "$form->{year}0531";
        $form->{"0405"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "06" && do {
        $form->{fromdate} = "$form->{year}0601";
        $form->{todate}   = "$form->{year}0630";
        $form->{"0406"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "07" && do {
        $form->{fromdate} = "$form->{year}0701";
        $form->{todate}   = "$form->{year}0731";
        $form->{"0407"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "08" && do {
        $form->{fromdate} = "$form->{year}0801";
        $form->{todate}   = "$form->{year}0831";
        $form->{"0408"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "09" && do {
        $form->{fromdate} = "$form->{year}0901";
        $form->{todate}   = "$form->{year}0930";
        $form->{"0409"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "10" && do {
        $form->{fromdate} = "$form->{year}1001";
        $form->{todate}   = "$form->{year}1031";
        $form->{"0410"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "11" && do {
        $form->{fromdate} = "$form->{year}1101";
        $form->{todate}   = "$form->{year}1130";
        $form->{"0411"}   = "X";
        last SWITCH;
      };
      $form->{period} eq "12" && do {
        $form->{fromdate} = "$form->{year}1201";
        $form->{todate}   = "$form->{year}1231";
        $form->{"0412"}   = "X";
        last SWITCH;
      };
    }

  # Kontrollvariablen für die Templates
  $form->{"year$_"} = ($form->{year} >= $_ ) ? "1":"0" for 2007..2107;

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
    $temp =~ s/\\n/<br \/>/;
    ($form->{co_street}, $form->{co_city}) = split("<br \/>", $temp);
    $form->{co_city} =~ s/\\n//g;
  }

  ################################
  #
  # Nation specific customisations
  #
  ################################

  # Germany

  if ( $form->{coa} eq 'Germany-DATEV-SKR03EU' or $form->{coa} eq 'Germany-DATEV-SKR04EU') {

    #
    # Outputformat specific customisation's
    #

    my @category_cent = $ustva->report_variables({
        myconfig    => \%myconfig,
        form        => $form,
        type        => '',
        attribute   => 'position',
        dec_places  => '2',
    });

    push @category_cent, qw(Z43  Z45  Z53  Z62  Z65  Z67);

    my @category_euro = $ustva->report_variables({
        myconfig    => \%myconfig,
        form        => $form,
        type        => '',
        attribute   => 'position',
        dec_places  => '0',
    });

    $form->{id} = [];
    $form->{amount} = [];

    if ( $form->{format} eq 'pdf' or $form->{format} eq 'postscript') {

      $form->{IN} = "$form->{type}-$form->{year}.tex";
      $form->{padding} = "~~";
      $form->{bold}    = "\textbf{";
      $form->{endbold} = "}";
      $form->{br}      = '\\\\';

      # Zahlenformatierung für Latex USTVA Formulare

      foreach my $number (@category_euro) {
        $form->{$number} = $form->format_amount(\%myconfig, $form->{$number}, '0', '');
      }

      my ${decimal_comma} = ( $myconfig{numberformat} eq '1.000,00'
           or $myconfig{numberformat} eq '1000,00' ) ? ',':'.';

      foreach my $number (@category_cent) {
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

      foreach my $number (@category_cent) {
        $form->{$number} = $form->format_amount(\%myconfig, $form->{$number}, '2', '0');
      }

      foreach my $number (@category_euro) {
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

    my @category_cent = $ustva->report_variables({
        myconfig    => \%myconfig,
        form        => $form,
        type        => '',
        attribute   => 'position',
        dec_places  => '2',
    });

    my @category_euro = $ustva->report_variables({
        myconfig    => \%myconfig,
        form        => $form,
        type        => '',
        attribute   => 'position',
        dec_places  => '0',
    });

    $form->{USTVA} = [];

    if ( $form->{format} eq 'generic') { # Formatierungen für HTML Ausgabe

      my $rec_ref = {};
      for my $kennziffer (@category_cent, @category_euro) {
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

  $::form->header;

  my $ustva = USTVA->new();
  $ustva->get_config($::lx_office_conf{paths}{userspath}, 'finanzamt.ini');

  my $land = $::form->{elsterland};
  my $amt  = $::form->{elsterFFFF};


  $::form->{title} = $::locale->text('Tax Office Preferences');


  my $select_tax_office               = $ustva->fa_auswahl($land, $amt, $ustva->query_finanzamt(\%::myconfig, $::form));
  my $checked_accrual                 = $::form->{method}        eq 'accrual' ? q|checked="checked"| : '';
  my $checked_cash                    = $::form->{method}        eq 'cash'    ? q|checked="checked"| : '';
  my $checked_monthly                 = $::form->{FA_voranmeld}  eq 'month'   ? "checked"            : '';
  my $checked_quarterly               = $::form->{FA_voranmeld}  eq 'quarter' ? "checked"            : '';
  my $checked_dauerfristverlaengerung = $::form->{FA_dauerfrist} eq '1'       ? "checked"            : '';
  my $checked_kz_71                   = $::form->{FA_71}         eq 'X'       ? "checked"            : '';

  my $_hidden_variables_ref;

  my %_hidden_local_variables = (
    'saved'       => $::locale->text('Check Details'),
    'nextsub'     => 'config_step2',
    'warnung'     => '0',
  );

  foreach my $variable (keys %_hidden_local_variables) {
    push @{ $_hidden_variables_ref },
        { 'variable' => $variable, 'value' => $_hidden_local_variables{$variable} };
  }

  my @_hidden_form_variables = qw(
    FA_Name             FA_Strasse        FA_PLZ
    FA_Ort              FA_Telefon        FA_Fax
    FA_PLZ_Grosskunden  FA_PLZ_Postfach   FA_Postfach
    FA_BLZ_1            FA_Kontonummer_1  FA_Bankbezeichnung_1
    FA_BLZ_2            FA_Kontonummer_2  FA_Bankbezeichnung_oertlich
    FA_Oeffnungszeiten  FA_Email          FA_Internet
    steuernummer        elsterland        elstersteuernummer
    elsterFFFF
  );

  foreach my $variable (@_hidden_form_variables) {
    push @{ $_hidden_variables_ref},
        { 'variable' => $variable, 'value' => $::form->{$variable} };
  }

# Which COA is in use?

  $ustva->get_coa($::form); # fetches coa and modifies some form variables

  # hä? kann die weg?
  my $steuernummer_new = '';

  # Variablen für das Template zur Verfügung stellen
  my $template_ref = {
     select_tax_office               => $select_tax_office,
     checked_accrual                 => $checked_accrual,
     checked_cash                    => $checked_cash,
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

  $form->header();

  my $elsterland         = '';
  my $elster_amt         = '';
  my $elsterFFFF         = '';
  my $elstersteuernummer = '';

  my $ustva = USTVA->new();
  $ustva->get_config($::lx_office_conf{paths}{userspath}, 'finanzamt.ini')
    if ($form->{saved} eq $locale->text('saved'));

  # Auf Übergabefehler checken
  USTVA::info(  $locale->text('Missing Tax Authoritys Preferences') . "\n"
              . $locale->text('USTVA-Hint: Tax Authoritys'))
    if (   $form->{elsterFFFF_new} eq 'Auswahl'
        || $form->{elsterland_new} eq 'Auswahl');
  USTVA::info(  $locale->text('Missing Method!') . "\n"
              . $locale->text('USTVA-Hint: Method'))
    if ($form->{method} eq '');

  # Klären, ob Variablen bereits befüllt sind UND ob veräderungen auf
  # der vorherigen Maske stattfanden: $change = 1(in der edit sub,
  # mittels get_config)

  my $change = $form->{elsterland} eq $form->{elsterland_new}
    && $form->{elsterFFFF} eq $form->{elsterFFFF_new} ? '0' : '1';
  $change = '0' if ($form->{saved} eq $locale->text('saved'));
  my $elster_init = $ustva->query_finanzamt(\%myconfig, $form);

  my %elster_init = %$elster_init;

  if ($change eq '1') {

    # Daten ändern
    $elsterland           = $form->{elsterland_new};
    $elsterFFFF           = $form->{elsterFFFF_new};
    $form->{elsterland}   = $elsterland;
    $form->{elsterFFFF}   = $elsterFFFF;
    $form->{steuernummer} = '';

    create_steuernummer();

    # rebuild elster_amt
    my $amt = $elster_init{$elsterFFFF};

    # load the predefined hash data into the FA_* Vars
    my @variables = qw(FA_Name FA_Strasse FA_PLZ FA_Ort
      FA_Telefon FA_Fax FA_PLZ_Grosskunden FA_PLZ_Postfach
      FA_Postfach
      FA_BLZ_1 FA_Kontonummer_1 FA_Bankbezeichnung_1
      FA_BLZ_2 FA_Kontonummer_2 FA_Bankbezeichnung_oertlich
      FA_Oeffnungszeiten FA_Email FA_Internet);

    for (my $i = 0; $i <= 20; $i++) {
      $form->{ $variables[$i] } =
        $elster_init->{$elsterland}->{$elsterFFFF}->[$i];
    }

  } else {

    $elsterland = $form->{elsterland};
    $elsterFFFF = $form->{elsterFFFF};

  }
  my $stnr = $form->{steuernummer};
  $stnr =~ s/\D+//g;
  my $patterncount   = $form->{patterncount};
  my $elster_pattern = $form->{elster_pattern};
  my $delimiter      = $form->{delimiter};
  my $steuernummer   = $stnr eq '' ? $form->{steuernummer} : '';

  $form->{FA_Oeffnungszeiten} =~ s/\\\\n/\n/g;


  $ustva->get_coa($form); # fetches coa and modifies some form variables

  my $input_steuernummer = $ustva->steuernummer_input(
                             $form->{elsterland},
                             $form->{elsterFFFF},
                             $form->{steuernummer}
  );

  $::lxdebug->message(LXDebug->DEBUG1, qq|$input_steuernummer|);


  my $_hidden_variables_ref;

  my %_hidden_local_variables = (
      'elsterland'          => $elsterland,
      'elsterFFFF'          => $elsterFFFF,
      'warnung'             => 0,
      'elstersteuernummer'  => $elstersteuernummer,
      'steuernummer'        => $stnr,
      'lastsub'             => 'config_step1',
      'nextsub'             => 'save',

  );

  foreach my $variable (keys %_hidden_local_variables) {
    push @{ $_hidden_variables_ref },
        { 'variable' => $variable, 'value' => $_hidden_local_variables{$variable} };
  }

  my @_hidden_form_variables = qw(
    FA_steuerberater_name   FA_steuerberater_street
    FA_steuerberater_city   FA_steuerberater_tel
    FA_voranmeld            method
    FA_dauerfrist           FA_71
    elster
    type                    elster_init
    saved                   callback
  );

  foreach my $variable (@_hidden_form_variables) {
    push @{ $_hidden_variables_ref},
        { 'variable' => $variable, 'value' => $form->{$variable} };
  }

  my $template_ref = {
     input_steuernummer              => $input_steuernummer,
     readonly                        => '', #q|disabled="disabled"|,
     callback                        => $form->{callback},
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
  my $delimiter      = $::form->{delimiter};
  my $elster_pattern = $::form->{elster_pattern};

  # rebuild steuernummer and elstersteuernummer
  # es gibt eine gespeicherte steuernummer $form->{steuernummer}
  # und die parts und delimiter

  my $h = 0;
  my $i = 0;

  my $steuernummer_new       = $part;
  my $elstersteuernummer_new = $::form->{elster_FFFF};
  $elstersteuernummer_new .= '0';

  for ($h = 1; $h < $patterncount; $h++) {
    $steuernummer_new .= qq|$delimiter|;
    for (my $i = 1; $i <= length($elster_pattern); $i++) {
      $steuernummer_new       .= $::form->{"part_$h\_$i"};
      $elstersteuernummer_new .= $::form->{"part_$h\_$i"};
    }
  }
  if ($::form->{steuernummer} ne $steuernummer_new) {
    $::form->{steuernummer}       = $steuernummer_new;
    $::form->{elstersteuernummer} = $elstersteuernummer_new;
    $::form->{steuernummer_new}   = $steuernummer_new;
  } else {
    $::form->{steuernummer_new}       = '';
    $::form->{elstersteuernummer_new} = '';
  }
  $::lxdebug->leave_sub();
}

sub save {
  $::lxdebug->enter_sub();

  $::auth->assert('advance_turnover_tax_return');

  my $filename = "$::myconfig{login}_$::form->{filename}";
  $filename =~ s|.*/||;

  #zuerst die steuernummer aus den part, parts_X_Y und delimiter herstellen
  create_steuernummer();

  # Textboxen formatieren: Linebreaks entfernen
  #
  $::form->{FA_Oeffnungszeiten} =~ s/\r\n/\\n/g;

  #URL mit http:// davor?
  $::form->{FA_Internet} =~ s/^http:\/\///;
  $::form->{FA_Internet} = 'http://' . $::form->{FA_Internet};

  my @config = qw(
    elster              elsterland            elstersteuernummer  steuernummer
    elsteramt           elsterFFFF            FA_Name             FA_Strasse
    FA_PLZ              FA_Ort                FA_Telefon          FA_Fax
    FA_PLZ_Grosskunden  FA_PLZ_Postfach       FA_Postfach         FA_BLZ_1
    FA_Kontonummer_1    FA_Bankbezeichnung_1  FA_BLZ_2            FA_Kontonummer_2
    FA_Bankbezeichnung_oertlich FA_Oeffnungszeiten
    FA_Email FA_Internet FA_voranmeld method FA_steuerberater_name
    FA_steuerberater_street FA_steuerberater_city FA_steuerberater_tel
    FA_71 FA_dauerfrist);

  # Hier kommt dann die Plausibilitätsprüfung der ELSTERSteuernummer
  if ($::form->{elstersteuernummer} ne '000000000') {

    $::form->{elster} = '1';

    open my $ustvaconfig, ">", "$::lx_office_conf{paths}{userspath}/$filename" or $::form->error("$filename : $!");

    # create the config file
    print {$ustvaconfig} qq|# Configuration file for USTVA\n\n|;
    my $key = '';
    foreach $key (sort @config) {
      $::form->{$key} =~ s/\\/\\\\/g;
      # strip M
      $::form->{$key} =~ s/\r\n/\n/g;

      print {$ustvaconfig} qq|$key=|;
      if ($::form->{$key} ne 'Y') {
        print {$ustvaconfig} qq|$::form->{$key}\n|;
      }
      if ($::form->{$key} eq 'Y') {
        print {$ustvaconfig} qq|checked \n|;
      }
    }
    print {$ustvaconfig} qq|\n\n|;
    close $ustvaconfig;
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
