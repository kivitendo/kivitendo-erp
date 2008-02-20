<?
/***************************************************************
* $Id: erpexport.php,v 1.1 2004/06/29 08:50:30 hli Exp $
*Author: Holger Lindemann
*Copyright: (c) 2004 Lx-System
*License: non free
*eMail: info@lx-system.de
*Version: 1.0.0
*ERP: Lx-Office ERP
***************************************************************/
?>
<html>
	<head><title>Lx-ERP Export der Shopartikel</title>
	<link type="text/css" REL="stylesheet" HREF="css/main.css"></link>
	<script language="JavaScript">
	<!--
		function xtcomm() {
			document.fld.PN.value="products_model"; document.fld.partnumber.checked=true;
			document.fld.BEZ.value="products_name"; document.fld.desctiption.checked=true;
			document.fld.GEWICHT.value="products_weight"; document.fld.weight.checked=true;
			document.fld.MWST.value="products_tax"; document.fld.rate.checked=true;
			document.fld.VK.value="products_price"; document.fld.sellprice.checked=true;
			document.fld.PG.value="categories_name"; document.fld.partsgroup.checked=true;
			document.fld.BESCHR.value="products_description"; document.fld.notes.checked=true;
			document.fld.LAGER.value="products_quantity"; document.fld.onhand.checked=true;
			document.fld.encl.value="";
			document.fld.deli.value=";";
			document.fld.crln.value="\\n";
			document.fld.head.checked=true;
			document.fld.shop.value="xtcomm";
		}
	//-->
	</script>
<body>

<?php
require_once "shoplib.php";

function artikel() {
	$sql ="SELECT P.partnumber,P.description,P.unit,P.weight,t.rate,P.sellprice,P.listprice,P.priceupdate,";
	$sql.="PG.partsgroup,P.notes,P.image,P.onhand,P.buchungsgruppen_id as bugru FROM ";
	$sql.="chart c left join tax t on c.taxkey_id=t.taxkey, parts P left join partsgroup PG on ";
	$sql.="PG.id=P.partsgroup_id left join buchungsgruppen B  on P.buchungsgruppen_id = B.id ";
	$sql.="WHERE P.shop='t'  and c.id=B.income_accno_id_0";
	$rs=getAll("erp",$sql,"artikel");
	return $rs;
}

