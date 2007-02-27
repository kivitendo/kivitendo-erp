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
# Utilities for ustva
#=====================================================================

package USTVA;

sub create_steuernummer {
  $main::lxdebug->enter_sub();

  $part           = $form->{part};
  $patterncount   = $form->{patterncount};
  $delimiter      = $form->{delimiter};
  $elster_pattern = $form->{elster_pattern};

  # rebuild steuernummer and elstersteuernummer
  # es gibt eine gespeicherte steuernummer $form->{steuernummer}
  # und die parts und delimiter

  my $h = 0;
  my $i = 0;

  $steuernummer_new       = $part;
  $elstersteuernummer_new = $elster_FFFF;
  $elstersteuernummer_new .= '0';

  for ($h = 1; $h < $patterncount; $h++) {
    $steuernummer_new .= qq|$delimiter|;
    for ($i = 1; $i <= length($elster_pattern); $i++) {
      $steuernummer_new       .= $form->{"part_$h\_$i"};
      $elstersteuernummer_new .= $form->{"part_$h\_$i"};
    }
  }
  if ($form->{steuernummer} ne $steuernummer_new) {
    $form->{steuernummer}       = $steuernummer_new;
    $form->{elstersteuernummer} = $elstersteuernummer_new;
    $form->{steuernummer_new}   = $steuernummer_new;
  }
  $main::lxdebug->leave_sub();
  return ($steuernummer_new, $elstersteuernummer_new);
}

sub steuernummer_input {
  $main::lxdebug->enter_sub();

  my ($self, $elsterland, $elsterFFFF, $steuernummer) = @_;

  my $steuernummer_input = '';
  
  $elster_land  = $elsterland;
  $elster_FFFF  = $elsterFFFF;
  $steuernummer = '0000000000' if ($steuernummer eq '');

  # $steuernummer formatieren (nur Zahlen) -> $stnr
  my $stnr = $steuernummer;
  $stnr =~ s/\D+//g;

  #Pattern description Elstersteuernummer
  my %elster_STNRformat = (
      'Mecklenburg Vorpommern' => 'FFF/BBB/UUUUP',    # '/' 3
      'Hessen'                 => '0FF BBB UUUUP',    # ' ' 3
      'Nordrhein Westfalen'    => 'FFF/BBBB/UUUP',    # '/' 3
      'Schleswig Holstein'     => 'FF BBB UUUUP',     # ' ' 2
      'Berlin'                 => 'FF/BBB/UUUUP',     # '/' 3
      'Thüringen'              => 'FFF/BBB/UUUUP',    # '/' 3
      'Sachsen'                => 'FFF/BBB/UUUUP',    # '/' 3
      'Hamburg'                => 'FF/BBB/UUUUP',     # '/' 3
      'Baden Würtemberg'       => 'FF/BBB/UUUUP',     # '/' 2
      'Sachsen Anhalt'         => 'FFF/BBB/UUUUP',    # '/' 3
      'Saarland'               => 'FFF/BBB/UUUUP',    # '/' 3
      'Bremen'                 => 'FF BBB UUUUP',     # ' ' 3
      'Bayern'                 => 'FFF/BBB/UUUUP',    # '/' 3
      'Rheinland Pfalz'        => 'FF/BBB/UUUU/P',    # '/' 4
      'Niedersachsen'          => 'FF/BBB/UUUUP',     # '/' 3
      'Brandenburg'            => 'FFF/BBB/UUUUP',    # '/' 3
  );

  #split the pattern
  my $elster_pattern = $elster_STNRformat{$elster_land};
  my @elster_pattern = split(' ', $elster_pattern);
  my $delimiter      = '&nbsp;';
  my $patterncount   = @elster_pattern;
  if ($patterncount < 2) {
    @elster_pattern = ();
    @elster_pattern = split('/', $elster_pattern);
    $delimiter      = '/';
    $patterncount   = @elster_pattern;
  }

  # no we have an array of patternparts and a delimiter
  # create the first automated and fixed part and delimiter

  $steuernummer_input .= qq|<b><font size="+1">|;
  my $part = '';
SWITCH: {
    $elster_pattern[0] eq 'FFF' && do {
      $part = substr($elster_FFFF, 1, 4);
      $steuernummer_input .= qq|$part|;
      last SWITCH;
    };
    $elster_pattern[0] eq '0FF' && do {
      $part = '0' . substr($elster_FFFF, 2, 4);
      $steuernummer_input .= qq|$part|;
      last SWITCH;
    };
    $elster_pattern[0] eq 'FF' && do {
      $part = substr($elster_FFFF, 2, 4);
      $steuernummer_input .= qq|$part|;
      last SWITCH;
    };
    1 == 1 && do {
      $steuernummer_input .= qq|Fehler!|;
      last SWITCH;
    };
  }

  #now the rest of the Steuernummer ...
  $steuernummer_input .= qq|</b></font>|;
  $steuernummer_input .= qq|\n
           <input type=hidden name="elster_pattern" value="$elster_pattern">
           <input type=hidden name="patterncount" value="$patterncount">
           <input type=hidden name="patternlength" value="$patterncount">
           <input type=hidden name="delimiter" value="$delimiter">
           <input type=hidden name="part" value="$part">
  |;

  my $k = 0;

  for (my $h = 1; $h < $patterncount; $h++) {
    $steuernummer_input .= qq|&nbsp;$delimiter&nbsp;\n|;
    for (my $i = 1; $i <= length($elster_pattern[$h]); $i++) {
      $steuernummer_input .= qq|<select name="part_$h\_$i">\n|;

      for (my $j = 0; $j <= 9; $j++) {
        $steuernummer_input .= qq|      <option value="$j"|;
        if ($steuernummer ne '') {
          if ($j eq substr($stnr, length($part) + $k, 1)) {
            $steuernummer_input .= qq| selected|;
          }
        }
        $steuernummer_input .= qq|>$j</option>\n|;
      }
      $k++;
      $steuernummer_input .= qq|</select>\n|;
    }
  }
  
  $main::lxdebug->leave_sub();
  
  return $steuernummer_input;
}

