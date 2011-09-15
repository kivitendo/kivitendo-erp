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

use utf8;
use strict;

use SL::DBUtils;
use SL::DATEV::KNEFile;
use SL::Taxkeys;

use Data::Dumper;
use File::Path;
use List::Util qw(max);
use Time::HiRes qw(gettimeofday);

sub _get_export_path {
  $main::lxdebug->enter_sub();

  my ($a, $b) = gettimeofday();
  my $path    = get_path_for_download_token("${a}-${b}-${$}");

  mkpath($path) unless (-d $path);

  $main::lxdebug->leave_sub();

  return $path;
}

sub get_path_for_download_token {
  $main::lxdebug->enter_sub();

  my $token = shift;
  my $path;

  if ($token =~ m|^(\d+)-(\d+)-(\d+)$|) {
    $path = $::lx_office_conf{paths}->{userspath} . "/datev-export-${1}-${2}-${3}";
  }

  $main::lxdebug->leave_sub();

  return $path;
}

sub get_download_token_for_path {
  $main::lxdebug->enter_sub();

  my $path = shift;
  my $token;

  if ($path =~ m|.*datev-export-(\d+)-(\d+)-(\d+)/?$|) {
    $token = "${1}-${2}-${3}";
  }

  $main::lxdebug->leave_sub();

  return $token;
}

sub clean_temporary_directories {
  $main::lxdebug->enter_sub();

  foreach my $path (glob($::lx_office_conf{paths}->{userspath} . "/datev-export-*")) {
    next unless (-d $path);

    my $mtime = (stat($path))[9];
    next if ((time() - $mtime) < 8 * 60 * 60);

    rmtree $path;
  }

  $main::lxdebug->leave_sub();
}

sub _fill {
  $main::lxdebug->enter_sub();

  my $text      = shift;
  my $field_len = shift;
  my $fill_char = shift;
  my $alignment = shift || 'right';

  my $text_len  = length $text;

  if ($field_len < $text_len) {
    $text = substr $text, 0, $field_len;

  } elsif ($field_len > $text_len) {
    my $filler = ($fill_char) x ($field_len - $text_len);
    $text      = $alignment eq 'right' ? $filler . $text : $text . $filler;
  }

  $main::lxdebug->leave_sub();

  return $text;
}

sub get_datev_stamm {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT * FROM datev|;
  my $sth   = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref("NAME_lc");

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

  my $query = qq|DELETE FROM datev|;
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
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  $sth->finish;

  $dbh->commit;
  $dbh->disconnect;
  $main::lxdebug->leave_sub();
}

sub kne_export {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $result;

  if ($form->{exporttype} == 0) {
    $result = kne_buchungsexport($myconfig, $form);
  } else {
    $result = kne_stammdatenexport($myconfig, $form);
  }

  $main::lxdebug->leave_sub();

  return $result;
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
  my ($fromto, $jahr, $leap);

  my $form = $main::form;

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
    $fromto            .= "'" . $transdatefrom . "' and transdate <= '" . $transdateto . "'";
    my ($yy, $mm, $dd)  = $main::locale->parse_date(\%main::myconfig, $transdatefrom);
    $jahr               = $yy;
  }

  $main::lxdebug->leave_sub();

  return ($fromto, $jahr);
}

sub _sign {
  my $value = shift;

  return $value < 0 ? -1
    :    $value > 0 ?  1
    :                  0;
}

