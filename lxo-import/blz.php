<html>
<LINK REL="stylesheet" HREF="../css/lx-office-erp.css" TYPE="text/css" TITLE="Lx-Office stylesheet">
<body>
<?php
/*
BLZimport mit Browser nach Lx-Office ERP
Holger Lindemann <hli@lx-system.de>
*/


/* display help */
if ($_POST["ok"]=="Hilfe") {
	echo "<br>Die erste Zeile enth&auml;lt keine Feldnamen der Daten.<br>";
	echo "Die Datenfelder haben eine feste Breite.<br><br>"; 
	echo "Die Daten k&ouml;nnen hier bezogen werden:<br>";
	echo "<a http='http://www.bundesbank.de/zahlungsverkehr/zahlungsverkehr_bankleitzahlen_download.php'>";
	echo "http://www.bundesbank.de/zahlungsverkehr/zahlungsverkehr_bankleitzahlen_download.php</a>";
	exit(0);
} else if ($_POST) {
	function ende($nr) {
		echo "Abbruch: $nr<br>";
		echo "Fehlende oder falsche Daten.";
		exit(1);
	}

	function l2u($str) {
		return iconv("ISO-8859-1", "UTF-8",$str);
	}

	require ("import_lib.php");

	if (!$_SESSION["db"]) {
		$conffile="../config/authentication.pl";
		if (!is_file($conffile)) {
			ende(4);
		}
		if (!anmelden()) ende(5);
	}


	/* get DB instance */
	$db=$_SESSION["db"]; 

	$test=$_POST["test"];

	clearstatcache ();

	/* no data? */
	if (empty($_FILES["Datei"]["name"]))
		ende (2);

	/* copy file */
	if (!move_uploaded_file($_FILES["Datei"]["tmp_name"],"blz.txt")) {
		print_r($_FILES);
		echo $_FILES["Datei"]["tmp_name"];
		echo "Upload von Datei fehlerhaft.";
		echo $_FILES["Datei"]["error"], "<br>";
		ende (2);
	} 

	/* check if file is really there */
	if (!file_exists("blz.txt")) 
		ende(3);

	$sqlins="INSERT INTO blz_data (blz,fuehrend,bezeichnung,plz,ort,kurzbez,pan,bic,pzbm,nummer,aekz,bl,folgeblz) ";
	$sqlins.="VALUES ('%s','%s','%s','%s','%s','%s','%s','%s','%s',%d,'%s','%s','%s')";
	$teststr="<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td>";
	$teststr.="<td>%s</td><td>%s</td><td>%d</td><td>%s</td><td>%s</td><td>%s</td></tr>\n";
	$sqldel="delete from blz_data";
	$ok="true";
	$cnt=0;
	$f=fopen("blz.txt","r");
	if ($test) echo "Testdurchlauf <br><table>\n";
	$i=0;
	$start=time();
	$rs = $db->getAll("SELECT current_setting('server_encoding')");
	$srvencoding = $rs[0]['current_setting'];
	$rs = $db->getAll("SELECT current_setting('client_encoding')");
	$cliencoding = $rs[0]['current_setting'];
	echo "SRV: $srvencoding - - CLI: $cliencoding<br>";
	if ($f) {
		//Cliententcoding auf Latin:
		if (!$test) { $rc=$db->query("BEGIN"); if ($cliencoding=="UTF8") $db->query("SET CLIENT_ENCODING TO 'latin-9'"); };
		if (!$test) $rc=$db->query($sqldel);
		while (($zeile=fgets($f,256)) != FALSE) {
			$cnt++;
			if (!$test){
				//Datenfile ist immer Latin!!
				//zwei Möglichkeiten der Zeichenwandlung. Was ist besser??
				//Client nicht umgestellt, Zeichen wandeln
				/*$sql=sprintf($sqlins,substr($zeile,0,8),substr($zeile,8,1),l2u(substr($zeile,9,58)),substr($zeile,67,5),
						l2u(substr($zeile,72,35)),l2u(substr($zeile,107,27)),substr($zeile,134,5),substr($zeile,139,11),
						substr($zeile,150,2),substr($zeile,152,6),substr($zeile,158,1),substr($zeile,159,1),
						substr($zeile,160,8));*/
				//Client umgestellt + und auch bei nicht UTF-Client:
				$sql=sprintf($sqlins,substr($zeile,0,8),substr($zeile,8,1),substr($zeile,9,58),substr($zeile,67,5),
						substr($zeile,72,35),substr($zeile,107,27),substr($zeile,134,5),substr($zeile,139,11),
						substr($zeile,150,2),substr($zeile,152,6),substr($zeile,158,1),substr($zeile,159,1),
						substr($zeile,160,8));
				$rc=$db->query($sql);
				if(DB::isError($rc)) {
					echo $sql."<br><pre>";
					echo $rc->getMessage()."</pre><br>";
					$ok=false;
					break;
				}
				if ($cnt % 10 == 0) { 
					if ($cnt % 1000 == 0) { $x=time()-$start; echo sprintf("%dsec %6d<br>",$x,$cnt); }
					else if ($cnt % 100 == 0) { echo "!"; }
					else { echo '.'; }
					flush(); 
				}
			} else {
				echo sprintf($teststr,substr($zeile,0,8),substr($zeile,8,1),l2u(substr($zeile,9,58)),substr($zeile,67,5),
                                                l2u(substr($zeile,72,35)),l2u(substr($zeile,107,27)),substr($zeile,134,5),substr($zeile,139,11),
                                                substr($zeile,150,2),substr($zeile,152,6),substr($zeile,158,1),substr($zeile,159,1),
                                                substr($zeile,160,8));
				$rc=true;
			}
			if (!$rc) { 
				$ok=false;
				break;
			}
			$i++;
		}
		if ($ok) {
			if (!$test) $rc=$db->query("COMMIT");
			echo "<br>$i Daten erfolgreich importierti<br>";
			if ($cliencoding=="UTF8") $db->query("SET CLIENT_ENCODING TO 'UTF8'");
			$stop=time();
			echo $stop-$start." Sekunden";
		} else {
			if (!$test) $rc=$db->query("ROLLBACK");
			echo "Fehler in Zeile: ".$i."<br>";
			echo $sql."<br>";
			ende(6);
		}
	} else {
		ende(4);
	}
	echo "</table><br>Fertig. $i Banken importiert.";
} else {
?>
<p class="listtop">BLZ-Import f&uuml;r die ERP<p>
<br>Die erste Zeile enth&auml;lt keine Feldnamen der Daten.<br>
Die Datenfelder haben eine feste Breite.<br><br>
Die Daten k&ouml;nnen hier bezogen werden:<br>
<a http='http://www.bundesbank.de/zahlungsverkehr/zahlungsverkehr_bankleitzahlen_download.php'>
http://www.bundesbank.de/zahlungsverkehr/zahlungsverkehr_bankleitzahlen_download.php</a><br><br>
Das File vorher <b>nicht</b> auf UTF8 wandeln!<br><br>
Achtung!! Die bestehenden BLZ-Daten werden zun&auml;chst gel&ouml;scht.
<br>
<form name="import" method="post" enctype="multipart/form-data" action="blz.php">
<input type="hidden" name="MAX_FILE_SIZE" value="20000000">
<input type="hidden" name="login" value="<?= $login ?>">
<table>
<tr><td>Test</td><td><input type="checkbox" name="test" value="1">ja</td></tr>
<tr><td>Daten</td><td><input type="file" name="Datei"></td></tr>
<tr><td></td><td><input type="submit" name="ok" value="Import"></td></tr>
</table>
</form>
<?php } ?>