sub fa_auswahl {
  $main::lxdebug->enter_sub();

#  use SL::Form;

  # Referenz wird übergeben, hash of hash wird nicht
  # in neues  Hash kopiert, sondern direkt über die Referenz verändert
  # Prototyp für diese Konstruktion

  my ($self, $land, $elsterFFFF, $elster_init) = @_;
  
  my $terminal = '';
  my $FFFF     = $elsterFFFF;
  my $ffff     = '';
  my $checked  = '';
  $checked = 'checked' if ($elsterFFFF eq '' and $land eq '');

  #if ($ENV{HTTP_USER_AGENT} =~ /(mozilla|opera|w3m)/i){
  #$terminal='mozilla';
  #} elsif ($ENV{HTTP_USER_AGENT} =~ /(links|lynx)/i){
  #$terminal = 'lynx';
  #}

  #if ( $terminal eq 'mozilla' or $terminal eq 'js' ) {
  my $fa_auswahl = qq|
        <script language="Javascript">
        function update_auswahl()
        {
                var elsterBLAuswahl = document.verzeichnis.elsterland_new;
                var elsterFAAuswahl = document.verzeichnis.elsterFFFF_new;

                elsterFAAuswahl.options.length = 0; // dropdown aufräumen
                |;

  foreach $elster_land (sort keys %$elster_init) {
    $fa_auswahl .= qq|
               if (elsterBLAuswahl.options[elsterBLAuswahl.selectedIndex].
               value == "$elster_land")
               {
               |;
    my $j              = 0;
    my %elster_land_fa = ();
    $FFFF = '';
    for $FFFF (keys %{ $elster_init->{$elster_land} }) {
      $elster_land_fa{$FFFF} = $elster_init->{$elster_land}->{$FFFF}->[0];
    }
    foreach $ffff (sort { $elster_land_fa{$a} cmp $elster_land_fa{$b} }
                   keys(%elster_land_fa)
      ) {
      $fa_auswahl .= qq|
                   elsterFAAuswahl.options[$j] = new Option("$elster_land_fa{$ffff} ($ffff)","$ffff");|;
      $j++;
    }
    $fa_auswahl .= qq|
               }|;
  }
  $fa_auswahl .= qq|
        }
        </script>

        <table width="100%">
          <tr>
            <td>
               Bundesland
            </td>
            <td>
              <select size="1" name="elsterland_new" onchange="update_auswahl()">|;
  if ($land eq '') {
    $fa_auswahl .= qq|<option value="Auswahl" $checked>hier auswählen...</option>\n|;
  }
  foreach $elster_land (sort keys %$elster_init) {
    $fa_auswahl .= qq|
                  <option value="$elster_land"|;
    if ($elster_land eq $land and $checked eq '') {
      $fa_auswahl .= qq| selected|;
    }
    $fa_auswahl .= qq|>$elster_land</option>
             |;
  }
  $fa_auswahl .= qq|
            </td>
          </tr>
          |;

  my $elster_land = '';
  $elster_land = ($land ne '') ? $land : '';
  %elster_land_fa = ();
  for $FFFF (keys %{ $elster_init->{$elster_land} }) {
    $elster_land_fa{$FFFF} = $elster_init->{$elster_land}->{$FFFF}->[0];
  }

  $fa_auswahl .= qq|
           <tr>
              <td>Finanzamt
              </td>
              <td>
                 <select size="1" name="elsterFFFF_new">|;
  if ($elsterFFFF eq '') {
    $fa_auswahl .= qq|<option value="Auswahl" $checked>hier auswählen...</option>|;
  } else {
    foreach $ffff (sort { $elster_land_fa{$a} cmp $elster_land_fa{$b} }
                   keys(%elster_land_fa)
      ) {

      $fa_auswahl .= qq|
                        <option value="$ffff"|;
      if ($ffff eq $elsterFFFF and $checked eq '') {
        $fa_auswahl .= qq| selected|;
      }
      $fa_auswahl .= qq|>$elster_land_fa{$ffff} ($ffff)</option>|;
    }
  }
  $fa_auswahl .= qq|
                 </td>
              </tr>
            </table>
            </select>|;

  $main::lxdebug->leave_sub();
  return $fa_auswahl;
}

