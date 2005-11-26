#=====================================================================
# Lx-Office ERP
# Copyright (c) 2004
#
#  Author: Philip Reetz
#   Email: p.reetz@linet-services.de
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
#
# Datev export module
#======================================================================

package DATEV;

use Data::Dumper;

sub get_datev_stamm {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query = qq|SELECT * FROM datev|;
  $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub save_datev_stamm {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  $query = qq|DELETE FROM datev|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|INSERT INTO datev
              (beraternr, beratername, dfvkz, mandantennr, datentraegernr, abrechnungsnr) VALUES
              (|
    . $dbh->quote($form->{beraternr}) . qq|,|
    . $dbh->quote($form->{beratername}) . qq|,|
    . $dbh->quote($form->{dfvkz}) . qq|,
              |
    . $dbh->quote($form->{mandantennr}) . qq|,|
    . $dbh->quote($form->{datentraegernr}) . qq|,|
    . $dbh->quote($form->{abrechnungsnr}) . qq|)|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $sth->finish;

  $dbh->commit;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub kne_export {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $rc;

  if ($form->{exporttype} == 0) {
    $rc = &kne_buchungsexport($myconfig, $form);
  } else {
    $rc = &kne_stammdatenexport($myconfig, $form);
  }

  $main::lxdebug->leave_sub();

  return $rc;
}

sub obe_export {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  $dbh->commit;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub get_dates {
  $main::lxdebug->enter_sub();

  my ($zeitraum, $monat, $quartal, $transdatefrom, $transdateto) = @_;

  $fromto = "transdate >= ";

  my @a = localtime;
  $a[5] += 1900;
  $jahr = $a[5];
  if ($zeitraum eq "monat") {
  SWITCH: {
      $monat eq "1" && do {
        $form->{fromdate} = "1.1.$jahr";
        $form->{todate}   = "31.1.$jahr";
        last SWITCH;
      };
      $monat eq "2" && do {
        $form->{fromdate} = "1.2.$jahr";

        #this works from 1901 to 2099, 1900 and 2100 fail.
        $leap = ($jahr % 4 == 0) ? "29" : "28";
        $form->{todate} = "$leap.2.$jahr";
        last SWITCH;
      };
      $monat eq "3" && do {
        $form->{fromdate} = "1.3.$jahr";
        $form->{todate}   = "31.3.$jahr";
        last SWITCH;
      };
      $monat eq "4" && do {
        $form->{fromdate} = "1.4.$jahr";
        $form->{todate}   = "30.4.$jahr";
        last SWITCH;
      };
      $monat eq "5" && do {
        $form->{fromdate} = "1.5.$jahr";
        $form->{todate}   = "31.5.$jahr";
        last SWITCH;
      };
      $monat eq "6" && do {
        $form->{fromdate} = "1.6.$jahr";
        $form->{todate}   = "30.6.$jahr";
        last SWITCH;
      };
      $monat eq "7" && do {
        $form->{fromdate} = "1.7.$jahr";
        $form->{todate}   = "31.7.$jahr";
        last SWITCH;
      };
      $monat eq "8" && do {
        $form->{fromdate} = "1.8.$jahr";
        $form->{todate}   = "31.8.$jahr";
        last SWITCH;
      };
      $monat eq "9" && do {
        $form->{fromdate} = "1.9.$jahr";
        $form->{todate}   = "30.9.$jahr";
        last SWITCH;
      };
      $monat eq "10" && do {
        $form->{fromdate} = "1.10.$jahr";
        $form->{todate}   = "31.10.$jahr";
        last SWITCH;
      };
      $monat eq "11" && do {
        $form->{fromdate} = "1.11.$jahr";
        $form->{todate}   = "30.11.$jahr";
        last SWITCH;
      };
      $monat eq "12" && do {
        $form->{fromdate} = "1.12.$jahr";
        $form->{todate}   = "31.12.$jahr";
        last SWITCH;
      };
    }
    $fromto .=
      "'" . $form->{fromdate} . "' and transdate <= '" . $form->{todate} . "'";
  }

  elsif ($zeitraum eq "quartal") {
    if ($quartal == 1) {
      $fromto .=
        "'01.01." . $jahr . "' and transdate <= '31.03." . $jahr . "'";
    } elsif ($quartal == 2) {
      $fromto .=
        "'01.04." . $jahr . "' and transdate <= '30.06." . $jahr . "'";
    } elsif ($quartal == 3) {
      $fromto .=
        "'01.07." . $jahr . "' and transdate <= '30.09." . $jahr . "'";
    } elsif ($quartal == 4) {
      $fromto .=
        "'01.10." . $jahr . "' and transdate <= '31.12." . $jahr . "'";
    }
  }

  elsif ($zeitraum eq "zeit") {
    $fromto .=
      "'" . $transdatefrom . "' and transdate <= '" . $transdateto . "'";
  }

  $main::lxdebug->leave_sub();

  return $fromto;
}

sub get_transactions {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form, $fromto) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $fromto =~ s/transdate/ac\.transdate/g;

  $query = qq|SELECT taxkey, rate FROM tax|;
  $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $taxes{ $ref->{taxkey} } = $ref->{rate};
  }

  $sth->finish();

  $query =
    qq|SELECT ac.oid, ac.transdate, ac.trans_id,ar.id, ac.amount, ac.taxkey, ar.invnumber, ar.duedate, ar.amount as umsatz,
              ct.name, c.accno, c.taxkey_id as charttax, c.datevautomatik, c.id, t.chart_id, t.rate FROM acc_trans ac,ar ar, customer ct,
              chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)WHERE $fromto AND ac.trans_id=ar.id AND ac.trans_id=ar.id
              AND ar.customer_id=ct.id AND ac.chart_id=c.id
              UNION ALL
              SELECT ac.oid, ac.transdate, ac.trans_id,ap.id, ac.amount, ac.taxkey, ap.invnumber, ap.duedate, ap.amount as umsatz,
              ct.name, c.accno, c.taxkey_id as charttax, c.datevautomatik, c.id, t.chart_id, t.rate FROM acc_trans ac, ap ap, vendor ct, chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id)
              WHERE $fromto AND ac.trans_id=ap.id AND ap.vendor_id=ct.id AND ac.chart_id=c.id
              UNION ALL
              SELECT ac.oid, ac.transdate, ac.trans_id,gl.id, ac.amount, ac.taxkey, gl.reference AS invnumber, gl.transdate AS duedate, ac.amount as umsatz,
              gl.description AS name, c.accno,  c.taxkey_id as charttax, c.datevautomatik, c.id, t.chart_id, t.rate FROM acc_trans ac, gl gl,
              chart c LEFT JOIN tax t ON
                 (t.chart_id=c.id) WHERE $fromto AND ac.trans_id=gl.id AND ac.chart_id=c.id
              ORDER BY trans_id, oid|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $i = 0;
  $g = 0;
  @splits;
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $count    = 0;
    $firstrun = 1;
    $count += $ref->{amount};
    push @{$i}, $ref;
    while (abs($count) > 0.01 || $firstrun) {
      $ref2 = $sth->fetchrow_hashref(NAME_lc);
      last unless ($ref2);
      $count += $ref2->{amount};
      push @{$i}, $ref2;
      $firstrun = 0;
    }
    $absumsatz = 0;
    if (scalar(@{$i}) > 2) {
      for my $j (0 .. (scalar(@{$i}) - 1)) {
        if (abs($i->[$j]->{'amount'}) > abs($absumsatz)) {
          $absumsatz     = $i->[$j]->{'amount'};
          $notsplitindex = $j;
        }
      }
      $ml = ($i->[0]->{'umsatz'} > 0) ? 1 : -1;
      for my $j (0 .. (scalar(@{$i}) - 1)) {
        if (   ($j != $notsplitindex)
            && ($i->[$j]->{'chart_id'}  eq "")
            && (   $i->[$j]->{'taxkey'} eq ""
                || $i->[$j]->{'taxkey'} eq "0"
                || $i->[$j]->{'taxkey'} eq "1"
                || $i->[$j]->{'taxkey'} eq "10"
                || $i->[$j]->{'taxkey'} eq "11")
          ) {
          my %blubb = {};
          map({ $blubb{$_} = $i->[$notsplitindex]->{$_}; }
              keys(%{ $i->[$notsplitindex] }));
          $absumsatz += $i->[$j]->{'amount'};
          $blubb{'amount'}     = $i->[$j]->{'amount'} * (-1);
          $blubb{'umsatz'}     = abs($i->[$j]->{'amount'}) * $ml;
          $i->[$j]->{'umsatz'} = abs($i->[$j]->{'amount'}) * $ml;
          push @{ $splits[$g] }, \%blubb;    #$i->[$notsplitindex];
          push @{ $splits[$g] }, $i->[$j];
          push @{ $form->{DATEV} }, \@{ $splits[$g] };
          $g++;
          } elsif (($j != $notsplitindex) && ($i->[$j]->{'chart_id'} eq "")) {
          $absumsatz +=
            ($i->[$j]->{'amount'} * (1 + $taxes{ $i->[$j]->{'taxkey'} }));
          my %blubb = {};
          map({ $blubb{$_} = $i->[$notsplitindex]->{$_}; }
              keys(%{ $i->[$notsplitindex] }));
          $test = 1 + $taxes{ $i->[$j]->{'taxkey'} };
          $blubb{'amount'} =
            $form->round_amount(($i->[$j]->{'amount'} * $test * -1), 2);

          #print(STDERR $test, " Taxrate\n\n");
          $blubb{'umsatz'} =
            abs($form->round_amount(($i->[$j]->{'amount'} * $test), 2)) * $ml;

          $i->[$j]->{'umsatz'} =
            abs($form->round_amount(($i->[$j]->{'amount'} * $test), 2)) * $ml;

          #print(STDERR $i->[$j]->{'umsatz'}, " Steuer Umsatz\n");
          #print(STDERR $i->[$j]->{'amount'}, " Steuer Betrag\n");
          #print(STDERR $blubb{'umsatz'}, " Umsatz NOTSPLIT\n");
          push @{ $splits[$g] }, \%blubb;
          push @{ $splits[$g] }, $i->[$j];
          push @{ $form->{DATEV} }, \@{ $splits[$g] };
          $g++;
          } else {
          next;
        }
      }
      if (abs($absumsatz) > 0.01) {
        print(STDERR $absumsatz, "ABSAUMSATZ\n");
        $form->error("Datev-Export fehlgeschlagen!");
      }
    } else {
      push @{ $form->{DATEV} }, \@{$i};
    }
    $i++;
  }
  $sth->finish;
  $dbh->disconnect;

  $main::lxdebug->leave_sub();
}

