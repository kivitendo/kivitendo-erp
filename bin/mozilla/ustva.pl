#!/bin/perl
#=====================================================================
# Lx-Office ERP
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
#======================================================================

require "$form->{path}/arap.pl";

#use strict;
#no strict 'refs';
#use diagnostics;
#use warnings; # FATAL=> 'all';
#use vars qw($locale $form %myconfig);
#our ($myconfig);
#use CGI::Carp "fatalsToBrowser";

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
  $lxdebug->enter_sub();
  my $myconfig = \%myconfig;
  use CGI;

  $form->{title} = $locale->text('UStVA');
  $form->{kz10}  = '';                       #Berichtigte Anmeldung? Ja =1 Nein=0

  my $year = substr(
                    $form->datetonum($form->current_date(\%myconfig),
                                     \%myconfig
                    ),
                    0, 4);

  my $department = '';
  local $hide = '';
  $form->header;

  print qq|
<body>
<form method=post action=$form->{script}>

<input type=hidden name=title value="$form->{title}">

<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr height="5"></tr>
  <tr>
    <td>
      <table>
      $department
|;

  # Hier Aufruf von get_config aus bin/mozilla/fa.pl zum
  # Einlesen der Finanzamtdaten
  &get_config($userspath, 'finanzamt.ini');

  # Hier Einlesen der user-config
  # steuernummer entfernt für prerelease
  my @a = qw(signature name company address businessnumber tel fax email
    co_chief co_department co_custom1 co_custom2 co_custom3 co_custom4 co_custom5
    co_name1 co_name2
    co_street co_street1 co_zip co_city co_city1 co_country co_tel co_tel1 co_tel2
    co_fax co_fax1 co_email co_email1 co_url co_url1 ustid duns
    co_bankname co_bankname1 co_bankname2 co_bankname3 co_blz co_blz1
    co_blz2 co_blz3 co_accountnr co_accountnr1 co_accountnr2 co_accountnr3);

  map { $form->{$_} = $myconfig->{$_} } @a;

  my $oeffnungszeiten = $form->{FA_Oeffnungszeiten};
  $oeffnungszeiten =~ s/\\\\n/<br>/g;
  print qq|
	<tr >
	  <td width="50%" align="left" valign="top">
	  <fieldset>
	  <legend>
	  <b>| . $locale->text('Firma') . qq|</b>
	  </legend>
  |;
  if ($form->{company} ne '') {
    print qq|<h3>$form->{company}</h3>\n|;
  } else {
    print qq|
	    <a href=am.pl?path=$form->{path}&action=config&level=Programm--Preferences&login=$form->{login}&password=$form->{password}>
	    | . $locale->text('Kein Firmenname hinterlegt!') . qq|</a><br>
    |;
  }

  # Anpassungen der Variablennamen auf pre 2.1.1 Namen
  # klären, ob $form->{company_street|_address} gesetzt sind
  #

  if ($form->{address} ne '') {
    my $temp = $form->{address};
    $temp =~ s/\\n/<br \/>/;
    ($form->{co_street}, $form->{co_city}) = split("<br \/>", $temp);
    $form->{co_city} =~ s/\\n//g;
  }

  if ($form->{co_street} ne ''
      and (   $form->{co_zip} ne ''
           or $form->{co_city} ne '')
    ) {
    print qq|
    $form->{co_street}<br>
    $form->{co_street1}<br>
    $form->{co_zip} $form->{co_city}|;
    } else {
    print qq|
	  <a href=am.pl?path=$form->{path}&action=config&level=Programm--Preferences&login=$form->{login}&password=$form->{password}>
	  | . $locale->text('Keine Firmenadresse hinterlegt!') . qq|</a>\n|;
  }
  $form->{co_email} = $form->{email} unless $form->{co_email};
  $form->{co_tel}   = $form->{tel}   unless $form->{co_tel};
  $form->{co_fax}   = $form->{fax}   unless $form->{co_fax};
  $form->{co_url}   = $form->{urlx}  unless $form->{co_url};

  print qq|
	  <br>
	  <br>
	  | . $locale->text('Tel.: ') . qq|
	  $form->{co_tel}
	  <br>
	  | . $locale->text('Fax.: ') . qq|
	  $form->{co_fax}	  
	  <br>
	  <br>
	  $form->{co_email}	  
	  <br>
	  <br>
	  | . $locale->text('Steuernummer: ') . qq|
  |;

  if ($form->{steuernummer} ne '') {
    print qq|$form->{steuernummer}|;
  } else {
    print qq|
	  <a href="ustva.pl?path=$form->{path}&action=edit&level=Programm--Finanzamteinstellungen&login=$form->{login}&password=$form->{password}">
	  Keine Steuernummer hinterlegt!</a><br>|;
  }
  print qq|
	  <br>
	  | . $locale->text('ELSTER-Steuernummer: ') . qq|
	  $form->{elstersteuernummer}
          <br>
          <br>

	  </fieldset>
	  <br>
  |;
  if ($form->{FA_steuerberater_name} ne '') {
    print qq|
	  <fieldset>
	  <legend>
            <input checked="checked" title="|
      . $locale->text('Beraterdaten in UStVA übernehmen?')
      . qq|" name="FA_steuerberater" id=steuerberater class=checkbox type=checkbox value="1">&nbsp;
            <b>| . $locale->text('Steuerberater/-in') . qq|</b>
            </legend>
            
            $form->{FA_steuerberater_name}<br>
            $form->{FA_steuerberater_street}<br>
            $form->{FA_steuerberater_city}<br>
            Tel: $form->{FA_steuerberater_tel}<br>
	  </fieldset>
	  <br>
    |;
  }
  print qq|
	  <fieldset>
	  <legend>
          <b>| . $locale->text('Voranmeldezeitraum') . qq|</b>
	  </legend>
  |;
  &ustva_vorauswahl();

  my @years = ();
  if (not defined $form->{all_years}) {

    # accounting years if SQL-Ledger Version < 2.4.1
    #    $year = $form->{year} * 1;
    @years = sort { $b <=> $a } (2003 .. ($year + 1));
    $form->{all_years} = \@years;
  }
  map { $form->{selectaccountingyear} .= qq|<option>$_\n| }
    @{ $form->{all_years} };
  print qq|
          <select name=year title="| . $locale->text('Year') . qq|">
  |;
  my $key = '';
  foreach $key (@years) {
    print qq|<option |;
    print qq|selected| if ($key eq $form->{year});
    print qq| >$key</option>
    |;
  }

  my $voranmeld = $form->{FA_voranmeld};
  print qq|             </select>|;
  my $checked = '';
  $checked = "checked" if ($form->{kz10} eq '1');
  print qq|
           <input name="FA_10" id=FA_10 class=checkbox type=checkbox value="1" $checked title = "|
    . $locale->text(
      'Ist dies eine berichtigte Anmeldung? (Nr. 10/Zeile 15 Steuererklärung)')
    . qq|">
            | . $locale->text('Berichtigte Anmeldung') . qq|
          <br>
  |;

  if ($voranmeld ne '') {
    print qq|
          <br>
          | . $locale->text($voranmeld) . qq|
  |;
    print qq| mit Dauerfristverlängerung| if ($form->{FA_dauerfrist} eq '1');
    print qq|

      <br>
  |;
  }
  if ($form->{method} ne '') {
    print qq|| . $locale->text('Method') . qq|: |;
    print qq|| . $locale->text('accrual') . qq||
      if ($form->{method} eq 'accrual');
    print qq|| . $locale->text('cash') . qq|| if ($form->{method} eq 'cash');
  }
  print qq|
	  </fieldset>

    </td>|;

  if ($form->{FA_Name} ne '') {
    print qq|
    <td width="50%" valign="top">	  
	  <fieldset>
	  <legend>
	  <b>| . $locale->text('Finanzamt') . qq|</b>
	  </legend>
          <h3>$form->{FA_Name}</h2>
    |;

    #if ($form->{FA_Ergaenzung_Name ne ''}){
    #  print qq|
    #          $form->{FA_Ergaenzung_Name}&nbsp
    #          <br>
    #  |;
    #}
    print qq|
          $form->{FA_Strasse}
          <br>
          $form->{FA_PLZ}&nbsp; &nbsp;$form->{FA_Ort}
          <br>
          <br>
          | . $locale->text('Tel. : ') . qq|
          $form->{FA_Telefon}
          <br> 
          | . $locale->text('Fax. : ') . qq|
          $form->{FA_Fax}
          <br>
          <br>
          <a href="mailto:$form->{FA_Email}?subject=|
      . CGI::escape("Steuer Nr: $form->{steuernummer}:")
      . qq|&amp;body=|
      . CGI::escape(
             "Sehr geehrte Damen und Herren,\n\n\nMit freundlichen Grüßen\n\n")
      . CGI::escape($form->{signature}) . qq|">
            $form->{FA_Email}
          </a>
          <br>
          <a href="$form->{FA_Internet}">
            $form->{FA_Internet}
          </a>
          <br>
          <br>
          | . $locale->text('Öffnungszeiten') . qq|
          <br>
          $oeffnungszeiten
          <br>
   |;

    my $FA_1 =
      (   $form->{FA_BLZ_1} ne ''
       && $form->{FA_Kontonummer_1}     ne ''
       && $form->{FA_Bankbezeichnung_1} ne '');
    my $FA_2 =
      (   $form->{FA_BLZ_2} ne ''
       && $form->{FA_Kontonummer_2}            ne ''
       && $form->{FA_Bankbezeichnung_oertlich} ne '');

    if ($FA_1 && $FA_2) {
      print qq|
          <br>
          | . $locale->text('Bankverbindungen') . qq|
          <table>
          <tr>
          <td>
          $form->{FA_Bankbezeichnung_1}
          <br>                  
          | . $locale->text('Konto: ') . qq|
          $form->{FA_Kontonummer_1}
          <br>
          | . $locale->text('BLZ: ') . qq|
          $form->{FA_BLZ_1}
          </td>
          <td>
          $form->{FA_Bankbezeichnung_oertlich}
          <br>
          | . $locale->text('Konto: ') . qq|
          $form->{FA_Kontonummer_2}
          <br> 
          | . $locale->text('BLZ: ') . qq|
          $form->{FA_BLZ_2}
          </td>
          </tr>
          </table>
          <br>|;
    } elsif ($FA_1) {
      print qq|
          <br>
          | . $locale->text('Bankverbindung') . qq|
          <br>
          <br>
          $form->{FA_Bankbezeichnung_1}
          <br>                  
          | . $locale->text('Konto: ') . qq|
          $form->{FA_Kontonummer_1}
          <br> 
          | . $locale->text('BLZ: ') . qq|
          $form->{FA_BLZ_1}          <br>
          <br>|;
    } elsif ($FA_2) {
      print qq|
          <br>
          | . $locale->text('Bankverbindung') . qq|
          <br>
          <br>
          $form->{FA_Bankbezeichnung_oertlich}
          <br>                  
          | . $locale->text('Konto: ') . qq|
          $form->{FA_Kontonummer_2}
          <br> 
          | . $locale->text('BLZ: ') . qq|
          $form->{FA_BLZ_2}
     |;
    }
    print qq|

      </fieldset>
      <br>
      <fieldset>
      <legend>
      <b>| . $locale->text('Ausgabeformat') . qq|</b>
      </legend>
  |;

    &show_options;
    my $ausgabe = '1';
    print qq|
	  </fieldset>
      |;

  } else {
    print qq|
     <td width="50%" valign="bottom">
     <fieldset>
     <legend>
     <b>| . $locale->text('Hinweise') . qq|</b>
     </legend>
      <h2 class="confirm">|
      . $locale->text('Missing Preferences: Outputroutine disabled')
      . qq|</h2>
      <h3>| . $locale->text('Help:') . qq|</h3>
      <ul>
      <li>| . $locale->text('Hint-Missing-Preferences') . qq|</li>
      </ul>
      </fieldset>
     |;
    my $ausgabe = '';
    $hide = q|disabled="disabled"|;
  }

  print qq|
      </td>
    </tr>
  |;

  #}# end if report = ustva

  print qq|
      </table>
     </td>
    </tr>
    <tr>
     <td><hr size="3" noshade></td>
    </tr>
  </table>

  <br>
  <input type="hidden" name="address" value="$form->{address}">
  <input type="hidden" name="reporttype" value="custom">
  <input type="hidden" name="co_street" value="$form->{co_street}">
  <input type="hidden" name="co_city" value="$form->{co_city}">
  <input type="hidden" name="path" value="$form->{path}">
  <input type="hidden" name="login" value="$form->{login}">
  <input type="hidden" name="password" value="$form->{password}">
  <table width="100%">
  <tr>
   <td align="left">
     <input type=hidden name=nextsub value=generate_ustva>
     <input $hide type=submit class=submit name=action value="|
    . $locale->text('Show') . qq|">
   </td>
   <td align="right">

    <!--</form>
    <form action="doc/ustva.html" method="get">
    -->
       <input type=submit class=submit name=action value="|
    . $locale->text('Help') . qq|">
   <!-- </form>-->
   </td>
  </tr>
  </table>
  |;

  print qq|

  </body>
  </html>
  |;
  $lxdebug->leave_sub();
}