sub info {
  $main::lxdebug->enter_sub();

  my $msg = $_[0];

  if ($ENV{HTTP_USER_AGENT}) {
    $msg =~ s/\n/<br>/g;

    print qq|<body><h2 class=info>Hinweis</h2>

    <p><b>$msg</b>
    <br>
    <br>
    <hr>
    <input type=button value="zurück" onClick="history.go(-1)">
    </body>
    |;

    exit;

  } else {

    if ($form->{error_function}) {
      &{ $form->{error_function} }($msg);
    } else {
      die "Hinweis: $msg\n";
    }
  }

  $main::lxdebug->leave_sub();
}

sub stichtag {
  $main::lxdebug->enter_sub();

  # noch nicht fertig
  # soll mal eine Erinnerungsfunktion für USTVA Abgaben werden, die automatisch
  # den Termin der nächsten USTVA anzeigt.
  #
  #
  my ($today, $FA_dauerfrist, $FA_voranmeld) = @_;

  #$today zerlegen:

  #$today =today * 1;
  $today =~ /(\d\d\d\d)(\d\d)(\d\d)/;
  $year     = $1;
  $month    = $2;
  $day      = $3;
  $yy       = $year;
  $mm       = $month;
  $yymmdd   = "$year$month$day" * 1;
  $mmdd     = "$month$day" * 1;
  $stichtag = '';

  #$tage_bis = '1234';
  #$ical = '...vcal format';

  #if ($FA_voranmeld eq 'month'){

  %liste = ("0110" => 'December',
            "0210" => 'January',
            "0310" => 'February',
            "0410" => 'March',
            "0510" => 'April',
            "0610" => 'May',
            "0710" => 'June',
            "0810" => 'July',
            "0910" => 'August',
            "1010" => 'September',
            "1110" => 'October',
            "1210" => 'November');

  #$mm += $dauerfrist
  #$month *= 1;
  $month += 1 if ($day > 10);
  $month    = sprintf("%02d", $month);
  $stichtag = $year . $month . "10";
  $ust_va   = $month . "10";

  foreach $date (%liste) {
    $ust_va = $liste{$date} if ($date eq $stichtag);
  }

  #} elsif ($FA_voranmeld eq 'quarter'){
  #1;

  #}

  #@stichtag = ('10.04.2004', '10.05.2004');

  #@liste = ['0110', '0210', '0310', '0410', '0510', '0610', '0710', '0810', '0910',
  #          '1010', '1110', '1210', ];
  #
  #foreach $key (@liste){
  #  #if ($ddmm < ('0110' * 1));
  #  if ($ddmm ){}
  #  $stichtag = $liste[$key - 1] if ($ddmm > $key);
  #
  #}
  #
  #$stichtag =~ /([\d]\d)(\d\d)$/
  #$stichtag = "$1.$2.$yy"
  #$stichtag=$1;
  $main::lxdebug->leave_sub();
  return ($stichtag, $description, $tage_bis, $ical);
}