sub _get_transactions {
  $main::lxdebug->enter_sub();

  my $fromto   =  shift;

  my $myconfig =  \%main::myconfig;
  my $form     =  $main::form;

  my $dbh      =  $form->get_standard_dbh($myconfig);

  my ($notsplitindex);
  my @errors   = ();

  $form->{net_gross_differences}     = [];
  $form->{sum_net_gross_differences} = 0;

  $fromto      =~ s/transdate/ac\.transdate/g;

  my $taxkeys  = Taxkeys->new();
  my $filter   = '';            # Useful for debugging purposes

  my %all_taxchart_ids = selectall_as_map($form, $dbh, qq|SELECT DISTINCT chart_id, TRUE AS is_set FROM tax|, 'chart_id', 'is_set');

  my $query    =
    qq|SELECT ac.acc_trans_id, ac.transdate, ac.trans_id,ar.id, ac.amount, ac.taxkey,
         ar.invnumber, ar.duedate, ar.amount as umsatz,
         ct.name,
         c.accno, c.taxkey_id as charttax, c.datevautomatik, c.id, c.link,
         ar.invoice
       FROM acc_trans ac
       LEFT JOIN ar          ON (ac.trans_id    = ar.id)
       LEFT JOIN customer ct ON (ar.customer_id = ct.id)
       LEFT JOIN chart c     ON (ac.chart_id    = c.id)
       WHERE (ar.id IS NOT NULL)
         AND $fromto
         $filter

       UNION ALL

       SELECT ac.acc_trans_id, ac.transdate, ac.trans_id,ap.id, ac.amount, ac.taxkey,
         ap.invnumber, ap.duedate, ap.amount as umsatz,
         ct.name,
         c.accno, c.taxkey_id as charttax, c.datevautomatik, c.id, c.link,
         ap.invoice
       FROM acc_trans ac
       LEFT JOIN ap        ON (ac.trans_id  = ap.id)
       LEFT JOIN vendor ct ON (ap.vendor_id = ct.id)
       LEFT JOIN chart c   ON (ac.chart_id  = c.id)
       WHERE (ap.id IS NOT NULL)
         AND $fromto
         $filter

       UNION ALL

       SELECT ac.acc_trans_id, ac.transdate, ac.trans_id,gl.id, ac.amount, ac.taxkey,
         gl.reference AS invnumber, gl.transdate AS duedate, ac.amount as umsatz,
         gl.description AS name,
         c.accno, c.taxkey_id as charttax, c.datevautomatik, c.id, c.link,
         FALSE AS invoice
       FROM acc_trans ac
       LEFT JOIN gl      ON (ac.trans_id  = gl.id)
       LEFT JOIN chart c ON (ac.chart_id  = c.id)
       WHERE (gl.id IS NOT NULL)
         AND $fromto
         $filter

       ORDER BY trans_id, acc_trans_id|;

  my $sth = prepare_execute_query($form, $dbh, $query);
  $form->{DATEV} = [];

  my $counter = 0;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    $counter++;
    if (($counter % 500) == 0) {
      print("$counter ");
    }

    my $trans    = [ $ref ];

    my $count    = $ref->{amount};
    my $firstrun = 1;
    my $subcent  = abs($count) < 0.02;

    while (abs($count) > 0.01 || $firstrun || ($subcent && abs($count) > 0.005)) {
      my $ref2 = $sth->fetchrow_hashref("NAME_lc");
      last unless ($ref2);

      if ($ref2->{trans_id} != $trans->[0]->{trans_id}) {
        $form->error("Unbalanced ledger! old trans_id " . $trans->[0]->{trans_id} . " new trans_id " . $ref2->{trans_id} . " count $count");
        ::end_of_request();
      }

      push @{ $trans }, $ref2;

      $count    += $ref2->{amount};
      $firstrun  = 0;
    }

    foreach my $i (0 .. scalar(@{ $trans }) - 1) {
      my $ref        = $trans->[$i];
      my $prev_ref   = 0 < $i ? $trans->[$i - 1] : undef;
      if (   $all_taxchart_ids{$ref->{id}}
          && ($ref->{link} =~ m/(?:AP_tax|AR_tax)/)
          && (   ($prev_ref && $prev_ref->{taxkey} && (_sign($ref->{amount}) == _sign($prev_ref->{amount})))
              || $ref->{invoice})) {
        $ref->{is_tax} = 1;
      }

      if (   !$ref->{invoice}
          &&  $ref->{is_tax}
          && !($prev_ref->{is_tax})
          &&  (_sign($ref->{amount}) == _sign($prev_ref->{amount}))) {
        $trans->[$i - 1]->{tax_amount} = $ref->{amount};
      }
    }

    my %taxid_taxkeys = ();
    my $absumsatz     = 0;
    if (scalar(@{$trans}) <= 2) {
      push @{ $form->{DATEV} }, $trans;
      next;
    }

    for my $j (0 .. (scalar(@{$trans}) - 1)) {
      if (abs($trans->[$j]->{'amount'}) > abs($absumsatz)) {
        $absumsatz     = $trans->[$j]->{'amount'};
        $notsplitindex = $j;
      }
    }

    my $ml             = ($trans->[0]->{'umsatz'} > 0) ? 1 : -1;
    my $rounding_error = 0;
    my @taxed;

    for my $j (0 .. (scalar(@{$trans}) - 1)) {
      if (   ($j != $notsplitindex)
          && !$trans->[$j]->{is_tax}
          && (   $trans->[$j]->{'taxkey'} eq ""
              || $trans->[$j]->{'taxkey'} eq "0"
              || $trans->[$j]->{'taxkey'} eq "1"
              || $trans->[$j]->{'taxkey'} eq "10"
              || $trans->[$j]->{'taxkey'} eq "11")) {
        my %new_trans = ();
        map { $new_trans{$_} = $trans->[$notsplitindex]->{$_}; } keys %{ $trans->[$notsplitindex] };

        $absumsatz               += $trans->[$j]->{'amount'};
        $new_trans{'amount'}      = $trans->[$j]->{'amount'} * (-1);
        $new_trans{'umsatz'}      = abs($trans->[$j]->{'amount'}) * $ml;
        $trans->[$j]->{'umsatz'}  = abs($trans->[$j]->{'amount'}) * $ml;

        push @{ $form->{DATEV} }, [ \%new_trans, $trans->[$j] ];

      } elsif (($j != $notsplitindex) && !$trans->[$j]->{is_tax}) {
        my %tax_info = $taxkeys->get_full_tax_info('transdate' => $trans->[$j]->{transdate});

        my %new_trans = ();
        map { $new_trans{$_} = $trans->[$notsplitindex]->{$_}; } keys %{ $trans->[$notsplitindex] };

        my $tax_rate              = $tax_info{taxkeys}->{ $trans->[$j]->{'taxkey'} }->{taxrate};
        $new_trans{'net_amount'}  = $trans->[$j]->{'amount'} * -1;
        $new_trans{'tax_rate'}    = 1 + $tax_rate;

        if (!$trans->[$j]->{'invoice'}) {
          $new_trans{'amount'}      = $form->round_amount(-1 * ($trans->[$j]->{amount} + $trans->[$j]->{tax_amount}), 2);
          $new_trans{'umsatz'}      = abs($new_trans{'amount'}) * $ml;
          $trans->[$j]->{'umsatz'}  = $new_trans{'umsatz'};
          $absumsatz               += -1 * $new_trans{'amount'};

        } else {
          my $unrounded             = $trans->[$j]->{'amount'} * (1 + $tax_rate) * -1 + $rounding_error;
          my $rounded               = $form->round_amount($unrounded, 2);

          $rounding_error           = $unrounded - $rounded;
          $new_trans{'amount'}      = $rounded;
          $new_trans{'umsatz'}      = abs($rounded) * $ml;
          $trans->[$j]->{'umsatz'}  = $new_trans{umsatz};
          $absumsatz               -= $rounded;
        }

        push @{ $form->{DATEV} }, [ \%new_trans, $trans->[$j] ];
        push @taxed, $form->{DATEV}->[-1];
      }
    }

    my $idx        = 0;
    my $correction = 0;
    while ((abs($absumsatz) >= 0.01) && (abs($absumsatz) < 1.00)) {
      if ($idx >= scalar @taxed) {
        last if (!$correction);

        $correction = 0;
        $idx        = 0;
      }

      my $transaction = $taxed[$idx]->[0];

      my $old_amount     = $transaction->{amount};
      my $old_correction = $correction;
      my @possible_diffs;

      if (!$transaction->{diff}) {
        @possible_diffs = (0.01, -0.01);
      } else {
        @possible_diffs = ($transaction->{diff});
      }

      foreach my $diff (@possible_diffs) {
        my $net_amount = $form->round_amount(($transaction->{amount} + $diff) / $transaction->{tax_rate}, 2);
        next if ($net_amount != $transaction->{net_amount});

        $transaction->{diff}    = $diff;
        $transaction->{amount} += $diff;
        $transaction->{umsatz} += $diff;
        $absumsatz             -= $diff;
        $correction             = 1;

        last;
      }

      $idx++;
    }

    $absumsatz = $form->round_amount($absumsatz, 2);
    if (abs($absumsatz) >= (0.01 * (1 + scalar @taxed))) {
      push @errors, "Datev-Export fehlgeschlagen! Bei Transaktion $trans->[0]->{trans_id} ($absumsatz)\n";

    } elsif (abs($absumsatz) >= 0.01) {
      push @{ $form->{net_gross_differences} }, $absumsatz;
      $form->{sum_net_gross_differences} += $absumsatz;
    }
  }

  $sth->finish();

  $form->error(join("<br>\n", @errors)) if (@errors);

  $main::lxdebug->leave_sub();
}

