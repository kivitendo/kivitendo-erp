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
#
#======================================================================

use POSIX qw(strftime getcwd);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

use SL::Common;
use SL::DATEV;

use strict;

1;

# end of main

require "bin/mozilla/common.pl";

sub continue { call_sub($main::form->{"nextsub"}); }

sub export {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('datev_export');

  $form->{title} = $locale->text("DATEX - Export Assistent");

  DATEV->get_datev_stamm(\%myconfig, \%$form);
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>


<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr>
    <th align=left>| . $locale->text("DATEV Angaben") . qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
        <tr>
          <td align=left nowrap>| . $locale->text("Beraternummer") . qq|</td>
          <td><input name=beraternr size=10 maxlength=7 value="$form->{beraternr}"></td>

          <td align=left nowrap>| . $locale->text("DFV-Kennzeichen") . qq|</td>
          <td><input name=dfvkz size=5 maxlength=2 value="$form->{dfvkz}"></td>
        </tr>
        <tr>
          <td align=left nowrap>| . $locale->text("Beratername") . qq|</td>
          <td><input name=beratername size=10 maxlength=9 value="$form->{beratername}"></td>

          <td align=left nowrap>| . $locale->text("Password") . qq|</td>
          <td><input name=passwort size=5 maxlength=4 value="$form->{passwort}"></td>
        </tr>
        <tr>
          <td align=left nowrap>| . $locale->text("Mandantennummer") . qq|</td>
          <td><input name=mandantennr size=10 maxlength=5 value="$form->{mandantennr}"></td>

          <td align=left nowrap>| . $locale->text("Medium Number") . qq|</td>
          <td><input name=datentraegernr size=5 maxlength=3 value="$form->{datentraegernr}"></td>
        </tr>
        <tr>
          | . # OBE-Export noch nicht implementiert! <td><input checked name=kne type=checkbox class=checkbox value=1> | . $locale->text("Kontonummernerweiterung (KNE)") . qq|</td>
    qq|<td><input type="hidden" name="kne" value="1"></td>
          <td></td>

          <td align=left nowrap>| . $locale->text("Abrechnungsnummer") . qq|</td>
          <td><input name=abrechnungsnr size=5 maxlength=3 value="$form->{abrechnungsnr}"></td>
        </tr>

        <tr>
          <td><input name=exporttype type=radio class=radio value=0 checked> |
    . $locale->text("Export Buchungsdaten") . qq|</td>
          <td></td>

          <td><input name=exporttype type=radio class=radio value=1> |
    . $locale->text("Export Stammdaten") . qq|</td>
          <td></td>
        </td>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

<input type=hidden name=nextsub value=export2>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;
  $main::lxdebug->leave_sub();
}

sub export2 {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;

  $main::auth->assert('datev_export');

  if ($form->{exporttype} == 0) {
    &export_bewegungsdaten();
  } else {
    &export_stammdaten();
  }
  $main::lxdebug->leave_sub();
}

