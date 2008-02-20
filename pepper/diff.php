<?
// $Id: diff.php,v 1.1 2004/12/17 13:50:15 hli Exp $
require_once "DB.php";
require_once "conf.php";
if (!$db) {
	$db=DB::connect($SHOPdns);
	if (!$db) dbFehler("",$db->getDebugInfo());
	if (DB::isError($db)) {
		dbFehler("",$db->getDebugInfo());
		die ($db->getDebugInfo());
	};
	$db2=DB::connect($ERPdns);
	if (!$db2) dbFehler("",$db2->getDebugInfo());
	if (DB::isError($db2)) {
		dbFehler("",$db2->getDebugInfo());
		die ($db2->getDebugInfo());
	};
}
if ($_POST["ok"]) {
	$sql="select Kategorie_ID from kategorien where  Unterkategorie_von = '@PhPepperShop@'";
	$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
	$no=$rs[0]["Kategorie_ID"];
	foreach($_POST as $key=>$val) {
		if ($key=="ok") continue;
		if ($key=="alle") continue;
		$sql="update artikel_kategorie set FK_Kategorie_ID=$no where FK_Artikel_ID=$val";
		echo "$key ";
		if ($db->query($sql)) { echo "deaktiviert<br>"; }
		else { echo "konnte nicht deaktiviert werden<br>"; };
	}
} else {
$sql="select Kategorie_ID from kategorien where  Unterkategorie_von = '@PhPepperShop@'";
$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
if ($rs) {
	$no="K.FK_Kategorie_ID<>".$rs[0]["Kategorie_ID"];
} else {
	$no="1";
}
$sql="select partnumber from parts where shop='1' order by partnumber";
$erp=$db2->getAll($sql,DB_FETCHMODE_ASSOC);
if ($erp) foreach ($erp as $zeile) { $arE[]=$zeile["partnumber"]; };
$sql="select Name,Artikel_ID,Artikel_NR from artikel A left join artikel_kategorie K on A.Artikel_ID=K.FK_Artikel_ID where $no";
$shop=$db->getAll($sql,DB_FETCHMODE_ASSOC);
if ($shop) foreach ($shop as $zeile) {
	$arS[]=$zeile["Artikel_NR"];
	$arID[$zeile["Artikel_NR"]]=array("id"=>$zeile["Artikel_ID"],"name"=>$zeile["Name"]);
}
$result=@array_diff($arS,$arE);
if ($result) {
?>
<html>
<head><title>Artikelpflege</title>
<script language="JavaScript">
<!--
	function sel() {
		val=document.doppel.alle.checked;
		cnt=document.doppel.length;
		for (i=0; i<cnt; i++) {
			document.doppel.elements[i].checked=val;
		}
	}
//-->
</script>
</head>
<body>
Folgende Artikel sind in der ERP nicht mehr als Shopartikel markiert.<br>
Markieren Sie die Artikel, die deaktiviert werden sollen.<br>
<form name='doppel' method='post' action='diff.php'>
<table>
<?
foreach ($result as $data) {
	echo "\t<tr><td><input type='checkbox' name='".$data."' value='".$arID[$data]["id"]."'></td><td>".$data."</td><td>".$arID[$data]["name"]."</td></tr>\n";
}
?>
	<tr><td><input type='checkbox' name='alle' value='1' onClick="sel()"></td><td></td><td>alle Artikel</td></tr>
	<tr><td colspan='3'><input type='submit' name='ok' value='ok'></td></tr>
</table>
<form>
<? }
	else { "Artikelbestand identisch"; };
} ?>
<a href="trans.php">zur&uuml;ck</a>
