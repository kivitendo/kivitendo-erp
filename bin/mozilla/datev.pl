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


use SL::DATEV;

1;
# end of main

sub continue { &{ $form->{nextsub} } };



sub export {
  $lxdebug->enter_sub();


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
    <th align=left>|.$locale->text("DATEV Angaben").qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
	  <td align=left nowrap>|.$locale->text("Beraternummer").qq|</td>
	  <td><input name=beraternr size=10 maxlength=7 value="$form->{beraternr}"></td>
	
	  <td align=left nowrap>|.$locale->text("DFV-Kennzeichen").qq|</td>
	  <td><input name=dfvkz size=5 maxlength=2 value="$form->{dfvkz}"></td>
	</tr>
	<tr>
	  <td align=left nowrap>|.$locale->text("Beratername").qq|</td>
	  <td><input name=beratername size=10 maxlength=9 value="$form->{beratername}"></td>
	
	  <td align=left nowrap>|.$locale->text("Password").qq|</td>
	  <td><input name=passwort size=5 maxlength=4 value="$form->{passwort}"></td>
	</tr>
	<tr>
	  <td align=left nowrap>|.$locale->text("Mandantennummer").qq|</td>
	  <td><input name=mandantennr size=10 maxlength=5 value="$form->{mandantennr}"></td>
	
	  <td align=left nowrap>|.$locale->text("Datenträgernummer").qq|</td>
	  <td><input name=datentraegernr size=5 maxlength=3 value="$form->{datentraegernr}"></td>
	</tr>	
	<tr>
	  <td><input checked name=kne type=checkbox class=checkbox value=1> |.$locale->text("Kontonummernerweiterung (KNE)").qq|</td>
          <td></td>
	
	  <td align=left nowrap>|.$locale->text("Abrechnungsnummer").qq|</td>
	  <td><input name=abrechnungsnr size=5 maxlength=3 value="$form->{abrechnungsnr}"></td>
	</tr>
        <tr>
          <td><input name=exporttype type=radio class=radio value=0 checked> |.$locale->text("Export Buchungsdaten").qq|</td>
          <td></td>
          
	  <td><input name=exporttype type=radio class=radio value=1> |.$locale->text("Export Stammdaten").qq|</td>
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

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;
  $lxdebug->leave_sub();
}

sub export2 {
  $lxdebug->enter_sub();

  if ($form->{exporttype}==0) {
    &export_bewegungsdaten();
  } else {&export_stammdaten();}
  $lxdebug->leave_sub();
}

sub export_bewegungsdaten {
  $lxdebug->enter_sub();


  $form->{title} = $locale->text("DATEX - Export Assistent");

  $form->{allemonate}=qq|<option value=1>|.$locale->text('January').qq|</option>
                         <option value=2>|.$locale->text('February').qq|</option>
                         <option value=3>|.$locale->text('March').qq|</option>
                         <option value=4>|.$locale->text('April').qq|</option>
                         <option value=5>|.$locale->text('May').qq|</option>
                         <option value=6>|.$locale->text('June').qq|</option>
                         <option value=7>|.$locale->text('July').qq|</option>
                         <option value=8>|.$locale->text('August').qq|</option>
                         <option value=9>|.$locale->text('September').qq|</option>
                         <option value=10>|.$locale->text('October').qq|</option>
                         <option value=11>|.$locale->text('November').qq|</option>
                         <option value=12>|.$locale->text('December').qq|</option>|;
    
    $form->{allequartale}=qq|<option selected value=1>|.$locale->text('I').qq|</option>
                         <option value=2>|.$locale->text('II').qq|</option>
                         <option value=3>|.$locale->text('III').qq|</option>
                         <option value=4>|.$locale->text('IV').qq|</option>|;
  $form->header;
  
  print qq|
<body>

<form method=post action=$form->{script}>


<table width=100%>
  <tr>
    <th class=listtop>$form->{title}</th>
  </tr>
  <tr>
    <th align=left>|.$locale->text("Zeitraum").qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
	<tr>
          <td align=left><input checked name=zeitraum class=radio type=radio value=monat>&nbsp;</td><td align=left>|.$locale->text('Monat').qq|</td>
          <td align=left></td>
	  <td align=left></td>
          <td align=left><select name=monat>$form->{allemonate}</select></td>
        </tr>
        <tr>  
          <td align=left><input name=zeitraum class=radio type=radio value=quartal>&nbsp;</td><td align=left>|.$locale->text('Quartal').qq|</td>
	  <td align=left></td>
          <td align=left></td>
          <td align=left><select name=quartal>$form->{allequartale}</select></td>
        </tr>
        <tr> 
          <td align=left><input name=zeitraum class=radio type=radio value=zeit>&nbsp;</td><td align=left>|.$locale->text('Datum von').qq|</td>
          <td align=left><input name=transdatefrom size=8></td>
	  <td align=left>|.$locale->text('bis').qq|</td>
          <td align=left><input name=transdateto size=8></td>         	
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

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}

sub export_stammdaten {
  $lxdebug->enter_sub();


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
    <th align=left>|.$locale->text("Konten").qq|</th>
  </tr>
  <tr height="5"></tr>
  <tr valign=top>
    <td>
      <table>
        <tr>
	  <td align=left>|.$locale->text('Von Konto: ').qq|</td>
          <td align=left><input name=accnofrom size=8 maxlength=8></td>
        </tr>
        <tr>
	  <td align=left>|.$locale->text('Bis Konto: ').qq|</td>
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

<input type=hidden name=path value=$form->{path}>
<input type=hidden name=login value=$form->{login}>
<input type=hidden name=password value=$form->{password}>

<br>
<input type=submit class=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;

  $lxdebug->leave_sub();
}


sub export3 {
  $lxdebug->enter_sub();

  DATEV->save_datev_stamm(\%myconfig, \%$form);
  
  if ($form->{kne}) {
  if (DATEV->kne_export(\%myconfig, \%$form)) {
  $form->redirect($locale->text('KNE Export erfolgreich!'))}
  } else {
  if (DATEV->obe_export(\%myconfig, \%$form)) { 
  $form->redirect($locale->text('OBE Export erfolgreich!'));}
  }
  $lxdebug->leave_sub();
}