#############################

sub help {
  $lxdebug->enter_sub();

  # parse help documents under doc
  my $tmp = $form->{templates};
  $form->{templates} = 'doc';
  $form->{help}      = 'ustva';
  $form->{type}      = 'help';
  $form->{format}    = 'html';
  &generate_ustva();

  #$form->{templates} = $tmp;
  $lxdebug->leave_sub();
}

sub show {
  $lxdebug->enter_sub();

  #&generate_ustva();
  no strict 'refs';
  $lxdebug->leave_sub();
  &{ $form->{nextsub} };
  use strict 'refs';
}

sub ustva_vorauswahl {
  $lxdebug->enter_sub();

  #Aktuelles Datum zerlegen:
  my $date = $form->datetonum($form->current_date(\%myconfig), \%myconfig);

  #$locale->date($myconfig, $form->current_date($myconfig), 0)=~ /(\d\d).(\d\d).(\d\d\d\d)/;
  $form->{day}   = substr($date, 6, 2);
  $form->{month} = substr($date, 4, 2);
  $form->{year}  = substr($date, 0, 4);
  $lxdebug->message(LXDebug::DEBUG1, qq|
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
  print qq|
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
    print qq|<select id="zeitraum" name="period" title="|
  . $locale->text('Select a period') . qq|" >|;

    my $key = '';
    foreach $key (sort keys %liste) {
      my $selected = '';
      $selected = 'selected' if ($sel eq $key);
      print qq|
         <option value="$key" $selected> $liste{$key}</option>
   |;
    }
    print qq|</select>|;

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
        $sel = 'D';
        last SWITCH;
      };
      $yymmdd <= ($yy + 410 + $dfv) && do {
        $sel = 'A';
        last SWITCH;
      };
      $yymmdd <= ($yy + 710 + $dfv) && do {
        $sel = 'B';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1010 + $dfv) && do {
        $sel = 'C';
        last SWITCH;
      };
      $yymmdd <= ($yy + 1231) && do {
        $sel = 'D';
      };
    }

    print qq|<select id="zeitraum" name="period" title="|
      . $locale->text('Select a period') . qq|" >|;
    my $key = '';
    foreach $key (sort keys %liste) {
      my $selected = '';
      $selected = 'selected' if ($sel eq $key);
      print qq|
         <option value="$key" $selected>$liste{$key}</option>
     |;
    }
    print qq|\n</select>
   |;

  } else {

    # keine Vorauswahl bei Voranmeldungszeitraum
    print qq|<select id="zeitraum" name="period" title="|
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
      print qq|
         <option value="$key">|
        . $locale->text("$listea{$key}")
        . qq|</option>\n|;
    }

    foreach $key (sort keys %listeb) {
      print qq|
         <option value="$key">|
        . $locale->text("$listeb{$key}")
        . qq|</option>\n|;
    }
    print qq|</select>|;
  }
  $lxdebug->leave_sub();
}

