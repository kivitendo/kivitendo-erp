<?php
/***************************************************************
*Author: Holger Lindemann
*Copyright: (c) 2004 Lx-System
*License: non free
*eMail: info@lx-system.de
*Version: 1.1.0
*Shop: xtCommerce 2.0 RC 1.2
***************************************************************/

require_once "shoplib.php";
$LAND=array("Germany"=>"D");

function createCategory($name,$maingroup) {
global $langs;
	$newID=uniqid(rand());
	$sql="insert into categories (categories_image,parent_id,date_added) values ('$newID',$maingroup,now())";
	$rc=query("shop",$sql,"createCategory");
	$sql="select * from categories where categories_image = '$newID'";
	$rs=getAll("shop",$sql,"createCategory");
	$id=$rs[0]["categories_id"];
	$sql="update categories set categories_image = null where categories_id=$id";
	$rc=query("shop",$sql,"createCategory");
	echo "($name) ";
	foreach ($langs as $LANG) {
		$sql="insert into categories_description (categories_id,language_id,categories_name) values ($id,$LANG,'$name')";
		$rc=query("shop",$sql,"createCategory");
		if ($rc === -99) break;
	}
	return ($rc === -99)?false:$id;
}
function getCategory($name) {
	if (empty($name)) $name="Default";
	$tmp=split("!",$name);
	$maingroup=0;
	$found=true;
	$i=0;
	do {
		$sql="select D.*,C.parent_id from categories C left join categories_description D on C.categories_id=D.categories_id ";
		$sql.="where categories_name like '".$tmp[$i]."' and C.parent_id=$maingroup";
		$rs=getAll("shop",$sql,"getCategory");
		if ($rs[0]["categories_id"]) {
			$maingroup=$rs[0]["categories_id"];
			echo $maingroup.":".$rs[0]["categories_name"]." ";
			$i++;
		} else {
			$found=false;
		}
	} while ($rs and $found and $i<count($tmp));
	for (;$i<count($tmp); $i++) {
		$maingroup=createCategory($tmp[$i],$maingroup);
	}
	return $maingroup;
}
function insartikel($data) {
global $header,$tax,$defLang;
	$newID=uniqid(rand());
	$sql="insert into products (products_model,products_image) values ('".$data[array_search("products_model")]."','$newID')";
	$rc=query("shop",$sql,"insartikel");
	$sql="select * from products where products_image='$newID'";
	$rs=getAll("shop",$sql,"insartikel");
	$sql="update products set products_image=null,products_status=1 where products_id=".$rs[0]["products_id"];
	$rc=query("shop",$sql,"insartikel");
	$sql="insert into products_description (products_id,language_id,products_name) values (".$rs[0]["products_id"].",$defLang,' ')";
	$rc=query("shop",$sql,"insartikel");
	$sql="insert into products_to_categories (products_id,categories_id) values (".$rs[0]["products_id"].",".$data["categories_id"].")";
	$rc=query("shop",$sql,"insartikel");
	echo " <b>insert</b> ";
	updartikel($data,$rs[0]["products_id"]);
}
function updartikel($data,$id) {
global $header,$tax,$defLang;
	$sql="update products set products_price=%01.2f,products_weight=%01.2f,products_tax_class_id=%d,products_last_modified=now()  where products_id=%d";
	$sql=sprintf($sql,$data[array_search("products_price",$header)],$data[array_search("products_weight",$header)],$tax[$data[array_search("products_tax",$header)]],$id);
	$rc=query("shop",$sql,"updartikel");
	$sql="update products_description set products_name='%s',products_description='%s' where products_id=%d and language_id=$defLang";
	$sql=sprintf($sql,$data[array_search("products_name",$header)],$data[array_search("products_description",$header)],$id);
	$rc=query("shop",$sql,"insartikel");
	$sql="update products_to_categories set categories_id=".$data[array_search("categories_id",$header)]." where products_id=$id";
	$rc=query("shop",$sql,"insartikel");
	echo "(".$id." ".$data[array_search("products_name",$header)].")+++<br>";
}
function chkartikel($data) {
global $header,$tax;
	$sql="select * from products P left join products_description D on P.products_id=D.products_id left join products_to_categories C on P.products_id=C.products_id where  products_model like '".$data[array_search("products_model",$header)]."' and language_id=2";
	$rs=getAll("shop",$sql,"chkartikel");
	if ($rs) {
			 if ($rs[0]["products_price"]<>$data[array_search("products_price",$header)])	{ updartikel($data,$rs[0]["products_id"]); }
		else if ($rs[0]["products_weight"]<>$data[array_search("products_weight",$header)])	{ updartikel($data,$rs[0]["products_id"]); }
		else if ($rs[0]["products_name"]<>$data[array_search("products_name",$header)])		{ updartikel($data,$rs[0]["products_id"]); }
		else if ($rs[0]["products_description"]<>$data[array_search("products_description",$header)])	{ updartikel($data,$rs[0]["products_id"]); }
		else if ($rs[0]["products_tax_class_id"]<>$tax[$data[array_search("products_tax",$header)]])	{ updartikel($data,$rs[0]["products_id"]); }
		else if ($rs[0]["categories_id"]<>$data[array_search("categories_id",$header)])		{ updartikel($data,$rs[0]["products_id"]); }
		else { echo "(".$rs[0]["products_id"]." ".$rs[0]["products_name"].")...<br>"; };
	} else {
		insartikel($data);
	}
}

