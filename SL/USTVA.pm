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
# Utilities for ustva
#=====================================================================

package USTVA;

use Carp;
use Data::Dumper;
use List::Util qw(first);

use SL::DB;
use SL::DBUtils;
use SL::DB::Default;
use SL::DB::Finanzamt;
use SL::Locale::String qw(t8);

use utf8;
use strict;

my @tax_office_information = (
  { 'id' =>  8, 'name' => 'Baden-Württemberg',      'taxbird_nr' => '1',  'elster_format' => 'FFBBB/UUUUP',  },
  { 'id' =>  9, 'name' => 'Bayern',                 'taxbird_nr' => '2',  'elster_format' => 'FFF/BBB/UUUUP', },
  { 'id' => 11, 'name' => 'Berlin',                 'taxbird_nr' => '3',  'elster_format' => 'FF/BBB/UUUUP',  },
  { 'id' => 12, 'name' => 'Brandenburg',            'taxbird_nr' => '4',  'elster_format' => 'FFF/BBB/UUUUP', },
  { 'id' =>  4, 'name' => 'Bremen',                 'taxbird_nr' => '5',  'elster_format' => 'FF BBB UUUUP',  },
  { 'id' =>  2, 'name' => 'Hamburg',                'taxbird_nr' => '6',  'elster_format' => 'FF/BBB/UUUUP',  },
  { 'id' =>  6, 'name' => 'Hessen',                 'taxbird_nr' => '7',  'elster_format' => '0FF BBB UUUUP', },
  { 'id' => 13, 'name' => 'Mecklenburg-Vorpommern', 'taxbird_nr' => '8',  'elster_format' => 'FFF/BBB/UUUUP', },
  { 'id' =>  3, 'name' => 'Niedersachsen',          'taxbird_nr' => '9',  'elster_format' => 'FF/BBB/UUUUP',  },
  { 'id' =>  5, 'name' => 'Nordrhein-Westfalen',    'taxbird_nr' => '10', 'elster_format' => 'FFF/BBBB/UUUP', },
  { 'id' =>  7, 'name' => 'Rheinland-Pfalz',        'taxbird_nr' => '11', 'elster_format' => 'FF/BBB/UUUUP', },
  { 'id' => 10, 'name' => 'Saarland',               'taxbird_nr' => '12', 'elster_format' => 'FFF/BBB/UUUUP', },
  { 'id' => 14, 'name' => 'Sachsen',                'taxbird_nr' => '13', 'elster_format' => 'FFF/BBB/UUUUP', },
  { 'id' => 15, 'name' => 'Sachsen-Anhalt',         'taxbird_nr' => '14', 'elster_format' => 'FFF/BBB/UUUUP', },
  { 'id' =>  1, 'name' => 'Schleswig-Holstein',     'taxbird_nr' => '15', 'elster_format' => 'FF BBB UUUUP',  },
  { 'id' => 16, 'name' => 'Thüringen',              'taxbird_nr' => '16', 'elster_format' => 'FFF/BBB/UUUUP', },
  );

  my @fiamt_config = qw(taxnumber fa_bufa_nr fa_dauerfrist fa_steuerberater_city fa_steuerberater_name
  fa_steuerberater_street fa_steuerberater_tel fa_voranmeld);

  my @fiamt_finanzamt = qw(
    fa_land_nr          fa_bufa_nr            fa_name             fa_strasse
    fa_plz              fa_ort                fa_telefon          fa_fax
    fa_plz_grosskunden  fa_plz_postfach       fa_postfach
    fa_blz_1 fa_kontonummer_1 fa_bankbezeichnung_1
    fa_blz_2 fa_kontonummer_2 fa_bankbezeichnung_2 fa_oeffnungszeiten
    fa_email fa_internet);


sub new {
  my $type = shift;

  my $self = {};

  bless $self, $type;

  $self->_init(@_);

  return $self;
}

sub _init {
  my $self = shift;

  $self->{tax_office_information} = [];

  foreach (@tax_office_information) {
    my $entry      = \%{ $_ };
    $entry->{name} = $::locale->{iconv_utf8}->convert($entry->{name});
    push @{ $self->{tax_office_information} }, $entry;
  }
}