sub config {
  $lxdebug->enter_sub();
  edit();
  $lxdebug->leave_sub();
}

sub debug {
  $lxdebug->enter_sub();
  $form->debug();
  $lxdebug->leave_sub();
}

sub show_options {
  $lxdebug->enter_sub();

  #  $form->{PD}{$form->{type}} = "selected";
  #  $form->{DF}{$form->{format}} = "selected";
  #  $form->{OP}{$form->{media}} = "selected";
  #  $form->{SM}{$form->{sendmode}} = "selected";
  my $type   = qq|      <input type=hidden name="type" value="ustva">|;
  my $media  = qq|      <input type=hidden name="media" value="screen">|;
  my $format =
      qq|       <option value=html selected>|
    . $locale->text('Vorschau')
    . qq|</option>|;
  if ($latex_templates) {
    $format .=
        qq|    <option value=pdf>|
      . $locale->text('UStVA als PDF-Dokument')
      . qq|</option>|;
  }

  #my $disabled= qq|disabled="disabled"|;
  #$disabled='' if ($form->{elster} eq '1' );
  if ($form->{elster} eq '1') {
    $format .=
        qq|<option value=elsterwinston>|
      . $locale->text('ELSTER Export nach Winston')
      . qq|</option>|
      . qq|<option value=elstertaxbird>|
      . $locale->text('ELSTER Export nach Taxbird')
      . qq|</option>|;      
  }

  #$format .= qq|<option value=elster>|.$locale->text('ELSTER Export nach Winston').qq|</option>|;
  print qq|
    $type
    $media
    <select name=format title = "|
    . $locale->text('Ausgabeformat auswählen...') . qq|">$format</select>
  |;
  $lxdebug->leave_sub();
}