sub make_kne_data_header {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form, $fromto) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my @a = localtime;
  $jahr = $a[5];

  #Header
  $anwendungsnr = ($fromto) ? "\x31\x31" : "\x31\x33";
  while (length($form->{datentraegernr}) < 3) {
    $form->{datentraegernr} = "\x30" . $form->{datentraegernr};
  }

  $header = "\x1D\x18\x31" . $form->{datentraegernr} . $anwendungsnr;

  $dfvkz = $form->{dfvkz};
  while (length($dfvkz) < 2) {
    $dfvkz = "\x30" . $dfvkz;
  }
  $header .= $dfvkz;

  $beraternr = $form->{beraternr};
  while (length($beraternr) < 7) {
    $beraternr = "\x30" . $beraternr;
  }
  $header .= $beraternr;

  $mandantennr = $form->{mandantennr};
  while (length($mandantennr) < 5) {
    $mandantennr = "\x30" . $mandantennr;
  }
  $header .= $mandantennr;

  $abrechnungsnr = $form->{abrechnungsnr} . $jahr;
  while (length($abrechnungsnr) < 6) {
    $abrechnungsnr = "\x30" . $abrechnungsnr;
  }
  $header .= $abrechnungsnr;

  $fromto =~ s/transdate|>=|and|\'|<=//g;
  my ($from, $to) = split /   /, $fromto;
  $from =~ s/ //g;
  $to   =~ s/ //g;

  if ($from ne "") {
    my ($fday, $fmonth, $fyear) = split /\./, $from;
    if (length($fmonth) < 2) {
      $fmonth = "0" . $fmonth;
    }
    if (length($fday) < 2) {
      $fday = "0" . $fday;
    }
    $from = $fday . $fmonth . substr($fyear, -2, 2);
  } else {
    $from = "";
  }

  $header .= $from;

  if ($to ne "") {
    my ($tday, $tmonth, $tyear) = split /\./, $to;
    if (length($tmonth) < 2) {
      $tmonth = "0" . $tmonth;
    }
    if (length($tday) < 2) {
      $tday = "0" . $tday;
    }
    $to = $tday . $tmonth . substr($tyear, -2, 2);
  } else {
    $to = "";
  }
  $header .= $to;
  if ($fromto ne "") {
    $primanota = "\x30\x30\x31";
    $header .= $primanota;
  }

  $passwort = $form->{passwort};
  while (length($passwort) < 4) {
    $passwort = "\x30" . $passwort;
  }
  $header .= $passwort;

  $anwendungsinfo = "\x20" x 16;
  $header .= $anwendungsinfo;
  $inputinfo = "\x20" x 16;
  $header .= $inputinfo;

  $header .= "\x79";

  #Versionssatz
  if ($form->{exporttype} == 0) {
    $versionssatz = "\xB5" . "1,";
  } else {
    $versionssatz = "\xB6" . "1,";
  }

  $query = qq| select accno from chart limit 1|;
  $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my $ref = $sth->fetchrow_hashref(NAME_lc);

  $accnolength = $ref->{accno};
  $sth->finish;

  $versionssatz .= length($accnolength);
  $versionssatz .= ",";
  $versionssatz .= length($accnolength);
  $versionssatz .= ",SELF" . "\x1C\x79";

  $dbh->disconnect;

  $header .= $versionssatz;

  $main::lxdebug->leave_sub();

  return $header;
}