sub get_coa {

  my ( $self, $form ) = @_;

  my $coa = $::instance_conf->get_coa;
  $form->{coa} = $coa;
  $form->{"COA_$coa"} = '1';
  $form->{COA_Germany} = '1' if ($coa =~ m/^germany/i);

  return;
}


sub report_variables {
  # Get all positions for taxreport out of the database
  # Needs Databaseupdate Pg-upgrade2/USTVA_abstraction.pl

  my ( $self,
       $arg_ref) = @_;

  my $myconfig   = $arg_ref->{myconfig};
  my $form       = $arg_ref->{form};
  my $type       = $arg_ref->{type}; # 'paied' || 'received' || ''
  my $attribute  = $arg_ref->{attribute}; #
  my $dec_places = (defined $arg_ref->{dec_places}) ? $arg_ref->{dec_places}:undef;

  my $where_type = $type ? "AND tax.report_headings.type = '$type'" : '';
  my $where_dcp  = defined $dec_places ? "AND tax.report_variables.dec_places = '$dec_places'" : '';

  my $query = qq|
    SELECT $attribute
    FROM tax.report_variables
    LEFT JOIN tax.report_headings
      ON (tax.report_variables.heading_id = tax.report_headings.id)
    WHERE 1=1
    $where_type
    $where_dcp
  |;

  my @positions;

  SL::DB->client->with_transaction(sub {
    my $dbh = SL::DB->client->dbh;
    my $sth = $dbh->prepare($query);

    $sth->execute() || $form->dberror($query);

    while ( my $row_ref = $sth->fetchrow_arrayref() ) {
      push @positions, @$row_ref;  # Copy the array contents
    }

    $sth->finish;
    1;
  }) or do { die SL::DB->client->error };

  return @positions;
}