$sql="select languages_id from languages";
$rs=getAll("shop",$sql,"sellanguageid");
if ($rs) {
	foreach ($rs as $zeile) {
		$langs[]=$zeile["languages_id"];
	}
} else {
	$langs[]=1;
}
$sql="select * from languages L left join configuration C on L.code=C.configuration_value where  configuration_key = 'DEFAULT_LANGUAGE'";
$rs=getAll("shop",$sql,"sellanguage");
if ($rs) {
	$defLang=$rs[0]["languages_id"];
} else {
	$defLang=$SHOPlang;
}
$sql="select * from tax_rates";
$rs=getAll("shop",$sql,"taxrates");
if ($rs) {
	foreach ($rs as $zeile) {
		$tax[$zeile["tax_rate"]]=$zeile["tax_class_id"];
	}
} else {
	$tax[0]="";
}

if ($_FILES["csv"]["name"] || ($_POST["nofile"] && file_exists($SHOPdir)) ) {
	if ($_FILES["csv"]["tmp_name"]) {
		move_uploaded_file($_FILES["csv"]["tmp_name"],$SHOPdir);
	}
	$f=fopen($SHOPdir,"r");
	$header=fgetcsv($f,1000,";");
	$header[]="categories_id";
	$data=fgetcsv($f,1000,";");
	while (!feof($f)) {
		$catId=getCategory($data[array_search("categories_name",$header)]);
		$data[]=$catId;
		chkartikel($data);
		$data=fgetcsv($f,1000,";");
	}
	fclose($f);
	echo "<a href='trans.php'>zur&uuml;ck</a>";
} else {
?>
<html>
	<head>
		<title>Datenaustausch ERP-xt:Commerce</title>
	</head>
<body>
<center>
<br>
<h1>Artikelimport aus csv-Datei in xt:Commerce</h1><br>
<form name="csv" action="shopimport_csv.php" enctype="multipart/form-data" method="post">
	<INPUT TYPE="hidden" name="MAX_FILE_SIZE" value="500000">
	<input type="checkbox" name="nofile" value="1">Auf dem Server vorhandene Daten importieren<br>
	Datenfile f&uuml;r Import <input type="file" name="csv"><br>
	<input type="submit" name="ok" value="ok">
</form>
</center>
<a href="trans.php">zur&uuml;ck</a>
</body>
</html>
<?
}
?>
