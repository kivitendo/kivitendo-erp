<html>
<LINK REL="stylesheet" HREF="../css/lx-office-erp.css" TYPE="text/css" TITLE="Lx-Office stylesheet">
<body>
<?
/*
Kontaktimport mit Browser nach Lx-Office ERP

Copyright (C) 2005
Author: Holger Lindemann
Email: hli@lx-system.de
Web: http://lx-system.de

*/
if ($_GET["login"]) {
	$login=$_GET["login"];
} else {
	$login=$_POST["login"];
};

require ("import_lib.php");
$db=new myDB($login);
$crm=checkCRM();

if ($_POST["ok"]) {
	$login=$_POST["login"];
	$test=$_POST["test"];

	if ($crm) {
		$kunde_fld = array_keys($contactscrm);
		$contact=$contactscrm;
	} else {
		$kunde_fld = array_keys($contacts);
		$contact=$contacts;
	}
	$nun=time();

	function ende($nr) {
		echo "Abbruch: $nr\n";
		echo "Aufruf: addressS.php [login customer|vendor] [test] | [felder]\n";
		exit($nr);
	}
	if ($_POST["ok"]=="Hilfe") {
		echo "Importfelder:<br>";
		echo "Feldname => Bedeutung<br>";
		foreach($contact as $key=>$val) {
			echo "$key => $val<br>";
		}
		exit(0);
	};

	clearstatcache ();

	$trenner=($_POST["trenner"])?$_POST["trenner"]:",";

if (!empty($_FILES["Datei"]["name"])) { 
	$file=$_POST["ziel"];
	if (!move_uploaded_file($_FILES["Datei"]["tmp_name"],$file."_contact.csv")) {
		$file=false;
		echo "Upload von ".$_FILES["Datei"]["name"]." fehlerhaft. (".$_FILES["Datei"]["error"].")<br>";
	} 
} else if (is_file($_POST["ziel"]."_contact.csv")) {
	$file=$_POST["ziel"];
} else {
	$file=false;
} 

if (!$file) ende (2);

if (!file_exists($file."_contact.csv")) ende(5);

if (!file_exists("../users/$login.conf")) ende(3);


$employee=chkUsr($login);
if (!$employee) ende(4);

if (!$db->chkcol($file)) ende(6);

$f=fopen($file."_contact.csv","r");
$zeile=fgets($f,1200);
$infld=split($trenner,strtolower($zeile));
$first=true;


foreach ($infld as $fld) {
	$fld = trim(strtr($fld,array("\""=>"","'"=>"")));
	$in_fld[]=$fld;
}
$j=0;
$zeile=fgetcsv($f,1200,$trenner);
while (!feof($f)){
	$i=-1;
	$firma="";
	$name=false;
	$id=false;
	$sql="insert into contacts ";
	$keys="(";
	$vals=" values (";
	foreach($zeile as $data) {
		$i++;
		if ($in_fld[$i]=="firma") { 
			$firma=addslashes(trim($data)); 
			continue;
		};
		if (!in_array($in_fld[$i],$kunde_fld)) {
			continue;
		}
		$data=addslashes(trim($data));
		if ($in_fld[$i]=="cp_cv_id" && $data) {
			$data=chkKdId($data);
			if ($data) $firma="";
			if (!$id) $id = $data;
			continue;
		} 
		if ($in_fld[$i]==$file."number" && $data) {
			$tmp=getFirma($data,$file);
			if ($tmp) $firma="";
			if ($id<>$tmp) $id=$tmp;
			continue;
		} 
		$keys.=$in_fld[$i].",";
		
		if ($data==false or empty($data) or !$data) {
                        $vals.="null,";
                } else {
                	if (in_array($in_fld[$i],array("cp_fax","cp_phone1","cp_phone2"))) {
				$data="0".$data;
			} else if ($in_fld[$i]=="cp_country" && $data) {
				$data=mkland($data);
			}
			if ($in_fld[$i]=="cp_name") $name=true;
                        $vals.="'".$data."',";
                        // bei jedem gefuellten Datenfeld erhoehen
                        $val_count++;
                }
	}
	if (!$name) {
		$zeile=fgetcsv($f,1200,$trenner);
		continue;
	}
	if ($firma) {
		$data=suchFirma($file,$firma);
		if ($data) {
			$vals.=$data["cp_cv_id"].",";
			$keys.="cp_cv_id,";
		}
	} else if ($id) {
			$vals.=$id.",";
			$keys.="cp_cv_id,";
	}
	if ($keys<>"(" && $val_count>2) {
		if ($test) {
			if ($first) {
				echo "<table border='1'>\n";
				echo "<tr><th>".str_replace(",","</th><th>",substr($keys,1,-1))."</th></tr>\n";
				$first=false;
			};
			$vals=str_replace("',","'</td><td>",substr($vals,9,-1));
			echo "<tr><td>".str_replace("null,","null</td><td>",$vals)."</td></tr>\n";
			flush();
		} else {
			$sql.=substr($keys,0,-1).")";
			$sql.=substr($vals,0,-1).")";
			$rc=$db->query($sql);
			if (!$rc) echo "Fehler: ".$sql."\n";
		}
		$j++;
	};
	$zeile=fgetcsv($f,1200,$trenner);
}
fclose($f);
echo $j." $file importiert.\n";} else {
?>
<p class="listtop">Kontakt-Adressimport f&uuml;r die ERP</p>
<form name="import" method="post" enctype="multipart/form-data" action="contactB.php">
<input type="hidden" name="MAX_FILE_SIZE" value="300000">
<input type="hidden" name="login" value="<?= $login ?>">
<table>
<tr><td></td><td><input type="submit" name="ok" value="Hilfe"></td></tr>
<tr><td>Zieltabelle</td><td><input type="radio" name="ziel" value="customer" checked>customer <input type="radio" name="ziel" value="vendor">vendor</td></tr>
<tr><td>Trennzeichen</td><td><input type="text" size="2" maxlength="1" name="trenner" value=";"></td></tr>
<tr><td>Test</td><td><input type="checkbox" name="test" value="1">ja</td></tr>
<tr><td>Daten</td><td><input type="file" name="Datei"></td></tr>
<tr><td></td><td><input type="submit" name="ok" value="Import"></td></tr>
</table>
</form>
<? }; ?>