sub generate_ustva {
  $lxdebug->enter_sub();

  # Aufruf von get_config aus bin/mozilla/ustva.pl zum
  # Einlesen der Finanzamtdaten aus finanzamt.ini

  get_config($userspath, 'finanzamt.ini');

  # form vars initialisieren
  my @anmeldungszeitraum =
    qw('0401' '0402' '0403' '0404' '0405' '0405' '0406' '0407' '0408' '0409' '0410' '0411' '0412' '0441' '0442' '0443' '0444');
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
      $lxdebug->message(LXDebug::DEBUG1,
                        qq|Actual year from Database: $form->{year}\n|);
    }

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

  # using dates in ISO-8601 format: yyyymmmdd  for Postgres...
  USTVA->ustva(\%myconfig, \%$form);

  # reformat Dates to dateformat
  $form->{fromdate} = $locale->date(\%myconfig, $form->{fromdate}, 0, 0, 0);

  $form->{todate} = $form->current_date($myconfig) unless $form->{todate};
  $form->{todate} = $locale->date(\%myconfig, $form->{todate}, 0, 0, 0);

  $form->{longperiod} =
    $locale->date(\%myconfig, $form->current_date(\%myconfig), 1, 0, 0);

  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {

    $form->{todate} = $form->current_date($myconfig)  unless ($form->{todate});

    my $longtodate  = $locale->date($myconfig, $form->{todate}, 1, 0, 0);
    my $shorttodate = $locale->date($myconfig, $form->{todate}, 0, 0, 0);

    my $longfromdate  = $locale->date($myconfig, $form->{fromdate}, 1, 0, 0);
    my $shortfromdate = $locale->date($myconfig, $form->{fromdate}, 0, 0, 0);

    $form->{this_period} = "$shortfromdate<br>\n$shorttodate";
    $form->{longperiod}      =
        $locale->text('for Period')
      . qq|<br>\n$longfromdate |
      . $locale->text('bis')
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
      . $locale->text('bis')
      . qq| $longcomparetodate|;
  }

  $form->{Datum_heute} =
    $locale->date(\%myconfig, $form->current_date(\%myconfig), 0, 0, 0);

  # setup variables for the form
  # steuernummer für prerelease entfernt
  my @a = qw(company businessnumber tel fax email
    co_chief co_department co_custom1 co_custom2 co_custom3 co_custom4 co_custom5
    co_name1 co_name2  co_street co_street1 co_zip co_city co_city1 co_country co_tel co_tel1 co_tel2
    co_fax co_fax1 co_email co_email1 co_url co_url1 ustid duns
    co_bankname co_bankname1 co_bankname2 co_bankname3 co_blz co_blz1
    co_blz2 co_blz3 co_accountnr co_accountnr1 co_accountnr2 co_accountnr3);

  map { $form->{$_} = $myconfig{$_} } @a;

  if ($form->{address} ne '') {
    my $temp = $form->{address};
    $temp =~ s/\\n/<br \/>/;
    ($form->{co_street}, $form->{co_city}) = split("<br \/>", $temp);
    $form->{co_city} =~ s/\\n//g;
  }

  if ( $form->{format} eq 'pdf' or $form->{format} eq 'postscript') {

    $form->{IN} = "$form->{type}-$form->{year}.tex";

    $form->{padding} = "~~";
    $form->{bold}    = "\textbf{";
    $form->{endbold} = "}";
    $form->{br}      = '\\\\';

    my @numbers = qw(511 861 36 80 971 931 98 96 53 74
      85 65 66 61 62 Z67 63 64 59 69 39 83
      Z43 Z45 Z53 Z62 Z65);

    my $number = '';

    # Zahlenformatierung für Latex USTVA Formulare
    if (   $myconfig{numberformat} eq '1.000,00'
           or $myconfig{numberformat} eq '1000,00') {
      foreach $number (@numbers) {
        $form->{$number} =~ s/,/~~/g;
      }
    }
    if (   $myconfig{numberformat} eq '1000.00'
        or $myconfig{numberformat} eq '1,000.00') {
      foreach $number (@numbers) {
        $form->{$number} =~ s/\./~~/g;
      }
    }
    if ( $form->{period} eq '13'){ #Catch yearly USTE for now, not yet implemented.
      $form->header;
      USTVA::error(
        $locale->text(
        'Impossible to create yearly Tax Report as PDF or Postscript<br \> Not yet implemented!'
        )
      );
    }
      
  } elsif ( $form->{format} eq 'html') { # Formatierungen für HTML Ausgabe

    $form->{IN} = $form->{type} . '.html';
    $form->{padding} = "&nbsp;&nbsp;";
    $form->{bold}    = "<b>";
    $form->{endbold} = "</b>";
    $form->{br}      = "<br>";
    $form->{address} =~ s/\\n/\n/g;

  } elsif ($form->{format} =~ /^elster/) {

    if ( $form->{period} eq '13' ) {
      $form->header;
      USTVA::info(
        $locale->text(
        'Impossible to create yearly Tax Report via Winston or Taxbird.<br \> Not yet implemented!'
      ));
    }

    if ( $form->{format} eq 'elsterwinston' ) {

      $form->{IN} = 'winston.xml';
     
      # Build Winston filename
      my $file = 'U';     # 1. char 'U' = USTVA
      $file .= $form->{period};
      #4. and 5. char = year modulo 100
      $file .= sprintf("%02d", $form->{year} % 100);
      #6. to 18. char = Elstersteuernummer
      #Beispiel: Steuernummer in Bayern
      #111/222/33334 ergibt für UStVA Jan 2004: U01049111022233334
      $file .= $form->{elsterFFFF};
      $file .= $form->{elstersteuernummer};
      #file suffix
      $file .= '.xml';
      $form->{tmpfile} = "$userspath/$file";
    }

    if ( $form->{format} eq 'elstertaxbird' ) {

      $form->{IN} = 'taxbird.txb';
     
      $form->{tmpfile} = "$userspath/USTVA-" . $form->{period} 
      . sprintf("%02d", $form->{year} % 100) . ".txb";

      if ($form->{period} =~ /^[4]\d$/ ){
        my %periods = ( # Lx => taxbird
                     '41' => '12',
                     '42' => '13',
                     '43' => '14',
                     '44' => '15',
                   );
      
        foreach my $quarter ( keys %periods ) {
          $form->{period} = $periods{$quarter} if ( $form->{period} eq $quarter);
        }
        
        my %lands = ( # Lx => taxbird # TODO: besser als array...
                    'Baden Würtemberg'       => '0',
                    'Bayern'                 => '1',
                    'Berlin'                 => '2',
                    'Brandenburg'            => '3',
                    'Bremen'                 => '4',
                    'Hamburg'                => '5',
                    'Hessen'                 => '6',
                    'Mecklenburg Vorpommern' => '7',
                    'Niedersachsen'          => '8',
                    'Nordrhein Westfalen'    => '9',
                    'Rheinland Pfalz'        => '10',
                    'Saarland'               => '11',
                    'Sachsen'                => '12',
                    'Sachsen Anhalt'         => '13',
                    'Schleswig Holstein'     => '14',
                    'Thüringen'              => '15',
              );


        foreach my $land ( keys %lands ){
          $form->{elsterland} = $lands{$land} if ($form->{elsterland} eq $land );
        }
      } elsif ($form->{period} =~ /^\d+$/ ) {
        $form->{period} =~ s/^0//g;
        my $period = $form->{period};
        $period * 1;
        $period--;
        $form->{period} = $period;
       } else {
         $form->header;
         USTVA::error( $locale->text('Wrong Period' ));
         exit(0);
                
       }
      
    }
    # Other Elster formats follow here...
    
  } elsif ( $form->{format} eq '' ){ # No format error.
    $form->header;
    USTVA::error( $locale->text('Application Error. No Format given!' ));
    exit(0);
 
  } else { # All other Formats are wrong
    $form->header;
    USTVA::error( $locale->text('Application Error. Wrong Format: ') . $form->{format} );
    exit(0);
  }
    
  
  $form->{templates} = $myconfig{templates};
  $form->{templates} = "doc" if ( $form->{type} eq 'help' );

  $form->parse_template($myconfig, $userspath);

  $lxdebug->leave_sub();
}