sub datetofour {
  $main::lxdebug->enter_sub();

  my ($date, $six) = @_;

  ($day, $month, $year) = split /\./, $date;

  if ($day =~ /^0/) {
    $day = substr($day, 1, 1);
  }
  if (length($month) < 2) {
    $month = "0" . $month;
  }
  if (length($year) > 2) {
    $year = substr($year, -2, 2);
  }

  if ($six) {
    $date = $day . $month . $year;
  } else {
    $date = $day . $month;
  }

  $main::lxdebug->leave_sub();

  return $date;
}

sub formatumsatz {
  $main::lxdebug->enter_sub();

  my ($umsatz, $stellen) = @_;

  $umsatz =~ s/-//;
  ($vorkomma, $nachkomma) = split /\./, $umsatz;
  $umsatz = "";
  if ($stellen > 0) {
    for ($i = $stellen; $i >= $stellen + 2 - length($vorkomma); $i--) {
      $umsatz .= "0";
    }
  }
  for ($i = 3; $i > length($nachkomma); $i--) {
    $nachkomma .= "0";
  }
  $umsatz = $vorkomma . substr($nachkomma, 0, 2);

  $main::lxdebug->leave_sub();

  return $umsatz;
}

sub make_ed_versionset {
  $main::lxdebug->enter_sub();

  my ($header, $filename, $blockcount, $fromto) = @_;

  $versionset = "V" . substr($filename, 2, 5);
  $versionset .= substr($header, 6, 22);
  if ($fromto ne "") {
    $versionset .= "0000" . substr($header, 28, 19);
  } else {
    $datum = "\x20" x 16;
    $versionset .= $datum . "001" . substr($header, 28, 4);
  }
  while (length($blockcount) < 5) {
    $blockcount = "0" . $blockcount;
  }
  $versionset .= $blockcount;
  $versionset .= "001";
  $versionset .= "\x20\x31";
  $versionset .= substr($header, -12, 10) . "    ";
  $versionset .= "\x20" x 53;

  $main::lxdebug->leave_sub();

  return $versionset;
}