sub make_kne_data_header {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form, $fromto, $start_jahr) = @_;
  my ($primanota);

  my $jahr = $start_jahr;
  if (!$jahr) {
    my @a = localtime;
    $jahr = $a[5];
  }

  #Header
  my $header  = "\x1D\x181";
  $header    .= _fill($form->{datentraegernr}, 3, ' ', 'left');
  $header    .= ($fromto) ? "11" : "13"; # Anwendungsnummer
  $header    .= _fill($form->{dfvkz}, 2, '0');
  $header    .= _fill($form->{beraternr}, 7, '0');
  $header    .= _fill($form->{mandantennr}, 5, '0');
  $header    .= _fill($form->{abrechnungsnr} . $jahr, 6, '0');

  $fromto         =~ s/transdate|>=|and|\'|<=//g;
  my ($from, $to) =  split /   /, $fromto;
  $from           =~ s/ //g;
  $to             =~ s/ //g;

  if ($from ne "") {
    my ($fday, $fmonth, $fyear) = split(/\./, $from);
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
    my ($tday, $tmonth, $tyear) = split(/\./, $to);
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
    $primanota = "001";
    $header .= $primanota;
  }

  $header .= _fill($form->{passwort}, 4, '0');
  $header .= " " x 16;       # Anwendungsinfo
  $header .= " " x 16;       # Inputinfo
  $header .= "\x79";

  #Versionssatz
  my $versionssatz  = $form->{exporttype} == 0 ? "\xB5" . "1," : "\xB6" . "1,";

  my $dbh           = $form->get_standard_dbh($myconfig);
  my $query         = qq|SELECT accno FROM chart LIMIT 1|;
  my $ref           = selectfirst_hashref_query($form, $dbh, $query);

  $versionssatz    .= length $ref->{accno};
  $versionssatz    .= ",";
  $versionssatz    .= length $ref->{accno};
  $versionssatz    .= ",SELF" . "\x1C\x79";

  $header          .= $versionssatz;

  $main::lxdebug->leave_sub();

  return $header;
}

