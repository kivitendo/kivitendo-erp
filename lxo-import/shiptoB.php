<html>
<LINK REL="stylesheet" HREF="../css/lx-office-erp.css" TYPE="text/css" TITLE="Lx-Office stylesheet">
<body>
<?
/*
Lieferanschriftimport mit Browser nach Lx-Office ERP

Copyright (C) 2005
Author: Philip Reetz
Email: p.reetz@linet-services.de
Web: http://www.linet-services.de

*/
	function ende($nr) {
		echo "Abbruch: $nr\n";
		exit($nr);
	}

	if ($_POST["ok"]=="Hilfe") {
		echo "Importfelder:<br>";
		echo "Feldname => Bedeutung<br>";
		foreach($shiptos as $key=>$val) {
			echo "$key => $val<br>";
		}
		exit(0);
	};

if (!$_SESSION["db"]) {
	$conffile="../config/authentication.pl";
	if (!is_file($conffile)) {
		ende(4);
	}
}
require ("import_lib.php");

if (!anmelden()) ende(5);

/* get DB instance */
$db=$_SESSION["db"]; //new myDB($login);


$crm=checkCRM();

if ($_POST["ok"] == "Import") {
	$test=$_POST["test"];
	
	$shipto_fld = array_keys($shiptos);
	$shipto=$shiptos;
	
	$nun=time();


	clearstatcache ();

	$trenner=($_POST["trenner"])?$_POST["trenner"]:",";

	if (!empty($_FILES["Datei"]["name"])) { 
		$file=$_POST["ziel"];
		if (!move_uploaded_file($_FILES["Datei"]["tmp_name"],$file."_shipto.csv")) {
			$file=false;
			echo "Upload von ".$_FILES["Datei"]["name"]." fehlerhaft. (".$_FILES["Datei"]["error"].")<br>";
		} 
	} else if (is_file($_POST["ziel"]."_shipto.csv")) {
		$file=$_POST["ziel"];
	} else {
		$file=false;
	} 
	if (!$file) ende (2);

	if (!file_exists($file."_shipto.csv")) ende(5);

	$employee=chkUsr($_SESSION["employee"]);
	if (!$employee) ende(4);

	if (!$db->chkcol($file)) ende(6);

	$f=fopen($file."_shipto.csv","r");
	$zeile=fgetcsv($f,1000,$trenner);
	$first=true;

	foreach ($zeile as $fld) {
		$fld = strtolower(trim(strtr($fld,array("\""=>"","'"=>""))));
		$in_fld[]=$fld;
	}
	$j=0;
	$prenumber=$_POST["prenumber"];
	$zeile=fgetcsv($f,1000,$trenner);

while (!feof($f)){
	$i=-1;
	$firma="";
	$name=false;
	$id=false;
	$sql="insert into shipto ";
	$keys="(";
	$vals=" values (";
	foreach($zeile as $data) {
		$i++;
		if (!in_array($in_fld[$i],$shipto_fld)) {
			continue;
		}
		$data=addslashes(trim($data));
		if ($in_fld[$i]=="trans_id" && $data) {
			$data=chkKdId($data);
			if (!$id) $id = $data;
			continue;
		} else  if ($in_fld[$i]=="trans_id") {
			continue;
		}
		if ($in_fld[$i]==$file."number" && $data) {
			$tmp=getFirma($data,$file);
			if ($id<>$tmp) $id=$tmp;
			continue;
		} else if ($in_fld[$i]==$file."number") {
			continue;
		}
		if ($in_fld[$i]=="firma") {
			if ($id) continue;
			$data=suchFirma($file,$firma);
			if ($data) {
				$id=$data["cp_cv_id"];
			}
			continue;
		}
		$keys.=$in_fld[$i].",";
		
		if ($data==false or empty($data) or !$data) {
                        $vals.="null,";
                } else {
                	if (in_array($in_fld[$i],array("cp_fax","cp_phone1","cp_phone2"))) {
				$data=$prenumber.$data;
			} else if ($in_fld[$i]=="cp_country" && $data) {
				$data=mkland($data);
			}
			if ($in_fld[$i]=="cp_name") $name=true;
                        $vals.="'".$data."',";
                        // bei jedem gefuellten Datenfeld erhoehen
                        $val_count++;
                }
	}
// 	if (!$name) {
// 		$zeile=fgetcsv($f,1000,$trenner);
// 		continue;
// 	}
	if ($keys<>"(" && $id) {
		$vals.=$id.",'CT'";
		$keys.="trans_id,module";
		if ($test) {
			if ($first) {
				echo "<table border='1'>\n";
				echo "<tr><th>".str_replace(",","</th><th>",substr($keys,1,-1))."</th></tr>\n";
				$first=false;
			};
			$vals=str_replace("',","'</td><td>",$vals);
			echo "<tr><td>".str_replace("null,","null</td><td>",$vals)."</td></tr>\n";
			flush();
		} else {
			$sql.=$keys.")";
			$sql.=$vals.")";
			$rc=$db->query($sql);
			if (!$rc) echo "Fehler: ".$sql."\n";
		}
		$j++;
	} else {
		echo $keys."<br>";
		echo $vals."<br>";
	};
	$zeile=fgetcsv($f,1000,$trenner);
}
fclose($f);
echo $j." $file importiert.\n";} else {
?>
<p class="listtop">Lieferanschriftimport f&uuml;r die ERP</p>
<form name="import" method="post" enctype="multipart/form-data" action="shiptoB.php">
<input type="hidden" name="MAX_FILE_SIZE" value="300000">
<table>
<tr><td></td><td><input type="submit" name="ok" value="Hilfe"></td></tr>
<tr><td>Zieltabelle</td><td><input type="radio" name="ziel" value="customer" checked>customer <input type="radio" name="ziel" value="vendor">vendor</td></tr>
<tr><td>Trennzeichen</td><td><input type="text" size="2" maxlength="1" name="trenner" value=";"></td></tr>
<tr><td>Telefonvorwahl</td><td><input type="text" size="4" maxlength="10" name="prenumber" value=""></td></tr>
<tr><td>Test</td><td><input type="checkbox" name="test" value="1">ja</td></tr>
<tr><td>Daten</td><td><input type="file" name="Datei"></td></tr>
<tr><td></td><td><input type="submit" name="ok" value="Import"></td></tr>
</table>
</form>
<? }; ?>