sub query_finanzamt {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig) or $self->error(DBI->errstr);

  #Test, if table finanzamt exist
  my $table    = 'finanzamt';
  my $filename = "sql/$table.sql";

  my $tst = $dbh->prepare("SELECT * FROM $table");
  $tst->execute;
  if ($DBI::err) {

    #There is no table, read the table from sql/finanzamt.sql
    print qq|<p>Bitte warten, Tabelle $table wird einmalig in Datenbank:
    $myconfig->{dbname} als Benutzer: $myconfig->{dbuser} hinzugefügt...</p>|;
    process_query($form, $dbh, $filename) || $self->error(DBI->errstr);

    #execute second last call
    my $dbh = $form->dbconnect($myconfig) or $self->error(DBI->errstr);
    $dbh->disconnect();
  }
  $tst->finish();

  #$dbh->disconnect();

  my @vars = (
    'FA_Land_Nr',             #  0
    'FA_BUFA_Nr',             #  1
                              #'FA_Verteiler',				#  2
    'FA_Name',                #  3
    'FA_Strasse',             #  4
    'FA_PLZ',                 #  5
    'FA_Ort',                 #  6
    'FA_Telefon',             #  7
    'FA_Fax',                 #  8
    'FA_PLZ_Grosskunden',     #  9
    'FA_PLZ_Postfach',        # 10
    'FA_Postfach',            # 11
    'FA_BLZ_1',               # 12
    'FA_Kontonummer_1',       # 13
    'FA_Bankbezeichnung_1',   # 14
                              #'FA_BankIBAN_1',				# 15
                              #'FA_BankBIC_1',				# 16
                              #'FA_BankInhaber_BUFA_Nr_1',			# 17
    'FA_BLZ_2',               # 18
    'FA_Kontonummer_2',       # 19
    'FA_Bankbezeichnung_2',   # 20
                              #'FA_BankIBAN_2',				# 21
                              #'FA_BankBIC_2',				# 22
                              #'FA_BankInhaber_BUFA_Nr_2',			# 23
    'FA_Oeffnungszeiten',     # 24
    'FA_Email',               # 25
    'FA_Internet'             # 26
                              #'FA_zustaendige_Hauptstelle_BUFA_Nr',		# 27
                              #'FA_zustaendige_vorgesetzte_Finanzbehoerde'	# 28
  );

  my $field = join(', ', @vars);

  my $query = "SELECT $field FROM finanzamt ORDER BY FA_Land_nr";
  my $sth = $dbh->prepare($query) or $self->error($dbh->errstr);
  $sth->execute || $form->dberror($query);
  my $array_ref = $sth->fetchall_arrayref();
  my $land      = '';
  foreach my $row (@$array_ref) {
    my $FA_finanzamt = $row;
    $land = 'Schleswig Holstein'     if (@$FA_finanzamt[0] eq '1');
    $land = 'Hamburg'                if (@$FA_finanzamt[0] eq '2');
    $land = 'Niedersachsen'          if (@$FA_finanzamt[0] eq '3');
    $land = 'Bremen'                 if (@$FA_finanzamt[0] eq '4');
    $land = 'Nordrhein Westfalen'    if (@$FA_finanzamt[0] eq '5');
    $land = 'Hessen'                 if (@$FA_finanzamt[0] eq '6');
    $land = 'Rheinland Pfalz'        if (@$FA_finanzamt[0] eq '7');
    $land = 'Baden Würtemberg'       if (@$FA_finanzamt[0] eq '8');
    $land = 'Bayern'                 if (@$FA_finanzamt[0] eq '9');
    $land = 'Saarland'               if (@$FA_finanzamt[0] eq '10');
    $land = 'Berlin'                 if (@$FA_finanzamt[0] eq '11');
    $land = 'Brandenburg'            if (@$FA_finanzamt[0] eq '12');
    $land = 'Mecklenburg Vorpommern' if (@$FA_finanzamt[0] eq '13');
    $land = 'Sachsen'                if (@$FA_finanzamt[0] eq '14');
    $land = 'Sachsen Anhalt'         if (@$FA_finanzamt[0] eq '15');
    $land = 'Thüringen'              if (@$FA_finanzamt[0] eq '16');

    my $ffff = @$FA_finanzamt[1];

    my $rec = {};
    $rec->{$land} = $ffff;

    shift @$row;
    shift @$row;

    $finanzamt{$land}{$ffff} = [@$FA_finanzamt];
  }

  $sth->finish();
  $dbh->disconnect();

  $main::lxdebug->leave_sub();

  return \%finanzamt;
}