sub make_ev_header {
  $main::lxdebug->enter_sub();

  my ($form, $fileno) = @_;
  $datentraegernr = $form->{datentraegernr};
  $beraternummer  = $form->{beraternr};
  $beratername    = $form->{beratername};
  $anzahl_dateien = $fileno;

  while (length($datentraegernr) < 3) {
    $datentraegernr .= " ";
  }

  while (length($beraternummer) < 7) {
    $beraternummer .= " ";
  }

  while (length($beratername) < 9) {
    $beratername .= " ";
  }

  while (length($anzahl_dateien) < 5) {
    $anzahl_dateien = "0" . $anzahl_dateien;
  }

  $ev_header =
    $datentraegernr . "\x20\x20\x20" . $beraternummer . $beratername . "\x20";
  $ev_header .= $anzahl_dateien . $anzahl_dateien;
  $ev_header .= "\x20" x 95;

  $main::lxdebug->leave_sub();

  return $ev_header;
}

sub kne_buchungsexport {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form) = @_;

  my $export_path = "datev/";
  my $filename    = "ED00000";
  my $evfile      = "EV01";
  my @ed_versionsets;
  my $fileno = 0;

  $fromto =
    &get_dates($form->{zeitraum}, $form->{monat},
               $form->{quartal},  $form->{transdatefrom},
               $form->{transdateto});
  &get_transactions($myconfig, $form, $fromto);

  while (scalar(@{ $form->{DATEV} })) {
    my $blockcount      = 1;
    my $remaining_bytes = 256;
    my $total_bytes     = 256;
    my $umsatzsumme     = 0;
    my $buchungssatz    = "";
    $filename++;
    my $ed_filename = $export_path . $filename;
    open(ED, "> $ed_filename") or die "can't open outputfile: $!\n";
    $header = &make_kne_data_header($myconfig, $form, $fromto);
    $remaining_bytes -= length($header);

    while (scalar(@{ $form->{DATEV} }) > 0) {
      $transaction    = shift @{ $form->{DATEV} };
      $trans_lines    = scalar(@{$transaction});
      $umsatz         = 0;
      $gegenkonto     = "";
      $konto          = "";
      $belegfeld1     = "";
      $datum          = "";
      $waehrung       = "";
      $buchungstext   = "";
      $belegfeld2     = "";
      $datevautomatik = 0;
      $taxkey         = 0;
      $charttax       = 0;
      %umlaute = ('ä' => 'ae',
                  'ö' => 'oe',
                  'ü' => 'ue',
                  'Ä' => 'Ae',
                  'Ö' => 'Oe',
                  'Ü' => 'Ue',
                  'ß' => 'sz');

      for (my $i = 0; $i < $trans_lines; $i++) {
        if (abs($transaction->[$i]->{'umsatz'}) > abs($umsatz)) {
          $umsatz = $transaction->[$i]->{'umsatz'};
        }
        if ($transaction->[$i]->{'datevautomatik'}) {
          $datevautomatik = 1;
        }
        if ($transaction->[$i]->{'taxkey'}) {
          $taxkey = $transaction->[$i]->{'taxkey'};
        }
        if ($transaction->[$i]->{'charttax'}) {
          $charttax = $transaction->[$i]->{'charttax'};
        }
        if (   ($transaction->[$i]->{'id'} eq $transaction->[$i]->{'chart_id'})
            && ($trans_lines > 2)) {
          undef($transaction->[$i]);
            } elsif ($transaction->[$i]->{'amount'} > 0) {
          $haben = $i;
            } else {
          $soll = $i;
        }
      }

      $umsatzsumme += abs($umsatz);

      # Umwandlung von Umlauten und Sonderzeichen in erlaubte Zeichen bei Textfeldern
      foreach $umlaut (keys(%umlaute)) {
        $transaction->[$haben]->{'invnumber'} =~
          s/${umlaut}/${umlaute{$umlaut}}/g;
        $transaction->[$haben]->{'name'} =~ s/${umlaut}/${umlaute{$umlaut}}/g;
      }

      $transaction->[$haben]->{'invnumber'} =~ s/[^0-9A-Za-z\$\%\&\*\+\-\/]//g;
      $transaction->[$haben]->{'name'} =~ s/[^0-9A-Za-z\$\%\&\*\+\-\ \/]//g;

      $transaction->[$haben]->{'invnumber'} =
        substr($transaction->[$haben]->{'invnumber'}, 0, 12);
      $transaction->[$haben]->{'name'} =
        substr($transaction->[$haben]->{'name'}, 0, 30);
      $transaction->[$haben]->{'invnumber'} =~ s/\ *$//;
      $transaction->[$haben]->{'name'}      =~ s/\ *$//;

      if ($trans_lines >= 2) {

        $gegenkonto = "a" . $transaction->[$haben]->{'accno'};
        $konto      = "e" . $transaction->[$soll]->{'accno'};
        if ($transaction->[$haben]->{'invnumber'} ne "") {
          $belegfeld1 =
            "\xBD" . $transaction->[$haben]->{'invnumber'} . "\x1C";
        }
        $datum = "d";
        $datum .= &datetofour($transaction->[$haben]->{'transdate'}, 0);
        $waehrung = "\xB3" . "EUR" . "\x1C";
        if ($transaction->[$haben]->{'name'} ne "") {
          $buchungstext = "\x1E" . $transaction->[$haben]->{'name'} . "\x1C";
        }
        if ($transaction->[$haben]->{'duedate'} ne "") {
          $belegfeld2 = "\xBE"
            . &datetofour($transaction->[$haben]->{'duedate'}, 1) . "\x1C";
        }
      }

      if (($remaining_bytes - length("+" . &formatumsatz($umsatz, 0))) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $umsatz = abs($umsatz);
      $vorzeichen = ($umsatz > 0) ? "+" : "-";
      $buchungssatz .= $vorzeichen . &formatumsatz($umsatz, 0);
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

      if ( ($taxkey || $datevautomatik)
        && (!$datevautomatik || ($datevautomatik && ($charttax ne $taxkey)))) {
        if (($remaining_bytes - length("\x6C" . "11")) <= 6) {
          $fuellzeichen =
            ($blockcount * 256 - length($buchungssatz . $header));
          $buchungssatz .= "\x00" x $fuellzeichen;
          $blockcount++;
          $total_bytes = ($blockcount) * 256;
        }
        if (!$datevautomatik) {
          $buchungssatz .= "\x6C" . $taxkey;
        } else {
          $buchungssatz .= "\x6C" . "4";
        }
        $remaining_bytes = $total_bytes - length($buchungssatz . $header);
      }

      if (($remaining_bytes - length($gegenkonto)) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $buchungssatz .= $gegenkonto;
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

      if (($remaining_bytes - length($belegfeld1)) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $buchungssatz .= $belegfeld1;
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

      if (($remaining_bytes - length($belegfeld2)) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $buchungssatz .= $belegfeld2;
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

      if (($remaining_bytes - length($datum)) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $buchungssatz .= $datum;
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

      if (($remaining_bytes - length($konto)) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $buchungssatz .= $konto;
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

      if (($remaining_bytes - length($buchungstext)) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $buchungssatz .= $buchungstext;
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

      if (($remaining_bytes - (length($waehrung . "\x79"))) <= 6) {
        $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
        $buchungssatz .= "\x00" x $fuellzeichen;
        $blockcount++;
        $total_bytes = ($blockcount) * 256;
      }
      $buchungssatz .= $waehrung . "\x79";
      $remaining_bytes = $total_bytes - length($buchungssatz . $header);

    }

    $mandantenendsumme =
      "x" . &formatumsatz($umsatzsumme, 14) . "\x79" . "\x7a";
    $fuellzeichen =
      256 - (length($header . $buchungssatz . $mandantenendsumme) % 256);
    $dateiende = "\x00" x $fuellzeichen;
    print(ED $header);
    print(ED $buchungssatz);
    print(ED $mandantenendsumme);
    print(ED $dateiende);
    close(ED);

    $ed_versionset[$fileno] =
      &make_ed_versionset($header, $filename, $blockcount, $fromto);
    $fileno++;
  }

  #Make EV Verwaltungsdatei
  $ev_header = &make_ev_header($form, $fileno);
  $ev_filename = $export_path . $evfile;
  open(EV, "> $ev_filename") or die "can't open outputfile: EV01\n";
  print(EV $ev_header);

  foreach $file (@ed_versionset) {
    print(EV $ed_versionset[$file]);
  }
  close(EV);
  ###
  $main::lxdebug->leave_sub();
}

sub kne_stammdatenexport {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form) = @_;
  $form->{abrechnungsnr} = "99";

  my $export_path = "datev/";
  my $filename    = "ED00000";
  my $evfile      = "EV01";
  my @ed_versionsets;
  my $fileno          = 1;
  my $i               = 0;
  my $blockcount      = 1;
  my $remaining_bytes = 256;
  my $total_bytes     = 256;
  my $buchungssatz    = "";
  $filename++;
  my $ed_filename = $export_path . $filename;
  open(ED, "> $ed_filename") or die "can't open outputfile: $!\n";
  $header = &make_kne_data_header($myconfig, $form, "");
  $remaining_bytes -= length($header);

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  $query =
    qq|SELECT c.accno, c.description FROM chart c WHERE c.accno >=|
    . $dbh->quote($form->{accnofrom}) . qq|
           AND c.accno <= |
    . $dbh->quote($form->{accnoto})
    . qq| ORDER BY c.accno|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($remaining_bytes - length("t" . $ref->{'accno'})) <= 6) {
      $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
      $buchungssatz .= "\x00" x $fuellzeichen;
      $blockcount++;
      $total_bytes = ($blockcount) * 256;
    }
    $buchungssatz .= "t" . $ref->{'accno'};
    $remaining_bytes = $total_bytes - length($buchungssatz . $header);
    $ref->{'description'} =~ s/[^0-9A-Za-z\$\%\&\*\+\-\/]//g;
    $ref->{'description'} = substr($ref->{'description'}, 0, 40);
    $ref->{'description'} =~ s/\ *$//;

    if (
        ($remaining_bytes - length("\x1E" . $ref->{'description'} . "\x1C\x79")
        ) <= 6
      ) {
      $fuellzeichen = ($blockcount * 256 - length($buchungssatz . $header));
      $buchungssatz .= "\x00" x $fuellzeichen;
      $blockcount++;
      $total_bytes = ($blockcount) * 256;
    }
    $buchungssatz .= "\x1E" . $ref->{'description'} . "\x1C\x79";
    $remaining_bytes = $total_bytes - length($buchungssatz . $header);
  }

  $sth->finish;
  print(ED $header);
  print(ED $buchungssatz);
  $fuellzeichen = 256 - (length($header . $buchungssatz . "z") % 256);
  $dateiende = "\x00" x $fuellzeichen;
  print(ED "z");
  print(ED $dateiende);
  close(ED);

  #Make EV Verwaltungsdatei
  $ed_versionset[0] =
    &make_ed_versionset($header, $filename, $blockcount, $fromto);

  $ev_header = &make_ev_header($form, $fileno);
  $ev_filename = $export_path . $evfile;
  open(EV, "> $ev_filename") or die "can't open outputfile: EV01\n";
  print(EV $ev_header);

  foreach $file (@ed_versionset) {
    print(EV $ed_versionset[$file]);
  }
  close(EV);

  $dbh->disconnect;
  ###

  $main::lxdebug->leave_sub();
}

1;