if ($_POST["export"]) {
	$data=artikel();
	$delim=($_POST["deli"])?$_POST["deli"]:",";
	if (get_magic_quotes_gpc()) {
		$crln = stripslashes($_POST["crln"]);
	}
	$crln = str_replace('\\r', "\015", $crln);
	$crln = str_replace('\\n', "\012", $crln);
	$crln = str_replace('\\t', "\011", $crln);
	$encl=$_POST["encl"];
	$i=0;
	$f=fopen($ERPdir,"w");
	if ($_POST["partnumber"])	{$header.=$_POST["PN"].$delim; };
	if ($_POST["desctiption"])	{$header.=$_POST["BEZ"].$delim; };
	if ($_POST["unit"])		{$header.=$_POST["EINHEIT"].$delim; };
	if ($_POST["onhand"])		{$header.=$_POST["LAGER"].$delim; };
	if ($_POST["weight"])		{$header.=$_POST["GEWICHT"].$delim; };
	if ($_POST["rate"])		{$header.=$_POST["MWST"].$delim; };
	if ($_POST["sellprice"])	{$header.=$_POST["VK"].$delim; };
	if ($_POST["listprice"])	{$header.=$_POST["EK"].$delim; };
	if ($_POST["priceupdate"])	{$header.=$_POST["PDATE"].$delim; };
	if ($_POST["partsgroup"])	{$header.=$_POST["PG"].$delim; };
	if ($_POST["notes"])		{$header.=$_POST["BESCHR"].$delim; };
	if ($_POST["image"])		{$header.=$_POST["IMAGE"].$delim; };
	$header=substr($header,0,-1);
?>
<table class="liste">
<!-- BEGIN Artikel -->
<?	$i=0;
	$f=fopen($ERPdir,"w");
	if ($_POST["head"]) fputs($f,$header.$crln);
	foreach($data as $zeile) {
		$file=""; $html="";
		if ($_POST["shop"]=="pepper") {
			if (preg_match("/^\[.*\].*/",$zeile["partsgroup"])) { $PG=$zeile["partsgroup"]; }
			else { $PG="[".$zeile["partsgroup"]."]"; };
			$mwst=$zeile["rate"]*100;
		} else if ($_POST["shop"]=="oscomm") {
			$mwst=sprintf("%01.4f",($zeile["rate"]*100));
			$PG=$zeile["partsgroup"];
		} else {
			$PG=$zeile["partsgroup"];
			$mwst=$zeile["rate"]*100;
		};
		$LineCol = $bgcol[$i%2+1];
		if ($_POST["partnumber"])	{$file.=$encl.$zeile["partnumber"].$encl.$delim; $html.="<td>".$zeile["partnumber"]."</td>";};
		if ($_POST["desctiption"])	{$file.=$encl.strtr($zeile["description"],chr(13).chr(10),"  ").$encl.$delim; $html.="<td>".$zeile["description"]."</td>";};
		if ($_POST["unit"])			{$file.=$encl.$zeile["unit"].$encl.$delim; $html.="<td>".$zeile["unit"]."</td>";};
		if ($_POST["onhand"])			{$file.=$encl.$zeile["onhand"].$encl.$delim; $html.="<td>".$zeile["onhand"]."</td>";};
		if ($_POST["weight"])		{$file.=$encl.$zeile["weight"].$encl.$delim; $html.="<td>".$zeile["weight"]."</td>";};
		if ($_POST["rate"])			{$file.=$encl.$mwst.$encl.$delim; $html.="<td>".$mwst."</td>";};
		if ($_POST["sellprice"])	{$file.=$encl.(sprintf("%02.2f",$zeile["sellprice"])).$encl.$delim; $html.="<td>".(sprintf("%02.2f",$zeile["sellprice"]))."</td>";};
		if ($_POST["listprice"])	{$file.=$encl.(sprintf("%02.2f",$zeile["listprice"])).$encl.$delim; $html.="<td>".(sprintf("%02.2f",$zeile["listprice"]))."</td>";};
		if ($_POST["partsgroup"])	{$file.=$encl.$PG.$encl.$delim; $html.="<td>".$zeile["partsgroup"]."</td>";};
		if ($_POST["notes"])		{$file.=$encl.strtr($zeile["notes"],chr(13).chr(10),"  ").$encl.$delim; $html.="<td>".$zeile["notes"]."</td>";};
		if ($_POST["image"])		{$file.=$encl.$zeile["image"].$encl.$delim; $html.="<td>".$zeile["image"]."</td>";};
		$i++;
		fputs($f,substr($file,0,-1).$crln);
		if ($_POST["show"]) {
?>
	<tr  class="smal" onMouseover="this.bgColor='#FF0000';" onMouseout="this.bgColor='<?= $LineCol ?>';" bgcolor="<?= $LineCol ?>">
		<?= $html ?>
	</tr>
<? 		}
	}
?>
<!-- END Artikel -->
</table>
Anzahl der Artikel: <?= $i ?><br>
Export am : <?= date("d.m.Y : H:i") ?><br>
download <a href="tmp/shopartikel.csv">Exportfile</a><br><hr>
<?
	fclose($f);
} // if ($export)
?>
Export der Shopartikel aus Lx-ERP <br>
M&ouml;gliche Felder
<form name="fld" action="erpexport.php" method="post">
<input type="hidden" name="shop" value="">
<table>
	<tr>
		<td><input type="checkbox" name="partnumber" value="1">Artikelnummer</td>
		<td><input type="checkbox" name="desctiption" value="1">Bezeichnung</td>
		<td><input type="checkbox" name="unit" value="1">Einheit</td>
		<td><input type="checkbox" name="weight" value="1">Gewicht</td>
	</tr>
	<tr>
		<td><input type="text" name="PN" size="23"></td>
		<td><input type="text" name="BEZ" size="23"></td>
		<td><input type="text" name="EINHEIT" size="23"></td>
		<td><input type="text" name="GEWICHT" size="23"></td>
	</tr>
	<tr><td colspan=5></td></tr>
	<tr>
		<td><input type="checkbox" name="sellprice" value="1">Verkaufspreis</td>
		<td><input type="checkbox" name="listprice" value="1">Listenpreis</td>
		<td><input type="checkbox" name="onhand" value="1">Lagerbestand</td>
		<td><input type="checkbox" name="rate" value="1">MwSt</td>
	</tr>
	<tr>
		<td><input type="text" name="VK" size="23"></td>
		<td><input type="text" name="EK" size="23"></td>
		<td><input type="text" name="LAGER" size="23"></td>
		<td><input type="text" name="MWST" size="23"></td>
	</tr>
	<tr><td colspan=5></td></tr>
	<tr>
		<td><input type="checkbox" name="partsgroup" value="1">Gruppe</td>
		<td><input type="checkbox" name="notes" value="1">Beschreibung</td>
		<td><input type="checkbox" name="image" value="1">Bild</td>
		<td><input type="checkbox" name="show" value="1" checked>HTML-Anzeige</td>
	</tr>
	<tr>
		<td><input type="text" name="PG" size="23"></td>
		<td><input type="text" name="BESCHR" size="23"></td>
		<td><input type="text" name="IMAGE" size="23"></td>
		<td></td>
	</tr>
	<tr>
		<td>Feldtrenner <input type="text" name="deli" size="2" value=","></td>
		<td>Feldumrahmung <input type="text" name="encl" size="2" value="&quot;"></td>
		<td>Zeilenende <input type="text" name="crln" size="2" value="\n"></td>
		<td><input type="checkbox" name="head" value="1" checked>Headline</td>
	</tr>
	<tr>
		<td colspan=5><input type="submit" name="export" value="Export"> <input type="button" name="xsc" value="xtCommerce" onClick="xtcomm()"></td>
	</tr>
</table>
<a href="trans.php">zur&uuml;ck</a>
</form>
</body>
</html>