sub process_query {
  $main::lxdebug->enter_sub();

  # Copyright D. Simander -> SL::Form under Gnu GPL.
  my ($form, $dbh, $filename) = @_;

  #  return unless (-f $filename);

  open(FH, "$filename") or $form->error("$filename : $!\n");
  my $query = "";
  my $sth;
  my @quote_chars;

  while (<FH>) {

    # Remove DOS and Unix style line endings.
    s/[\r\n]//g;

    # don't add comments or empty lines
    next if /^(--.*|\s+)$/;

    for (my $i = 0; $i < length($_); $i++) {
      my $char = substr($_, $i, 1);

      # Are we inside a string?
      if (@quote_chars) {
        if ($char eq $quote_chars[-1]) {
          pop(@quote_chars);
        }
        $query .= $char;

      } else {
        if (($char eq "'") || ($char eq "\"")) {
          push(@quote_chars, $char);

        } elsif ($char eq ";") {

          # Query is complete. Send it.

          $sth = $dbh->prepare($query);
          $sth->execute || $form->dberror($query);
          $sth->finish;

          $char  = "";
          $query = "";
        }

        $query .= $char;
      }
    }
  }

  close FH;

  $main::lxdebug->leave_sub();
}

sub ustva {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period     = 0;
  my $category        = "pos_ustva";
  my @category_cent = qw(
     511  861  36   80   971  931  98   96   53   74
     85   65   66   61   62   67   63   64   59   69 
     39   83   811  891  Z43  Z45  Z53  Z62  Z65  Z67
  );

  my @category_euro = qw(
     41 44 49 43 48 51 
     86 35 77 76 91 97 
     93 95 94 42 60 45 
     52 73 84 81 89
  );

  $form->{decimalplaces} *= 1;

  foreach $item (@category_cent) {
    $form->{"$item"} = 0;
  }
  foreach $item (@category_euro) {
    $form->{"$item"} = 0;
  }

  $form->{coa} = coa_get($dbh);
  $main::lxdebug->message(LXDebug::DEBUG2, "COA: $form->{coa}");

  &get_accounts_ustva($dbh, $last_period, $form->{fromdate}, $form->{todate},
                      $form, $category);

  ###########################################
  #
  # Nationspecific Modfications
  #
  ###########################################
  
  # Germany
  
  if ( $form->{coa} eq 'Germany-DATEV-SKR03EU' or $form->{coa} eq 'Germany-DATEV-SKR04EU'){
  
    # 16%/19% Umstellung
    # Umordnen der Kennziffern
    if ( $form->{year} < 2007) {
      $form->{35} += $form->{81};
      $form->{36} += $form->{811};
      $form->{95} += $form->{89};
      $form->{98} += $form->{891};
      map { delete $form->{$_} } qw(81 811 89 891);
    } else {
      $form->{35} += $form->{51};
      $form->{36} += $form->{511};
      $form->{95} += $form->{97};
      $form->{98} += $form->{971};
      map { delete $form->{$_} } qw(51 511 97 971);
    }

  }


  # Fixme: Wird auch noch für Oesterreich gebraucht, 
  # weil kein eigenes Ausgabeformular
  # sotte aber aus der allgeméinen Steuerberechnung verschwinden
  #
  # Berechnung der USTVA Formularfelder laut Bogen 207
  #

  $form->{"51r"} = $form->{"511"};
  $form->{"86r"} = $form->{"861"};
  $form->{"97r"} = $form->{"971"};
  $form->{"93r"} = $form->{"931"};

  $form->{"Z43"} = $form->{"511"}     + $form->{"811"} + $form->{"861"} 
                     + $form->{"36"}  + $form->{"80"}  + $form->{"971"} 
                     + $form->{"891"} + $form->{"931"} + $form->{"96"} 
                     + $form->{"98"};

  $form->{"Z45"} = $form->{"Z43"};

  $form->{"Z53"} = $form->{"Z45"}     + $form->{"53"}  + $form->{"74"}  
                     + $form->{"85"}  + $form->{"65"};
                     
  $form->{"Z62"} = $form->{"Z43"}     - $form->{"66"}  - $form->{"61"} 
                     - $form->{"62"}  - $form->{"67"}  - $form->{"63"}  
                     - $form->{"64"}  - $form->{"59"};
                      
  $form->{"Z65"} = $form->{"Z62"}     - $form->{"69"};
  $form->{"83"}  = $form->{"Z65"}     - $form->{"39"};
  
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub coa_get {

  my ($dbh) = @_;
  
  my $query= qq|SELECT coa FROM defaults|;

  my $sth = $dbh->prepare($query);
  
  $sth->execute || $form->dberror($query);
    
  ($ref) = $sth->fetchrow_array;
  
  return $ref;

};

sub get_accounts_ustva {
  $main::lxdebug->enter_sub();

  my ($dbh, $last_period, $fromdate, $todate, $form, $category) = @_;

  my ($null, $department_id) = split /--/, $form->{department};

  my $query;
  my $dpt_where;
  my $dpt_join;
  my $project;
  my $where    = "";
  my $glwhere  = "";
  my $subwhere = "";
  my $ARwhere  = "";
  my $APwhere  = '';
  my $arwhere  = "";
  my $item;

    my $gltaxkey_where = "(tk.pos_ustva>=59 AND tk.pos_ustva<=66)";

  if ($fromdate) {
    if ($form->{method} eq 'cash') {
      $subwhere .= " AND transdate >= '$fromdate'";
      $glwhere = " AND ac.transdate >= '$fromdate'";
      $ARwhere .= " AND acc.transdate >= '$fromdate'"; 
    }
    $APwhere .= " AND AP.transdate >= '$fromdate'";
    $where .= " AND ac.transdate >= '$fromdate'";
  }

  if ($todate) {
    $where    .= " AND ac.transdate <= '$todate'";
    $ARwhere  .= " AND acc.transdate <= '$todate'";
  }

  if ($department_id) {
    $dpt_join = qq|
               JOIN department t ON (a.department_id = t.id)
		  |;
    $dpt_where = qq|
               AND t.id = $department_id
	           |;
  }

  if ($form->{project_id}) {
    $project = qq|
                 AND ac.project_id = $form->{project_id}
		 |;
  }
  ############################################
  # Method eq 'cash' = IST Versteuerung
  ############################################
  # Betrifft nur die eingenommene Umsatzsteuer
  #
  ############################################

  if ($form->{method} eq 'cash') {  

    $query = qq|
       SELECT
         -- USTVA IST-Versteuerung
         -- 
         -- Alle tatsaechlichen _Zahlungseingaenge_ 
         -- im Voranmeldezeitraum erfassen 
         -- (Teilzahlungen werden prozentual auf verschiedene Steuern aufgeteilt)
         SUM( ac.amount * 
            -- Bezahlt / Rechnungssumme
           ( 
             SELECT SUM(acc.amount)
             FROM acc_trans acc
             INNER JOIN chart c ON (acc.chart_id   =   c.id 
                                    AND c.link   like  '%AR_paid%')
             WHERE
              1=1 
              $ARwhere
              AND acc.trans_id = ac.trans_id
              )
           / 
           ( 
            SELECT amount FROM ar WHERE id = ac.trans_id  
           )
         ) AS amount,
         tk.pos_ustva
       FROM acc_trans ac
       LEFT JOIN chart c ON (c.id  = ac.chart_id)
       LEFT JOIN ar      ON (ar.id = ac.trans_id)
       LEFT JOIN taxkeys tk ON (
         tk.id = (
           SELECT id FROM taxkeys 
           WHERE chart_id   = ac.chart_id 
             -- AND taxkey_id  = ac.taxkey 
             AND startdate <= COALESCE(ar.deliverydate,ar.transdate)
           ORDER BY startdate DESC LIMIT 1
         )
       )
       WHERE 
       1=1 
       -- Here no where, please. All Transactions ever should be
       -- testet if they are paied in the USTVA report period.
       GROUP BY tk.pos_ustva
    |;
   
  } elsif ($form->{method} eq 'accrual') {
    #########################################
    # Method eq 'accrual' = Soll Versteuerung
    #########################################

    if ($department_id) {
      $dpt_join = qq|
	      JOIN dpt_trans t ON (t.trans_id = ac.trans_id)
	      |;
      $dpt_where = qq|
               AND t.department_id = $department_id
	      |;
    }


    $query = qq|
       -- Alle Einnahmen AR und pos_ustva erfassen
       SELECT
         - sum(ac.amount) AS amount, 
         tk.pos_ustva
       FROM acc_trans ac 
       JOIN chart c ON (c.id = ac.chart_id) 
       JOIN ar ON (ar.id = ac.trans_id)
       JOIN taxkeys tk ON (
         tk.id = (
           SELECT id FROM taxkeys 
           WHERE chart_id   = ac.chart_id 
             AND startdate <= COALESCE(ar.deliverydate,ar.transdate)
           ORDER BY startdate DESC LIMIT 1
         )
       )
       $dpt_join
       WHERE 1 = 1
       $where
       $dpt_where
       $project
       GROUP BY tk.pos_ustva
  |;
   
  } else {
  
    $self->error("Unknown tax method: $form->{method}")

  }
  
  #########################################
  # Ausgaben und Gl Buchungen sind gleich
  # für Ist- und Soll-Versteuerung
  #########################################
  $query .= qq| 
     UNION -- alle Ausgaben AP erfassen

       SELECT
         sum(ac.amount) AS amount, 
         tk.pos_ustva
       FROM acc_trans ac
       JOIN ap ON (ap.id = ac.trans_id )
       JOIN chart c ON (c.id = ac.chart_id)
       LEFT JOIN taxkeys tk ON (
           tk.id = (
             SELECT id FROM taxkeys 
             WHERE chart_id=ac.chart_id 
               AND taxkey_id = ac.taxkey 
               AND startdate <= COALESCE(AP.transdate)
             ORDER BY startdate DESC LIMIT 1
           )
       )
       WHERE
       1=1
       $where
       $dpt_where
       $project
       GROUP BY tk.pos_ustva

     UNION -- Einnahmen direkter gl Buchungen erfassen

       SELECT sum
         ( - ac.amount) AS amount, 
         tk.pos_ustva
       FROM acc_trans ac
       JOIN chart c ON (c.id = ac.chart_id)
       JOIN gl a ON (a.id = ac.trans_id)
       LEFT JOIN taxkeys tk ON (
         tk.id = (
           SELECT id FROM taxkeys 
           WHERE chart_id=ac.chart_id 
             AND NOT $gltaxkey_where  
             AND startdate <= COALESCE(ac.transdate)
           ORDER BY startdate DESC LIMIT 1
         )
       )

       $dpt_join
       WHERE 1 = 1
       $where
       $dpt_from
       $project
       GROUP BY tk.pos_ustva


     UNION -- Ausgaben direkter gl Buchungen erfassen

       SELECT sum
         (ac.amount) AS amount, 
         tk.pos_ustva
       FROM acc_trans ac
       JOIN chart c ON (c.id = ac.chart_id)
       JOIN gl a ON (a.id = ac.trans_id)
       LEFT JOIN taxkeys tk ON (
         tk.id = (
           SELECT id FROM taxkeys 
           WHERE chart_id=ac.chart_id 
             AND $gltaxkey_where 
             AND startdate <= COALESCE(ac.transdate)
           ORDER BY startdate DESC LIMIT 1
         )
       )

       $dpt_join
       WHERE 1 = 1
       $where
       $dpt_from
       $project
       GROUP BY tk.pos_ustva

  |;

  my @accno;
  my $accno;
  my $ref;

  # Show all $query in Debuglevel LXDebug::QUERY
  $callingdetails = (caller (0))[3];
  $main::lxdebug->message(LXDebug::QUERY, "$callingdetails \$query=\n $query");
              
  my $sth = $dbh->prepare($query);
  
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    # Bug 365 solved?!
    $ref->{amount} *= -1;
    if ($category eq "pos_bwa") {
      if ($last_period) {
        $form->{ $ref->{$category} }{kumm} += $ref->{amount};
      } else {
        $form->{ $ref->{$category} }{jetzt} += $ref->{amount};
      }
    } else {
      $form->{ $ref->{$category} } += $ref->{amount};
    }
  }

  $sth->finish;

  $main::lxdebug->leave_sub();

}



1;