sub export_bewegungsdaten {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('datev_export');

  $form->{title} = $locale->text("DATEX - Export Assistent");

  $form->{allemonate} =
      qq|<option value=1>|
    . $locale->text('January')
    . qq|</option>
                         <option value=2>|
    . $locale->text('February') . qq|</option>
                         <option value=3>|
    . $locale->text('March') . qq|</option>
                         <option value=4>|
    . $locale->text('April') . qq|</option>
                         <option value=5>|
    . $locale->text('May') . qq|</option>
                         <option value=6>|
    . $locale->text('June') . qq|</option>
                         <option value=7>|
    . $locale->text('July') . qq|</option>
                         <option value=8>|
    . $locale->text('August') . qq|</option>
                         <option value=9>|
    . $locale->text('September') . qq|</option>
                         <option value=10>|
    . $locale->text('October') . qq|</option>
                         <option value=11>|
    . $locale->text('November') . qq|</option>
                         <option value=12>|
    . $locale->text('December') . qq|</option>|;

  $form->{allequartale} =
      qq|<option selected value=1>|
    . $locale->text('I')
    . qq|</option>
                         <option value=2>| . $locale->text('II') . qq|</option>
                         <option value=3>|
    . $locale->text('III') . qq|</option>
                         <option value=4>|
    . $locale->text('IV') . qq|</option>|;
  $form->{"jsscript"} = 1;
  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>


<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr>
    <th align=left>| . $locale->text("Zeitraum") . qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
        <tr>
          <td align=left><input checked name=zeitraum class=radio type=radio value=monat>&nbsp;</td><td align=left>|
    . $locale->text('Monat') . qq|</td>
          <td align=left></td>
          <td align=left></td>
          <td align=left><select name=monat>$form->{allemonate}</select></td>
        </tr>
        <tr>
          <td align=left><input name=zeitraum class=radio type=radio value=quartal>&nbsp;</td><td align=left>|
    . $locale->text('Quartal') . qq|</td>
          <td align=left></td>
          <td align=left></td>
          <td align=left><select name=quartal>$form->{allequartale}</select></td>
        </tr>
        <tr>
          <td align=left><input name=zeitraum class=radio type=radio value=zeit>&nbsp;</td><td align=left>|
    . $locale->text('Datum von') . qq|</td>
          <td align=left><input id=transdatefrom name=transdatefrom size=10>
            <input type="button" name="transdatefrom" id="trigger_transdatefrom" value="?"></td>
          <td align=left>| . $locale->text('bis') . qq|</td>
          <td align=left><input id=transdateto name=transdateto size=10>
            <input type="button" name="transdateto" id="trigger_transdateto" value="?"></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>

| . $form->write_trigger(\%myconfig, 2,
                         "transdatefrom", "BL", "trigger_transdatefrom",
                         "transdateto", "BL", "trigger_transdateto") . qq|

<input type=hidden name=beraternr value="$form->{beraternr}">
<input type=hidden name=dfvkz value="$form->{dfvkz}">
<input type=hidden name=beratername value="$form->{beratername}">
<input type=hidden name=passwort value="$form->{passwort}">
<input type=hidden name=mandantennr value="$form->{mandantennr}">
<input type=hidden name=datentraegernr value="$form->{datentraegernr}">
<input type=hidden name=kne value="$form->{kne}">
<input type=hidden name=abrechnungsnr value="$form->{abrechnungsnr}">

<input type=hidden name=exporttype value="$form->{exporttype}">

<input type=hidden name=nextsub value=export3>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub export_stammdaten {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('datev_export');

  $form->{title} = $locale->text("DATEX - Export Assistent");

  $form->header;

  print qq|
<body>

<form method=post action=$form->{script}>
<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr>
    <th align=left>| . $locale->text("Konten") . qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
        <tr>
          <td align=left>| . $locale->text('Von Konto: ') . qq|</td>
          <td align=left><input name=accnofrom size=8 maxlength=8></td>
        </tr>
        <tr>
          <td align=left>| . $locale->text('Bis Konto: ') . qq|</td>
          <td align=left><input name=accnoto size=8 maxlength=8></td>
        </tr>
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
<input type=hidden name=beraternr value="$form->{beraternr}">
<input type=hidden name=dfvkz value="$form->{dfvkz}">
<input type=hidden name=beratername value="$form->{beratername}">
<input type=hidden name=passwort value="$form->{passwort}">
<input type=hidden name=mandantennr value="$form->{mandantennr}">
<input type=hidden name=datentraegernr value="$form->{datentraegernr}">
<input type=hidden name=kne value="$form->{kne}">
<input type=hidden name=abrechnungsnr value="$form->{abrechnungsnr}">

<input type=hidden name=exporttype value="$form->{exporttype}">

<input type=hidden name=nextsub value=export3>

<br>
<input type=submit class=submit name=action value="|
    . $locale->text('Continue') . qq|">
</form>

</body>
</html>
|;

  $main::lxdebug->leave_sub();
}

sub export3 {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my %myconfig = %main::myconfig;
  my $locale   = $main::locale;

  $main::auth->assert('datev_export');

  DATEV::clean_temporary_directories();

  DATEV->save_datev_stamm(\%myconfig, \%$form);

  my $link = "datev.pl?action=download&download_token=";

  if ($form->{kne}) {
    my $result = DATEV->kne_export(\%myconfig, \%$form);
    if ($result && @{ $result->{filenames} }) {
      $link .= Q($result->{download_token});

      print(qq|<br><b>| . $locale->text('KNE-Export erfolgreich!') . qq|</b><br><br><a href="$link">Download</a>|);

    } else {
      $form->error("KNE-Export schlug fehl.");
    }
  } else {
    # OBE-Export nicht implementiert.

    # my @filenames = DATEV->obe_export(\%myconfig, \%$form);
    # if (@filenames) {
    #   print(qq|<br><b>| . $locale->text('OBE-Export erfolgreich!') . qq|</b><br>|);
    #   $link .= "&filenames=" . $form->escape(join(":", @filenames));
    #   print(qq|<br><a href="$link">Download</a>|);
    # } else {
    #   $form->error("OBE-Export schlug fehl.");
    # }
  }

  print("</body></html>");

  $main::lxdebug->leave_sub();
}

sub download {
  $main::lxdebug->enter_sub();

  my $form     = $main::form;
  my $locale   = $main::locale;

  $main::auth->assert('datev_export');

  my $tmp_name = Common->tmpname();
  my $zip_name = strftime("lx-office-datev-export-%Y%m%d.zip", localtime(time()));

  my $cwd = getcwd();

  my $path = DATEV::get_path_for_download_token($form->{download_token});
  if (!$path) {
    $form->error($locale->text("Your download does not exist anymore. Please re-run the DATEV export assistant."));
  }

  chdir($path) || die("chdir $path");

  my @filenames = glob "*";

  if (!@filenames) {
    chdir($cwd);
    DATEV::clean_temporary_directories();
    $form->error($locale->text("Your download does not exist anymore. Please re-run the DATEV export assistant."));
  }

  my $zip = Archive::Zip->new();
  map { $zip->addFile($_); } @filenames;
  $zip->writeToFileNamed($tmp_name);

  chdir($cwd);

  open(IN, $tmp_name) || die("open $tmp_name");
  print("Content-Type: application/zip\n");
  print("Content-Disposition: attachment; filename=\"${zip_name}\"\n\n");
  while (<IN>) {
    print($_);
  }
  close(IN);

  unlink($tmp_name);

  DATEV::clean_temporary_directories();

  $main::lxdebug->leave_sub();
}