sub datetofour {
  $main::lxdebug->enter_sub();

  my ($date, $six) = @_;

  my ($day, $month, $year) = split(/\./, $date);

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

sub trim_leading_zeroes {
  my $str = shift;

  $str =~ s/^0+//g;

  return $str;
}

sub make_ed_versionset {
  $main::lxdebug->enter_sub();

  my ($header, $filename, $blockcount, $fromto) = @_;

  my $versionset  = "V" . substr($filename, 2, 5);
  $versionset    .= substr($header, 6, 22);

  if ($fromto ne "") {
    $versionset .= "0000" . substr($header, 28, 19);
  } else {
    my $datum = " " x 16;
    $versionset .= $datum . "001" . substr($header, 28, 4);
  }

  $versionset .= _fill($blockcount, 5, '0');
  $versionset .= "001";
  $versionset .= " 1";
  $versionset .= substr($header, -12, 10) . "    ";
  $versionset .= " " x 53;

  $main::lxdebug->leave_sub();

  return $versionset;
}

sub make_ev_header {
  $main::lxdebug->enter_sub();

  my ($form, $fileno) = @_;

  my $ev_header  = _fill($form->{datentraegernr}, 3, ' ', 'left');
  $ev_header    .= "   ";
  $ev_header    .= _fill($form->{beraternr}, 7, ' ', 'left');
  $ev_header    .= _fill($form->{beratername}, 9, ' ', 'left');
  $ev_header    .= " ";
  $ev_header    .= (_fill($fileno, 5, '0')) x 2;
  $ev_header    .= " " x 95;

  $main::lxdebug->leave_sub();

  return $ev_header;
}

sub kne_buchungsexport {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form) = @_;

  my @filenames;

  my $export_path = _get_export_path() . "/";
  my $filename    = "ED00000";
  my $evfile      = "EV01";
  my @ed_versionset;
  my $fileno = 0;

  $form->header;
  print qq|
  <html>
  <body>Export in Bearbeitung<br>
  Buchungss&auml;tze verarbeitet:
|;

  my ($fromto, $start_jahr) =
    &get_dates($form->{zeitraum}, $form->{monat},
               $form->{quartal},  $form->{transdatefrom},
               $form->{transdateto});
  _get_transactions($fromto);
  my $counter = 0;
  print qq|<br>2. Durchlauf:|;
  while (scalar(@{ $form->{DATEV} })) {
    my $umsatzsumme = 0;
    $filename++;
    my $ed_filename = $export_path . $filename;
    push(@filenames, $filename);
    my $header = &make_kne_data_header($myconfig, $form, $fromto, $start_jahr);

    my $kne_file = SL::DATEV::KNEFile->new();
    $kne_file->add_block($header);

    while (scalar(@{ $form->{DATEV} }) > 0) {
      my $transaction = shift @{ $form->{DATEV} };
      my $trans_lines = scalar(@{$transaction});
      $counter++;
      if (($counter % 500) == 0) {
        print("$counter ");
      }

      my $umsatz         = 0;
      my $gegenkonto     = "";
      my $konto          = "";
      my $belegfeld1     = "";
      my $datum          = "";
      my $waehrung       = "";
      my $buchungstext   = "";
      my $belegfeld2     = "";
      my $datevautomatik = 0;
      my $taxkey         = 0;
      my $charttax       = 0;
      my ($haben, $soll);
      my $iconv          = $::locale->{iconv_utf8};
      my %umlaute = ($iconv->convert('ä') => 'ae',
                     $iconv->convert('ö') => 'oe',
                     $iconv->convert('ü') => 'ue',
                     $iconv->convert('Ä') => 'Ae',
                     $iconv->convert('Ö') => 'Oe',
                     $iconv->convert('Ü') => 'Ue',
                     $iconv->convert('ß') => 'sz');
      for (my $i = 0; $i < $trans_lines; $i++) {
        if ($trans_lines == 2) {
          if (abs($transaction->[$i]->{'amount'}) > abs($umsatz)) {
            $umsatz = $transaction->[$i]->{'amount'};
          }
        } else {
          if (abs($transaction->[$i]->{'umsatz'}) > abs($umsatz)) {
            $umsatz = $transaction->[$i]->{'umsatz'};
          }
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
        if ($transaction->[$i]->{'amount'} > 0) {
          $haben = $i;
        } else {
          $soll = $i;
        }
      }

      # Umwandlung von Umlauten und Sonderzeichen in erlaubte Zeichen bei Textfeldern
      foreach my $umlaut (keys(%umlaute)) {
        $transaction->[$haben]->{'invnumber'} =~ s/${umlaut}/${umlaute{$umlaut}}/g;
        $transaction->[$haben]->{'name'}      =~ s/${umlaut}/${umlaute{$umlaut}}/g;
      }

      $transaction->[$haben]->{'invnumber'} =~ s/[^0-9A-Za-z\$\%\&\*\+\-\/]//g;
      $transaction->[$haben]->{'name'}      =~ s/[^0-9A-Za-z\$\%\&\*\+\-\ \/]//g;

      $transaction->[$haben]->{'invnumber'} =  substr($transaction->[$haben]->{'invnumber'}, 0, 12);
      $transaction->[$haben]->{'name'}      =  substr($transaction->[$haben]->{'name'}, 0, 30);
      $transaction->[$haben]->{'invnumber'} =~ s/\ *$//;
      $transaction->[$haben]->{'name'}      =~ s/\ *$//;

      if ($trans_lines >= 2) {

        $gegenkonto = "a" . trim_leading_zeroes($transaction->[$haben]->{'accno'});
        $konto      = "e" . trim_leading_zeroes($transaction->[$soll]->{'accno'});
        if ($transaction->[$haben]->{'invnumber'} ne "") {
          $belegfeld1 = "\xBD" . $transaction->[$haben]->{'invnumber'} . "\x1C";
        }
        $datum = "d";
        $datum .= &datetofour($transaction->[$haben]->{'transdate'}, 0);
        $waehrung = "\xB3" . "EUR" . "\x1C";
        if ($transaction->[$haben]->{'name'} ne "") {
          $buchungstext = "\x1E" . $transaction->[$haben]->{'name'} . "\x1C";
        }
        if ($transaction->[$haben]->{'duedate'} ne "") {
          $belegfeld2 = "\xBE" . &datetofour($transaction->[$haben]->{'duedate'}, 1) . "\x1C";
        }
      }

      $umsatz       = $kne_file->format_amount(abs($umsatz), 0);
      $umsatzsumme += $umsatz;
      $kne_file->add_block("+" . $umsatz);

      if (   ( $datevautomatik || $taxkey)
          && (!$datevautomatik || ($datevautomatik && ($charttax ne $taxkey)))) {
#         $kne_file->add_block("\x6C" . (!$datevautomatik ? $taxkey : "4"));
        $kne_file->add_block("\x6C${taxkey}");
      }

      $kne_file->add_block($gegenkonto);
      $kne_file->add_block($belegfeld1);
      $kne_file->add_block($belegfeld2);
      $kne_file->add_block($datum);
      $kne_file->add_block($konto);
      $kne_file->add_block($buchungstext);
      $kne_file->add_block($waehrung . "\x79");
    }

    my $mandantenendsumme = "x" . $kne_file->format_amount($umsatzsumme / 100.0, 14) . "\x79\x7a";

    $kne_file->add_block($mandantenendsumme);
    $kne_file->flush();

    open(ED, ">", $ed_filename) or die "can't open outputfile: $!\n";
    print(ED $kne_file->get_data());
    close(ED);

    $ed_versionset[$fileno] = &make_ed_versionset($header, $filename, $kne_file->get_block_count(), $fromto);
    $fileno++;
  }

  #Make EV Verwaltungsdatei
  my $ev_header = &make_ev_header($form, $fileno);
  my $ev_filename = $export_path . $evfile;
  push(@filenames, $evfile);
  open(EV, ">", $ev_filename) or die "can't open outputfile: EV01\n";
  print(EV $ev_header);

  foreach my $file (@ed_versionset) {
    print(EV $ed_versionset[$file]);
  }
  close(EV);
  print qq|<br>Done. <br>
|;
  ###
  $main::lxdebug->leave_sub();

  return { 'download_token' => get_download_token_for_path($export_path), 'filenames' => \@filenames };
}

sub kne_stammdatenexport {
  $main::lxdebug->enter_sub();

  my ($myconfig, $form) = @_;
  $form->{abrechnungsnr} = "99";

  $form->header;
  print qq|
  <html>
  <body>Export in Bearbeitung<br>
|;

  my @filenames;

  my $export_path = _get_export_path() . "/";
  my $filename    = "ED00000";
  my $evfile      = "EV01";
  my @ed_versionset;
  my $fileno          = 1;
  my $i               = 0;
  my $blockcount      = 1;
  my $remaining_bytes = 256;
  my $total_bytes     = 256;
  my $buchungssatz    = "";
  $filename++;
  my $ed_filename = $export_path . $filename;
  push(@filenames, $filename);
  open(ED, ">", $ed_filename) or die "can't open outputfile: $!\n";
  my $header = &make_kne_data_header($myconfig, $form, "");
  $remaining_bytes -= length($header);

  my $fuellzeichen;
  our $fromto;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my (@where, @values) = ((), ());
  if ($form->{accnofrom}) {
    push @where, 'c.accno >= ?';
    push @values, $form->{accnofrom};
  }
  if ($form->{accnoto}) {
    push @where, 'c.accno <= ?';
    push @values, $form->{accnoto};
  }

  my $where_str = ' WHERE ' . join(' AND ', map { "($_)" } @where) if (scalar @where);

  my $query     = qq|SELECT c.accno, c.description
                     FROM chart c
                     $where_str
                     ORDER BY c.accno|;

  my $sth = $dbh->prepare($query);
  $sth->execute(@values) || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
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
  my $dateiende = "\x00" x $fuellzeichen;
  print(ED "z");
  print(ED $dateiende);
  close(ED);

  #Make EV Verwaltungsdatei
  $ed_versionset[0] =
    &make_ed_versionset($header, $filename, $blockcount, $fromto);

  my $ev_header = &make_ev_header($form, $fileno);
  my $ev_filename = $export_path . $evfile;
  push(@filenames, $evfile);
  open(EV, ">", $ev_filename) or die "can't open outputfile: EV01\n";
  print(EV $ev_header);

  foreach my $file (@ed_versionset) {
    print(EV $ed_versionset[$file]);
  }
  close(EV);

  $dbh->disconnect;
  ###

  print qq|<br>Done. <br>
|;

  $main::lxdebug->leave_sub();

  return { 'download_token' => get_download_token_for_path($export_path), 'filenames' => \@filenames };
}

1;