sub edit {
  $lxdebug->enter_sub();

  # edit all taxauthority prefs

  $form->header;
  &get_config($userspath, 'finanzamt.ini');

  #&create_steuernummer;

  my $land = $form->{elsterland};
  my $amt  = $form->{elsterFFFF};

  my $callback = '';
  $callback =
    "$form->{cbscript}?action=edit&login=$form->{cblogin}&path=$form->{cbpath}&root=$form->{cbroot}&rpw=$form->{cbrpw}"
    if ($form->{cbscript} ne '' and $form->{cblogin} ne '');

  $form->{title} = $locale->text('Finanzamt - Einstellungen');
  print qq|
    <body>
    <form name="verzeichnis" method=post action="$form->{script}">
     <table width=100%>
	<tr>
	  <th class="listtop">|
    . $locale->text('Finanzamt - Einstellungen') . qq|</th>
	</tr>
        <tr>
         <td>
           <br>
           <fieldset>
           <legend><b>|
    . $locale->text('Angaben zum Finanzamt') . qq|</b></legend>
  |;

  #print qq|$form->{terminal}|;

  USTVA::fa_auswahl($land, $amt, &elster_hash());
  print qq|
           </fieldset>
           <br>
  |;
  my $checked = '';
  $checked = "checked" if ($form->{method} eq 'accrual');
  print qq|
           <fieldset>
           <legend><b>| . $locale->text('Verfahren') . qq|</b>
           </legend>
           <input name=method id=accrual class=radio type=radio value="accrual" $checked>
           <label for="accrual">| . $locale->text('accrual') . qq|</label>
           <br>
  |;
  $checked = '';
  $checked = "checked" if ($form->{method} eq 'cash');
  print qq|
           <input name=method id=cash class=radio type=radio value="cash" $checked>
           <label for="cash">| . $locale->text('cash') . qq|</label>
           </fieldset>
           <br>
           <fieldset>
           <legend><b>| . $locale->text('Voranmeldungszeitraum') . qq|</b>
           </legend>
  |;
  $checked = '';
  $checked = "checked" if ($form->{FA_voranmeld} eq 'month');
  print qq|
           <input name=FA_voranmeld id=month class=radio type=radio value="month" $checked>
           <label for="month">| . $locale->text('month') . qq|</label>
           <br>
  |;
  $checked = '';
  $checked = "checked" if ($form->{FA_voranmeld} eq 'quarter');
  print qq|
           <input name="FA_voranmeld" id=quarter class=radio type=radio value="quarter" $checked>
           <label for="quarter">| . $locale->text('quarter') . qq|</label>
           <br>
  |;
  $checked = '';
  $checked = "checked" if ($form->{FA_dauerfrist} eq '1');
  print qq|
           <input name="FA_dauerfrist" id=FA_dauerfrist class=checkbox type=checkbox value="1" $checked>
           <label for="">|
    . $locale->text('Dauerfristverlängerung') . qq|</label>
           
           </fieldset>
           <br>
           <fieldset>
           <legend><b>| . $locale->text('Steuerberater/-in') . qq|</b>
           </legend>
  |;
  $checked = '';
  $checked = "checked" if ($form->{FA_71} eq 'X');
  print qq|
          <!-- <input name="FA_71" id=FA_71 class=checkbox type=checkbox value="X" $checked>
           <label for="FA_71">|
    . $locale->text('Verrechnung des Erstattungsbetrages erwünscht (Zeile 71)')
    . qq|</label>
           <br>
           <br>-->
           <table>
           <tr>
           <td>
           | . $locale->text('Name') . qq|
           </td>
           <td>
           | . $locale->text('Straße') . qq|
           </td>
           <td>
           | . $locale->text('PLZ, Ort') . qq|
           </td>
           <td>
           | . $locale->text('Telefon') . qq|
           </td>
           </tr>
           <tr>
           <td>
           <input name="FA_steuerberater_name" id=steuerberater size=25 value="$form->{FA_steuerberater_name}">
           </td>
           <td>
           <input name="FA_steuerberater_street" id=steuerberater size=25 value="$form->{FA_steuerberater_street}">
           </td>
           <td>
           <input name="FA_steuerberater_city" id=steuerberater size=25 value="$form->{FA_steuerberater_city}">
           </td>
           <td>
           <input name="FA_steuerberater_tel" id=steuerberater size=25 value="$form->{FA_steuerberater_tel}">
           </tr>
           </table>
           
           </fieldset>

           <br>
           <br>
           <hr>
           <!--<input type=submit class=submit name=action value="|
    . $locale->text('debug') . qq|">-->
           |;
  print qq|
           <input type="button" name="Verweis" value="|
    . $locale->text('Back to user config...') . qq|" 
            onClick="self.location.href='$callback'">| if ($callback ne '');
  print qq|
           &nbsp; &nbsp;
           <input type=submit class=submit name=action value="|
    . $locale->text('continue') . qq|">

         </td>
       </tr>
     </table>
  |;

  my @variables = qw( steuernummer elsterland elstersteuernummer elsterFFFF);
  my $variable  = '';
  foreach $variable (@variables) {
    print qq|	
          <input name=$variable type=hidden value="$form->{$variable}">|;
  }
  my $steuernummer_new = '';

  #<input type=hidden name="steuernummer_new" value="$form->{$steuernummer_new}">
  print qq|
          <input type=hidden name="callback" value="$callback">
          <input type=hidden name="nextsub" value="edit_form">
          <input type=hidden name="warnung" value="1">
          <input type=hidden name="saved" value="|
    . $locale->text('Bitte Angaben überprüfen') . qq|">
          <input type=hidden name="path" value=$form->{path}>
          <input type=hidden name="login" value=$form->{login}>
          <input type=hidden name="password" value=$form->{password}>
          <input type=hidden name="warnung" value="0">
  |;

  @variables = qw(FA_Name FA_Strasse FA_PLZ
    FA_Ort FA_Telefon FA_Fax FA_PLZ_Grosskunden FA_PLZ_Postfach FA_Postfach
    FA_BLZ_1 FA_Kontonummer_1 FA_Bankbezeichnung_1 FA_BLZ_2
    FA_Kontonummer_2 FA_Bankbezeichnung_oertlich FA_Oeffnungszeiten
    FA_Email FA_Internet);

  foreach $variable (@variables) {
    print qq|	
          <input name=$variable type=hidden value="$form->{$variable}">|;
  }

  print qq|
   </form>
   </body>
|;
  $lxdebug->leave_sub();
}

