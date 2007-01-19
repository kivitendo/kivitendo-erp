<html>
<LINK REL="stylesheet" HREF="../css/lx-office-erp.css" TYPE="text/css" TITLE="Lx-Office stylesheet">
<body>
<?
/*
Warenimport mit Browser nach Lx-Office ERP
Henry Margies <h.margies@maxina.de>
Holger Lindemann <hli@lx-system.de>
*/

/* get login via GET or POST */
if ($_GET["login"]) {
	$login=$_GET["login"];
} else {
	$login=$_POST["login"];
};

require ("import_lib.php");
/* get DB instance */
$db=new myDB($login);


/* just display page or do real import? */
if ($_POST["ok"]) {


require ("parts_import.php");

function ende($nr) {
	echo "Abbruch: $nr<br>";
	echo "Fehlende oder falsche Daten.";
	exit(1);
}

/* display help */
if ($_POST["ok"]=="Hilfe") {
	echo "Importfelder:<br>";
	echo "Feldname => Bedeutung<br>";
	foreach($parts as $key=>$val) {
		echo "$key => $val<br>";
	}
	echo "Jeder Artikel mu&szlig; einer Buchungsgruppe zugeordnet werden. ";
	echo "Dazu mu&szlig; entweder in der Maske eine Standardbuchungsgruppe gew&auml;hlt werden <br>";
	echo "oder es wird ein g&uuml;ltiges Konto in 'income_accno_id' und 'expense_accno_id' eingegeben. ";
	echo "Das Programm versucht dann eine passende Buchungsgruppe zu finden.";
	exit(0);
};

clearstatcache ();

$test    = $_POST["test"];
$trenner = ($_POST["trenner"])?$_POST["trenner"]:",";
$file    = "parts";

/* no data? */
if (empty($_FILES["Datei"]["name"]))
	ende (2);

/* copy file */
if (!move_uploaded_file($_FILES["Datei"]["tmp_name"],$file.".csv")) {
	echo "Upload von Datei fehlerhaft.";
	echo $_FILES["Datei"]["error"], "<br>";
	ende (2);
} 

/* ??? */
if (!file_exists("../users/$login.conf")) 
	ende(3);

/* check if file is really there */
if (!file_exists("$file.csv")) 
	ende(5);

/* ??? */
if (!$db->chkcol($file)) 
	ende(6);

/* ??? */
if (!chkUsr($login))
	ende(4);

/* first check all elements */
echo "Checking data:<br>";
$err = import_parts($db, $file, $trenner, $parts, TRUE, FALSE, FALSE,$_POST);
echo "$err Errors found\n";


if ($err!=0)
	exit(0);

/* just print data or insert it, if test is false */
import_parts($db, $file, $trenner, $parts, FALSE, !$test, TRUE,$_POST);

} else {
	$bugrus=getAllBG($db);
?>

<p class="listtop">Artikelimport f&uuml;r die ERP<p>
<br>
<form name="import" method="post" enctype="multipart/form-data" action="partsB.php">
<input type="hidden" name="MAX_FILE_SIZE" value="2000000">
<input type="hidden" name="login" value="<?= $login ?>">
<table>
<tr><td></td><td><input type="submit" name="ok" value="Hilfe"></td></tr>
<tr><td>Trennzeichen</td><td><input type="text" size="2" maxlength="1" name="trenner" value=";"></td></tr>
<tr><td>Test</td><td><input type="checkbox" name="test" value="1">ja</td></tr>
<tr><td>Art</td><td><input type="Radio" name="ware" value="W">Ware &nbsp; 
		    <input type="Radio" name="ware" value="D">Dienstleistung
		    <input type="Radio" name="ware" value="G" checked>gemischt (Spalte 'art' vorhanden)</td></tr>
<tr><td>Default Bugru<br></td><td><select name="bugru">
<?	if ($bugrus) foreach ($bugrus as $bg) { ?>
			<option value="<?= $bg["id"] ?>"><?= $bg["description"] ?>
<?	} ?>
	</select>
	<input type="radio" name="bugrufix" value="0" checked>nie<br>
	<input type="radio" name="bugrufix" value="1">f&uuml;r alle Artikel verwenden
	<input type="radio" name="bugrufix" value="2">f&uuml;r Artikel ohne passende Bugru
	</td></tr>
<tr><td>Daten</td><td><input type="file" name="Datei"></td></tr>
<tr><td></td><td><input type="submit" name="ok" value="Import"></td></tr>
</table>
</form>
<? }; ?>