sub steuernummer_input {
  $main::lxdebug->enter_sub();

  my ($self, $elsterland, $elsterFFFF, $steuernummer) = @_;
  our ($elster_FFFF, $elster_land);

  my $steuernummer_input = '';

  $elster_land  = $elsterland;
  $elster_FFFF  = $elsterFFFF;
  $steuernummer = '0000000000' if ($steuernummer eq '');

  # $steuernummer formatieren (nur Zahlen) -> $stnr
  my $stnr = $steuernummer;
  $stnr =~ s/\D+//g;

  #Pattern description Elstersteuernummer

  #split the pattern
  my $tax_office     = first { $_->{id} eq $elster_land } @{ $self->{tax_office_information} };
  my $elster_pattern = $tax_office->{elster_format};
 # $::lxdebug->message(LXDebug->DEBUG2, "stnr=".$stnr." elster_FFFF=".$elster_FFFF.
 #                     " pattern=".$elster_pattern." land=".$elster_land);
  my @elster_pattern = split(' ', $elster_pattern);
  my $delimiter1      = '&nbsp;';
  my $delimiter2      = '&nbsp;';
  my $patterncount   = @elster_pattern;
  if ($patterncount < 2) {
    @elster_pattern = ();
    @elster_pattern = split('/', $elster_pattern);
    $delimiter1      = '/';
    $delimiter2      = '/';
    $patterncount   = @elster_pattern;
    if ($patterncount < 2) {
        @elster_pattern = ();
        @elster_pattern = split(' ', $elster_pattern);
        $delimiter1      = ' ';
        $delimiter2      = ' ';
        $patterncount   = @elster_pattern;
    }
  }

  # no we have an array of patternparts and a delimiter
  # create the first automated and fixed part and delimiter

  $steuernummer_input .= qq|<b><font size="+1">|;
  my $part = '';
#  $::lxdebug->message(LXDebug->DEBUG2, "pattern0=".$elster_pattern[0]);
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
    $elster_pattern[0] eq 'FFBBB' && do {
      $part = substr($elster_FFFF, 2, 4);
      $steuernummer_input .= qq|$part|;
      $delimiter1 = '';
      $patterncount++ ;
      # Sonderfall BW
      @elster_pattern = ('FF','BBB','UUUUP');
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
  $steuernummer_input .= qq|</font></b>|;
  $steuernummer_input .= qq|\n
           <input type=hidden name="elster_pattern" value="$elster_pattern">
           <input type=hidden name="patterncount" value="$patterncount">
           <input type=hidden name="patternlength" value="$patterncount">
           <input type=hidden name="delimiter1" value="$delimiter1">
           <input type=hidden name="delimiter2" value="$delimiter2">
           <input type=hidden name="part" value="$part">
  |;

  my $k = 0;

  for (my $h = 1; $h < $patterncount; $h++) {
    my $delimiter = ( $h==1?$delimiter1:$delimiter2);
    $steuernummer_input .= qq|&nbsp;$delimiter&nbsp;\n|;
#  $::lxdebug->message(LXDebug->DEBUG2, "pattern[$h]=".$elster_pattern[$h]);
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

  # Referenz wird übergeben, hash of hash wird nicht
  # in neues  Hash kopiert, sondern direkt über die Referenz verändert
  # Prototyp für diese Konstruktion

  my ($self, $land, $elsterFFFF, $elster_init) = @_;

#  $::lxdebug->message(LXDebug->DEBUG2,"land=".$land." amt=".$elsterFFFF);
  my $terminal = '';
  my $FFFF     = $elsterFFFF;
  my $ffff     = '';
  my $checked  = '';
  $checked = 'checked' if ($elsterFFFF eq '' and $land eq '');
  my %elster_land_fa;
  my %elster_land_name = ();

  my $fa_auswahl = qq|
        <script language="Javascript">
        function update_auswahl()
        {
                var elsterBLAuswahl = document.verzeichnis.fa_land_nr_new;
                var elsterFAAuswahl = document.verzeichnis.fa_bufa_nr_new;

                elsterFAAuswahl.options.length = 0; // dropdown aufräumen
                |;

  foreach my $elster_land (sort keys %$elster_init) {
    $fa_auswahl .= qq|
               if (elsterBLAuswahl.options[elsterBLAuswahl.selectedIndex].value == "$elster_land")
               {
               |;
    my $j              = 0;
    %elster_land_fa = ();
    $FFFF = '';
    for $FFFF (keys %{ $elster_init->{$elster_land} }) {
        if ( $FFFF eq 'name' ) {
            $elster_land_name{$elster_land} = $elster_init->{$elster_land}{$FFFF};
            delete $elster_init->{$elster_land}{$FFFF};
        } else {
            $elster_land_fa{$FFFF} = $elster_init->{$elster_land}{$FFFF}->fa_name;
       }
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
              <select size="1" name="fa_land_nr_new" onchange="update_auswahl()">|;
  if ($land eq '') {
    $fa_auswahl .= qq|<option value="Auswahl" $checked>| . $main::locale->text('Select federal state...') . qq|</option>\n|;
  }
  foreach my $elster_land (sort keys %$elster_init) {
    $fa_auswahl .= qq|
                  <option value="$elster_land"|;
#  $::lxdebug->message(LXDebug->DEBUG2,"land=".$land." elster_land=".$elster_land." lname=".$elster_land_name{$elster_land});
    if ($elster_land eq $land and $checked eq '') {
      $fa_auswahl .= qq| selected|;
    }
    $fa_auswahl .= qq|>$elster_land_name{$elster_land}</option>
             |;
  }
  $fa_auswahl .= qq|
              </select>
            </td>
          </tr>
          |;

  my $elster_land = '';
  $elster_land = ($land ne '') ? $land : '';
  %elster_land_fa = ();
  for $FFFF (keys %{ $elster_init->{$elster_land} }) {
    $elster_land_fa{$FFFF} = $elster_init->{$elster_land}{$FFFF}->fa_name;
  }

  $fa_auswahl .= qq|
           <tr>
              <td>Finanzamt
              </td>
              <td>
                 <select size="1" name="fa_bufa_nr_new">|;
  if ($elsterFFFF eq '') {
    $fa_auswahl .= qq|<option value="Auswahl" $checked>| . $main::locale->text('Select tax office...') . qq|</option>|;
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
                 </select>
              </td>
          </tr>
        </table>|;

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
    <input type=button value="| . $main::locale->text('Back') . qq|" onClick="history.go(-1)">
    </body>
    |;

    $::dispatcher->end_request;

  } else {

    die "Hinweis: $msg\n";
  }

  $main::lxdebug->leave_sub();
}

sub query_finanzamt {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  #Test, if table finanzamt exist
  my $table    = 'finanzamt';
  my $filename = "sql/$table.sql";

  my $tst = $dbh->prepare("SELECT * FROM $table");
  $tst->execute || do {
    #There is no table, read the table from sql/finanzamt.sql
    print qq|<p>Bitte warten, Tabelle $table wird einmalig in Datenbank:
    $myconfig->{dbname} als Benutzer: $myconfig->{dbuser} hinzugefügt...</p>|;
    SL::DB->client->with_transaction(sub {
      process_query($form, $dbh, $filename) || $self->error(DBI->errstr);
      1;
    }) or do { die SL::DB->client->error };
  };
  $tst->finish();


  my $fiamt =  SL::DB::Finanzamt->_get_manager_class->get_all(sort => 'fa_land_nr');
  my $land      = 0;
  my %finanzamt;
  foreach my $row (@$fiamt) {
    my $tax_office   = first { $_->{id} == $row->fa_land_nr } @{ $self->{tax_office_information} };
    $land            = $tax_office->{id};
    $finanzamt{$land}{$row->fa_bufa_nr}  = $row;
    $finanzamt{$land}{'name'} ||= $tax_office->{name};
  }
  $main::lxdebug->leave_sub();

  return \%finanzamt;
}

sub process_query {
  $main::lxdebug->enter_sub();

  my ($form, $dbh, $filename) = @_;

  open my $FH, "<", "$filename" or $form->error("$filename : $!\n");
  my $query = "";
  my $sth;
  my @quote_chars;

  while (<$FH>) {

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

  close $FH;

  $main::lxdebug->leave_sub();
}

sub ustva {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $dbh = SL::DB->client->dbh;

  my $last_period     = 0;
  my $category        = "pos_ustva";

  $form->{coa} = $::instance_conf->get_coa;

  unless ($form->{coa} eq 'Germany-DATEV-SKR03EU' or $form->{coa} eq 'Germany-DATEV-SKR04EU') {
    croak t8("Advance turnover tax return only valid for SKR03 or SKR04");
  }
  my @category_cent = USTVA->report_variables({
      myconfig    => $myconfig,
      form        => $form,
      type        => '',
      attribute   => 'position',
      dec_places  => '2',
  });
  push @category_cent, ("pos_ustva_811b_kivi", "pos_ustva_861b_kivi");
  if ( $form->{coa} eq 'Germany-DATEV-SKR03EU' or $form->{coa} eq 'Germany-DATEV-SKR04EU') {
      push @category_cent, qw(Z43  Z45  Z53  Z54  Z62  Z65  Z67);
  }
  my @category_euro = USTVA->report_variables({
      myconfig    => $myconfig,
      form        => $form,
      type        => '',
      attribute   => 'position',
      dec_places  => '0',
  });
  push @category_euro, ("pos_ustva_81b_kivi", "pos_ustva_86b_kivi");
  @{$form->{category_cent}} = @category_cent;
  @{$form->{category_euro}} = @category_euro;
  $form->{decimalplaces} *= 1;

  foreach my $item (@category_cent) {
    $form->{"$item"} = 0;
  }
  foreach my $item (@category_euro) {
    $form->{"$item"} = 0;
  }

  # Controlvariable for templates
  my $coa_name = $form->{coa};
  $form->{"$coa_name"} = '1';

  &get_accounts_ustva($dbh, $last_period, $form->{fromdate}, $form->{todate},
                      $form, $category);

  ###########################################
  #
  # Nationspecific Modfications
  #
  ###########################################

  # Germany

  if ( $form->{coa} eq 'Germany-DATEV-SKR03EU' or $form->{coa} eq 'Germany-DATEV-SKR04EU') {

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
  # sollte aber aus der allgemeinen Steuerberechnung verschwinden
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

  $form->{"Z53"} = $form->{"Z45"}     + $form->{"47"}  + $form->{"53"}  + $form->{"74"}
                     + $form->{"85"}  + $form->{"65"};

  $form->{"Z62"} = $form->{"Z53"}     - $form->{"66"}  - $form->{"61"}
                     - $form->{"62"}  - $form->{"67"}  - $form->{"63"}
                     - $form->{"64"}  - $form->{"59"};

  $form->{"Z65"} = $form->{"Z62"}     - $form->{"69"};
  $form->{"83"}  = $form->{"Z65"}     - $form->{"39"};

  $main::lxdebug->leave_sub();
}

sub get_accounts_ustva {
  $main::lxdebug->enter_sub();

  my ($dbh, $last_period, $fromdate, $todate, $form, $category) = @_;
  our ($dpt_join);

  my $query;
  my $where    = "";
  my $glwhere  = "";
  my $subwhere = "";
  my $ARwhere  = "";
  my $APwhere  = '';
  my $arwhere  = "";
  my $item;

  my $gltaxkey_where = "((tk.pos_ustva = 46) OR (tk.pos_ustva>=59 AND tk.pos_ustva<=67) or (tk.pos_ustva>=89 AND tk.pos_ustva<=93))";

  if ($fromdate) {
    if ($form->{accounting_method} eq 'cash') {
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

  my $acc_trans_where = '1=1';
  if ($fromdate || $todate) {
    $acc_trans_where = "ac.trans_id IN (SELECT DISTINCT trans_id FROM acc_trans WHERE ";

    if ($fromdate) {
      $acc_trans_where .= "transdate >= '$fromdate'";
    }
    if ($todate) {
      $acc_trans_where .= " AND " if ($fromdate);
      $acc_trans_where .= "transdate <= '$todate'";
    }

    $acc_trans_where .= ")";
  }

  ############################################
  # Method eq 'cash' = IST Versteuerung
  ############################################
  # Betrifft nur die eingenommene Umsatzsteuer
  #
  ############################################

  if ($form->{accounting_method} eq 'cash') {

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
              )           /
           (
            SELECT amount FROM ar WHERE id = ac.trans_id
           )
         ) AS amount,
         tk.pos_ustva,  t.rate, c.accno
       FROM acc_trans ac
       LEFT JOIN chart c ON (c.id  = ac.chart_id)
       LEFT JOIN ar      ON (ar.id = ac.trans_id)
       LEFT JOIN tax t   ON (t.id = ac.tax_id)
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
       $acc_trans_where
       GROUP BY tk.pos_ustva, t.rate, c.accno
    |;

  } elsif ($form->{accounting_method} eq 'accrual') {
    #########################################
    # Method eq 'accrual' = Soll Versteuerung
    #########################################

    $query = qq|
       -- Alle Einnahmen AR und pos_ustva erfassen
       SELECT
         - sum(ac.amount) AS amount,
         tk.pos_ustva, t.rate, c.accno
       FROM acc_trans ac
       JOIN chart c ON (c.id = ac.chart_id)
       JOIN ar ON (ar.id = ac.trans_id)
       JOIN tax t ON (t.id = ac.tax_id)
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
       GROUP BY tk.pos_ustva, t.rate, c.accno
  |;

  } else {

    $form->error("Unknown tax method: $form->{accounting_method}")

  }

  #########################################
  # Ausgaben und Gl Buchungen sind gleich
  # für Ist- und Soll-Versteuerung
  #########################################
  $query .= qq|
     UNION -- alle Ausgaben AP erfassen

       SELECT
         sum(ac.amount) AS amount,
         tk.pos_ustva, t.rate, c.accno
       FROM acc_trans ac
       JOIN ap ON (ap.id = ac.trans_id )
       JOIN chart c ON (c.id = ac.chart_id)
       JOIN tax t ON (t.id = ac.tax_id)
       LEFT JOIN taxkeys tk ON (
           tk.id = (
             SELECT id FROM taxkeys
             WHERE 1=1
               AND chart_id=ac.chart_id
               --AND taxkey_id = ac.taxkey
               AND startdate <= COALESCE(AP.transdate)
             ORDER BY startdate DESC LIMIT 1
           )
       )
       WHERE
       1=1
       $where
       GROUP BY tk.pos_ustva, t.rate, c.accno

     UNION -- Einnahmen direkter gl Buchungen erfassen

       SELECT sum
         ( - ac.amount) AS amount,
         tk.pos_ustva, t.rate, c.accno
       FROM acc_trans ac
       JOIN chart c ON (c.id = ac.chart_id)
       JOIN gl a ON (a.id = ac.trans_id)
       JOIN tax t ON (t.id = ac.tax_id)
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
       GROUP BY tk.pos_ustva, t.rate, c.accno


     UNION -- Ausgaben direkter gl Buchungen erfassen

       SELECT sum
         (ac.amount) AS amount,
         tk.pos_ustva, t.rate, c.accno
       FROM acc_trans ac
       JOIN chart c ON (c.id = ac.chart_id)
       JOIN gl a ON (a.id = ac.trans_id)
       JOIN tax t ON (t.id = ac.tax_id)
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
       GROUP BY tk.pos_ustva, t.rate, c.accno

  |;

  # Show all $query in Debuglevel LXDebug::QUERY
  my $callingdetails = (caller (0))[3];
  $main::lxdebug->message(LXDebug->QUERY(), "$callingdetails \$query=\n $query");

  my $sth = $dbh->prepare($query);

  $sth->execute || $form->dberror($query);
  # ugly, but we need to use static accnos
  my ($accno_five, $accno_sixteen, $corr);

  if ($form->{coa} eq 'Germany-DATEV-SKR03EU') {
    $accno_five     = 1773;
    $accno_sixteen  = 1775;
  } elsif (($form->{coa} eq 'Germany-DATEV-SKR04EU')) {
    $accno_five     = 3803; # SKR04
    $accno_sixteen  = 3805; # SKR04
  } else {die "wrong call"; }

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    next unless $ref->{$category};
    $corr = 0;
    $ref->{amount} *= -1;
    # USTVA Pos 35
    if ($ref->{pos_ustva} eq '35') {
      if ($ref->{rate} == 0.16) {
        $form->{"pos_ustva_81b_kivi"} += $ref->{amount};
      } elsif ($ref->{rate} == 0.05) {
        $form->{"pos_ustva_86b_kivi"} += $ref->{amount};
      } elsif ($ref->{rate} == 0.19) {
        # pos_ustva says 16, but rate says 19
        # (pos_ustva should be tax dependent and not taxkeys dependent)
        # correction hotfix for this case:
        # bookings exists with 19% ->
        # move 19% bookings to the 19% position
        # Dont rely on dates of taxkeys
        $corr = 1;
        $form->{"81"} += $ref->{amount};
      }  elsif ($ref->{rate} == 0.07) {
        # pos_ustva says 5, but rate says 7
        # see comment above:
        # Dont rely on dates of taxkeys
        $corr = 1;
        $form->{"86"} += $ref->{amount};
      } else {die ("No valid tax rate for pos 35" . Dumper($ref)); }
    }
    # USTVA Pos 36 (Steuerkonten)
    if ($ref->{pos_ustva} eq '36') {
      if ($ref->{accno} =~ /^$accno_sixteen/) {
        $form->{"pos_ustva_811b_kivi"} += $ref->{amount};
      } elsif ($ref->{accno} =~ /^$accno_five/) {
        $form->{"pos_ustva_861b_kivi"} += $ref->{amount};
      } else { die ("No valid accno for pos 36" . Dumper($ref)); }
    }
  $form->{ $ref->{$category} } += $ref->{amount} unless $corr;
  }

  $sth->finish;

  $main::lxdebug->leave_sub();

}

sub set_FromTo {
  $main::lxdebug->enter_sub();

  my ($self, $form) = @_;

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
              $form->current_date(\%::myconfig), \%::myconfig
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

  #quarter reports
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

  $main::lxdebug->leave_sub();
}

sub get_fiamt_vars {
    return @fiamt_finanzamt;
}

sub get_oldconfig {
  $main::lxdebug->enter_sub();

  my $ret = 0;
  my %oldkeys = (
      'steuernummer' => 'taxnumber',
      'elsterFFFF' => 'fa_bufa_nr',
      'FA_dauerfrist' => 'fa_dauerfrist',
      'FA_steuerberater_city' => 'fa_steuerberater_city',
      'FA_steuerberater_name' => 'fa_steuerberater_name',
      'FA_steuerberater_street' => 'fa_steuerberater_street',
      'FA_steuerberater_tel' => 'fa_steuerberater_tel',
      'FA_voranmeld' => 'fa_voranmeld',
      );

  my $filename = $::lx_office_conf{paths}{userspath}."/finanzamt.ini";
  my $FACONF;
  return unless (open( $FACONF, "<", $filename));

  while (<$FACONF>) {
    last if (/^\[/);
    next if (/^(\#|\s)/);

    # remove comments
    s/\s#.*//g;

    # remove any trailing whitespace
    s/^\s*(.*?)\s*$/$1/;
    my ($key, $value) = split(/=/, $_, 2);

    $main::lxdebug->message(LXDebug->DEBUG2(), "oldkey: ".$key." val=".$value." newkey=".
                          $oldkeys{$key}." oval=".$::form->{$oldkeys{$key}});
    if ( $oldkeys{$key} && $::form->{$oldkeys{$key}} eq '' ) {
        $::form->{$oldkeys{$key}} = $::locale->{iconv_utf8}->convert($value);
        $main::lxdebug->message(LXDebug->DEBUG2(), "set ".$oldkeys{$key}."=".$::form->{$oldkeys{$key}});
        $ret = 1;
    }
  }
  $main::lxdebug->leave_sub();
  return $ret;
}

sub get_config {
    $main::lxdebug->enter_sub();
    my $defaults   = SL::DB::Default->get;
    my @rd_config =  @fiamt_config;
    push @rd_config ,qw(accounting_method coa company address co_ustid duns);
    $::form->{$_} = $defaults->$_ for @rd_config;

    if ( $::form->{taxnumber} eq '' || $::form->{fa_bufa_nr} eq '') {
        #alte finanzamt.ini lesen, ggf abspeichern
        if ( get_oldconfig() ) {
            get_finanzamt();
            save_config();
        }
    }

    my $coa = $::form->{coa};
    $::form->{"COA_$coa"} = '1';
    $::form->{COA_Germany} = '1' if ($coa =~ m/^germany/i);
    $main::lxdebug->leave_sub();
}

sub get_finanzamt {
    $main::lxdebug->enter_sub();
    if ( $::form->{fa_bufa_nr} && $::form->{fa_bufa_nr} ne '' ) {
        my $fiamt =  SL::DB::Finanzamt->_get_manager_class->get_first(
                 query => [ fa_bufa_nr => $::form->{fa_bufa_nr} ]);
        $::form->{$_} = $fiamt->$_ for @fiamt_finanzamt;
    }
    $main::lxdebug->leave_sub();
}

sub save_config {
    $main::lxdebug->enter_sub();
    my $defaults  = SL::DB::Default->get;
    $defaults->$_($::form->{$_}) for @fiamt_config;
    $defaults->save;
    if ( $defaults->fa_bufa_nr ) {
        my $fiamt =  SL::DB::Finanzamt->_get_manager_class->get_first(
                 query => [ fa_bufa_nr => $defaults->fa_bufa_nr ]);
        $fiamt->$_($::form->{$_}) for @fiamt_finanzamt;
        $fiamt->save;
    }
    $main::lxdebug->leave_sub();
}

1;