sub edit_form {
  $lxdebug->enter_sub();
  $form->header();
  print qq|
    <body>
  |;
  my $elsterland         = '';
  my $elster_amt         = '';
  my $elsterFFFF         = '';
  my $elstersteuernummer = '';
  &get_config($userspath, 'finanzamt.ini')
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
  my $elster_init = &elster_hash();

  #my %elster_init = ();
  my %elster_init = %$elster_init;

  if ($change eq '1') {

    # Daten ändern
    $elsterland           = $form->{elsterland_new};
    $elsterFFFF           = $form->{elsterFFFF_new};
    $form->{elsterland}   = $elsterland;
    $form->{elsterFFFF}   = $elsterFFFF;
    $form->{steuernummer} = '';
    &create_steuernummer;

    # rebuild elster_amt
    my $amt = '';
    foreach $amt (keys %{ $elster_init{ $form->{elsterland} } }) {
      $elster_amt = $amt
        if ($elster_init{ $form->{elsterland}{$amt} eq $form->{elsterFFFF} });
    }

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
  my $steuernummer   = '';
  $steuernummer = $form->{steuernummer} if ($steuernummer eq '');

  #Warnung
  my $warnung = $form->{warnung};

  #printout form
  print qq|
   <form name="elsterform" method=post action="$form->{script}">
   <table width="100%">
       <tr>
        <th colspan="2" class="listtop">|
    . $locale->text('Finanzamt - Einstellungen') . qq|</th>
       </tr>
       <tr>
         <td colspan=2>
         <br>
  |;
  &show_fa_daten;
  print qq|
         </td>
       </tr>
       <tr>
         <td colspan="2">
           <br>
           <fieldset>
           <legend>
           <font size="+1">| . $locale->text('Steuernummer') . qq|</font>
           </legend>
           <br>
  |;
  $steuernummer =
    USTVA::steuernummer_input($form->{elsterland}, $form->{elsterFFFF},
                              $form->{steuernummer});
  print qq|
           </H2><br>
           </fieldset>
           <br>
           <br>
           <hr>
         </td>
      </tr>
      <tr>
         <td align="left">

          <input type=hidden name=lastsub value="edit">
          |;
  print qq|<input type=submit class=submit name=action value="|
    . $locale->text('back') . qq|">|
    if ($form->{callback} eq '');

  print qq|
           <input type="button" name="Verweis" value="|
    . $locale->text('Back to user config...') . qq|" 
            onClick="self.location.href='$form->{callback}'">|
    if ($form->{callback} ne '');

  if ($form->{warnung} eq "1") {
    print qq|
          <input type=hidden name=nextsub value="edit_form">
          <input type=submit class=submit name=action value="|
      . $locale->text('continue') . qq|">
          <input type=hidden name="saved" value="|
      . $locale->text('Bitte alle Angaben überprüfen') . qq|">
    |;
  } else {
    print qq|
          <input type=hidden name="nextsub" value="save">
          <input type=hidden name="filename" value="finanzamt.ini">
          <input type=submit class=submit name=action value="|
      . $locale->text('save') . qq|">
         |;
  }

  print qq|
         </td>
         <td align="right">
           <H2 class=confirm>$form->{saved}</H2>
         </td>
      </tr>
  </table>
  |;

  my @variables = qw(FA_steuerberater_name FA_steuerberater_street
    FA_steuerberater_city FA_steuerberater_tel
    FA_voranmeld method
    FA_dauerfrist FA_71 elster
    path login password type elster_init saved
  );
  my $variable = '';
  foreach $variable (@variables) {
    print qq|
        <input name="$variable" type="hidden" value="$form->{$variable}">|;
  }
  print qq|
          <input type=hidden name="elsterland" value="$elsterland">
          <input type=hidden name="elsterFFFF" value="$elsterFFFF">
          <input type=hidden name="warnung" value="$warnung">
          <input type=hidden name="elstersteuernummer" value="$elstersteuernummer">
          <input type=hidden name="steuernummer" value="$stnr">
          <input type=hidden name="callback" value="$form->{callback}">
  </form>
  |;
  $lxdebug->leave_sub();
}

sub create_steuernummer {
  $lxdebug->enter_sub();
  my $part           = $form->{part};
  my $patterncount   = $form->{patterncount};
  my $delimiter      = $form->{delimiter};
  my $elster_pattern = $form->{elster_pattern};

  # rebuild steuernummer and elstersteuernummer
  # es gibt eine gespeicherte steuernummer $form->{steuernummer}
  # und die parts und delimiter

  my $h = 0;
  my $i = 0;

  my $steuernummer_new       = $part;
  my $elstersteuernummer_new = $form->{elster_FFFF};
  $elstersteuernummer_new .= '0';

  for ($h = 1; $h < $patterncount; $h++) {
    $steuernummer_new .= qq|$delimiter|;
    for (my $i = 1; $i <= length($elster_pattern); $i++) {
      $steuernummer_new       .= $form->{"part_$h\_$i"};
      $elstersteuernummer_new .= $form->{"part_$h\_$i"};
    }
  }
  if ($form->{steuernummer} ne $steuernummer_new) {
    $form->{steuernummer}       = $steuernummer_new;
    $form->{elstersteuernummer} = $elstersteuernummer_new;
    $form->{steuernummer_new}   = $steuernummer_new;
  } else {
    $form->{steuernummer_new}       = '';
    $form->{elstersteuernummer_new} = '';
  }
  $lxdebug->leave_sub();
}

sub get_config {
  $lxdebug->enter_sub();

  my ($userpath, $filename) = @_;
  my ($key,      $value)    = '';
  open(FACONF, "$userpath/$form->{login}_$filename")
    or    #falls Datei nicht vorhanden ist
    sub {
    open(FANEW, ">$userpath/$form->{login}_$filename")
      or $form->error("$userpath/$filename : $!");
    close FANEW;
    open(FACONF, "$userpath/$form->{login}_$filename")
      or $form->error("$userpath/$form->{username}_$filename : $!");
    };
  while (<FACONF>) {
    last if /^\[/;
    next if /^(#|\s)/;

    # remove comments
    s/\s#.*//g;

    # remove any trailing whitespace
    s/^\s*(.*?)\s*$/$1/;
    ($key, $value) = split /=/, $_, 2;

    #if ($value eq ' '){
    #   $form->{$key} = " " ;
    #} elsif ($value ne ' '){
    $form->{$key} = "$value";

    #}
  }
  close FACONF;

  # Textboxen formatieren: Linebreaks entfernen
  #
  #$form->{FA_Oeffnungszeiten} =~ s/\\\\n/<br>/g;
  $lxdebug->leave_sub();
}

sub save {
  $lxdebug->enter_sub();
  my $filename = "$form->{login}_$form->{filename}";

  #zuerst die steuernummer aus den part, parts_X_Y und delimiter herstellen
  create_steuernummer;

  # Textboxen formatieren: Linebreaks entfernen
  #
  $form->{FA_Oeffnungszeiten} =~ s/\r\n/\\n/g;

  #URL mit http:// davor?
  $form->{FA_Internet} =~ s/^http:\/\///;
  $form->{FA_Internet} = 'http://' . $form->{FA_Internet};

  my @config = qw(elster elsterland elstersteuernummer steuernummer
    elsteramt elsterFFFF FA_Name FA_Strasse
    FA_PLZ FA_Ort FA_Telefon FA_Fax FA_PLZ_Grosskunden
    FA_PLZ_Postfach FA_Postfach FA_BLZ_1 FA_Kontonummer_1
    FA_Bankbezeichnung_1 FA_BLZ_2 FA_Kontonummer_2
    FA_Bankbezeichnung_oertlich FA_Oeffnungszeiten
    FA_Email FA_Internet FA_voranmeld method FA_steuerberater_name
    FA_steuerberater_street FA_steuerberater_city FA_steuerberater_tel
    FA_71 FA_dauerfrist);

  # Hier kommt dann die Plausibilitätsprüfung der ELSTERSteuernummer
  if ($form->{elstersteuernummer} ne '000000000') {
    $form->{elster} = '1';
    open(CONF, ">$userspath/$filename") or $form->error("$filename : $!");

    # create the config file
    print CONF qq|# Configuration file for USTVA\n\n|;
    my $key = '';
    foreach $key (sort @config) {
      $form->{$key} =~ s/\\/\\\\/g;
      $form->{$key} =~ s/"/\\"/g;

      # strip M
      $form->{$key} =~ s/\r\n/\n/g;
      print CONF qq|$key=|;
      if ($form->{$key} ne 'Y') {
        print CONF qq|$form->{$key}\n|;
      }
      if ($form->{$key} eq 'Y') {
        print CONF qq|checked \n|;
      }
    }
    print CONF qq|\n\n|;
    close CONF;
    $form->{saved} = $locale->text('saved');

  } else {

    $form->{saved} = $locale->text('Bitte eine Steuernummer angeben');
  }

  &edit_form;
  $lxdebug->leave_sub();
}

sub show_fa_daten {
  $lxdebug->enter_sub();
  my $readonly        = $_;
  my $oeffnungszeiten = $form->{FA_Oeffnungszeiten};
  $oeffnungszeiten =~ s/\\\\n/\n/g;
  print qq|    <br>
               <fieldset>
               <legend>
               <font size="+1">|
    . $locale->text('Finanzamt') . qq| $form->{FA_Name}</font>
               </legend>
  |;

  #print qq|\n<h4>$form->{FA_Ergaenzung_Name}&nbsp;</h4>
  #        | if ( $form->{FA_Ergaenzung_Name} );
  print qq|
               <table width="100%" valign="top">
               <tr>
                <td valign="top">
                  <br>
                  <fieldset>
                    <legend>
                    <b>| . $locale->text('Address') . qq|</b>
                    </legend>

                  <table width="100%">
                   <tr>
                    <td>
                    | . $locale->text('Finanzamt') . qq|
                    </td>
                   </tr>
                   <tr>
                    <td colspan="2">
                     <input name="FA_Name" size="40" title="FA_Name" value="$form->{FA_Name}" $readonly>
                    <td>
                   </tr>
                   <tr>
                    <td colspan="2">
                     <input name="FA_Strasse" size="40" title="FA_Strasse" value="$form->{FA_Strasse}" $readonly>
                    </td width="100%">
                   </tr>
                   <tr>
                    <td width="116px">
                     <input name="FA_PLZ" size="10" title="FA_PLZ" value="$form->{FA_PLZ}" $readonly>
                    </td>
                    <td>
                     <input name="FA_Ort" size="20" title="FA_Ort" value="$form->{FA_Ort}" $readonly>
                    </td>
                  </tr>
                  </table>
                  </fieldset>
                  <br>
                  <fieldset>
                  <legend>
                  <b>| . $locale->text('Kontakt') . qq|</b>
                  </legend>
                      | . $locale->text('Telefon') . qq|<br>
                      <input name="FA_Telefon" size="40" title="FA_Telefon" value="$form->{FA_Telefon}" $readonly>
                      <br>
                      <br> 
                      | . $locale->text('Fax') . qq|<br>
                      <input name="FA_Fax" size="40" title="FA_Fax" value="$form->{FA_Fax}" $readonly>
                      <br>
                      <br>
                      | . $locale->text('Internet') . qq|<br>
                      <input name="FA_Email" size="40" title="FA_Email" value="$form->{FA_Email}" $readonly>
                      <br>
                      <br>
                      <input name="FA_Internet" size="40" title="" title="FA_Internet" value="$form->{FA_Internet}" $readonly>
                      <br>
                  </fieldset>
                </td>
                <td valign="top">
                  <br>
                  <fieldset>
                  <legend>
                  <b>| . $locale->text('Öffnungszeiten') . qq|</b>
                  </legend>
                  <textarea name="FA_Oeffnungszeiten" rows="4" cols="40" $readonly>$oeffnungszeiten</textarea>
                  </fieldset>
                  <br>
  |;
  my $FA_1 =
    (   $form->{FA_BLZ_1} ne ''
     && $form->{FA_Kontonummer_1}     ne ''
     && $form->{FA_Bankbezeichnung_1} ne '');
  my $FA_2 =
    (   $form->{FA_BLZ_2} ne ''
     && $form->{FA_Kontonummer_2}            ne ''
     && $form->{FA_Bankbezeichnung_oertlich} ne '');

  if ($FA_1 && $FA_2) {
    print qq|
                    <fieldset>
                    <legend>
                    <b>|
      . $locale->text('Bankverbindungen des Finanzamts') . qq|</b>
                    <legend>
                    <table>   
                    <tr>
                     <td>
                        | . $locale->text('Kreditinstitut') . qq|
                        <br>
                        <input name="FA_Bankbezeichnung_1" size="30" value="$form->{FA_Bankbezeichnung_1}" $readonly>
                        <br>
                        <br>
                        | . $locale->text('Kontonummer') . qq|
                        <br>
                        <input name="FA_Kontonummer_1" size="15" value="$form->{FA_Kontonummer_1}" $readonly>
                        <br>
                        <br> 
                        | . $locale->text('Bankleitzahl') . qq|
                        <br>
                        <input name="FA_BLZ_1" size="15" value="$form->{FA_BLZ_1}" $readonly>
                     </td>
                     <td>
                        | . $locale->text('Kreditinstitut') . qq|
                        <br>
                        <input name="FA_Bankbezeichnung_oertlich" size="30" value="$form->{FA_Bankbezeichnung_oertlich}" $readonly>
                        <br>
                        <br>
                        | . $locale->text('Kontonummer') . qq|
                        <br>
                        <input name="FA_Kontonummer_2" size="15" value="$form->{FA_Kontonummer_2}" $readonly>
                        <br>
                        <br> 
                        | . $locale->text('Bankleitzahl') . qq|
                        <br>
                        <input name="FA_BLZ_2" size="15" value="$form->{FA_BLZ_2}" $readonly>
                     </td>
                    </tr>
                    </table>
                    </fieldset>
    |;
  } elsif ($FA_1) {
    print qq|
                    <fieldset>
                    <legend>
                      <b>|
      . $locale->text('Bankverbindung des Finanzamts') . qq|</b>
                    <legend>
                    | . $locale->text('Kontonummer') . qq|
                    <br>
                    <input name="FA_Kontonummer_1" size="30" value="$form->{FA_Kontonummer_1}" $readonly>
                    <br>
                    <br> 
                    | . $locale->text('Bankleitzahl (BLZ)') . qq|
                    <br>
                    <input name="FA_BLZ_1" size="15" value="$form->{FA_BLZ_1}" $readonly>
                    <br>
                    <br>
                    | . $locale->text('Kreditinstitut') . qq|
                    <br>
                    <input name="FA_Bankbezeichnung_1" size="15" value="$form->{FA_Bankbezeichnung_1}" $readonly>
                    <br>
                    </fieldset>
    |;
  } else {
    print qq|
                    <fieldset>
                    <legend>
                      <b>|
      . $locale->text('Bankverbindung des Finanzamts') . qq|</b>
                    <legend> 
                    | . $locale->text('Kontonummer') . qq|
                    <br>
                    <input name="FA_Kontonummer_2" size="30" value="$form->{FA_Kontonummer_2}" $readonly>
                    <br>
                    <br> 
                    | . $locale->text('Bankleitzahl (BLZ)') . qq|
                    <br>
                    <input name="FA_BLZ_2" size="15" value="$form->{FA_BLZ_2}" $readonly>
                    <br>
                    <br>
                    | . $locale->text('Kreditinstitut') . qq|
                    <br>
                    <input name="FA_Bankbezeichnung_oertlich" size="15" value="$form->{FA_Bankbezeichnung_oertlich}" $readonly>
                    </fieldset>
    |;
  }
  print qq|
                 </td>
               </tr>              
          </table>
  </fieldset>
  |;
  $lxdebug->leave_sub();
}


sub continue {
  $lxdebug->enter_sub();

  # allow Symbolic references just here:
  no strict 'refs';
  &{ $form->{nextsub} };
  use strict 'refs';
  $lxdebug->leave_sub();
}

sub back {
  $lxdebug->enter_sub();
  &{ $form->{lastsub} };
  $lxdebug->leave_sub();
}

sub elster_hash {
  $lxdebug->enter_sub();
  my $finanzamt = USTVA::query_finanzamt(\%myconfig, \%$form);
  $lxdebug->leave_sub();
  return $finanzamt;
}


