<?
// $Id: diff.php,v 1.1 2004/06/30 10:12:15 hli Exp $
require_once "shoplib.php";
$LAND=array("Germany"=>"D");
if ($_POST["ok"]) {
	foreach($_POST as $key=>$val) {
		if ($key=="ok") continue;
		if ($key=="alle") continue;
		$sql="update products set products_status=0 where products_model='$key'";
		//echo "$key $sql";
		echo "$key ";
		if (query("shop",$sql,"diff")) { echo "deaktiviert<br>"; }
		else { echo "konnte nicht deaktiviert werden<br>"; };
	}
} else {
$sql="select partnumber from parts where shop='1' order by partnumber";
$erp=getAll("erp",$sql,"getPartnumber");
if ($SHOPlang>0) {
	$defLang=$SHOPlang;
} else {
	$sql="select * from languages L left join configuration C on L.code=C.configuration_value where  configuration_key = 'DEFAULT_LANGUAGE'";
	$rs=getAll("shop",$sql,"getLanguage");
	if ($rs) {
		$defLang=$rs[0]["languages_id"];
	} else {
		$defLang=1;
	}
}
if ($erp) foreach ($erp as $zeile) { $arE[]=$zeile["partnumber"]; };
$sql="select products_model,P.products_id,products_name from products P left join products_description D on P.products_id=D.products_id where language_id=$defLang and products_status=1 order by products_model";
$shop=getAll("shop",$sql,"products_model");
if ($shop) foreach ($shop as $zeile) {
	$arS[]=$zeile["products_model"];
	$arID[$zeile["products_model"]]=array("id"=>$zeile["products_id"],"name"=>$zeile["products_name"]);
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
<form name='doppel' method='post' action='diff.php?login=<?= $login ?>'>
<table>
<?
foreach ($result as $data) {
	echo "\t<tr><td><input type='checkbox' name='".$data."' value='1'></td><td>".$data."</td><td>".$arID[$data]["name"]."</td></tr>\n";
}
?>
	<tr><td><input type='checkbox' name='alle' value='1' onClick="sel()"></td><td></td><td>alle Artikel</td></tr>
	<tr><td colspan='3'><input type='submit' name='ok' value='ok'></td></tr>
</table>
<form>
<? }
	else { echo "Artikelbestand identisch"; };
} ?>
<!-- a href="trans.php">zur&uuml;ck</a -->
