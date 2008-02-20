<?
// $Id: confedit.php,v 0.10 2006/02/06 11:34:30 hli Exp $
if (!isset($_SERVER['PHP_AUTH_USER'])) {
       Header("WWW-Authenticate: Basic realm=\"Configurations-Editor\"");
       Header("HTTP/1.0 401 Unauthorized");
       echo "Sie m&uuml;ssen sich autentifizieren\n";
       exit;
} else {
	include "conf.php";
	require_once "DB.php";
	$db=@DB::connect($ERPdns);
	if (!DB::isError($db)) {
		$sql="select id,pricegroup from pricegroup";
		$pgs=$db->getall($sql);
	}
	function pg($sel) {
	global $pgs;
		echo "\t<option value=0";
		if ($sel==0) echo " selected";
		echo ">Standard VK\n";
		if ($pgs) foreach ($pgs as $row) {
			echo "\t<option value=".$row[0];
			if ($sel==$row[0]) echo " selected";
			echo ">".$row[1]."\n";
		}
	}
    if ($_SERVER['PHP_AUTH_USER']<>$ERPftpuser || $_SERVER['PHP_AUTH_PW']<>$ERPftppwd) {
		Header("WWW-Authenticate: Basic realm=\"My Realm\"");
		Header("HTTP/1.0 401 Unauthorized");
		echo "Sie m&uuml;ssen sich autentifizieren\n";
		exit;
	}
	if ($_POST["ok"]=="sichern") {
		$ok=true;
		$dsnP="pgsql://".$_POST["ERPuser"].":".$_POST["ERPpass"]."@".$_POST["ERPhost"]."/".$_POST["ERPdbname"];
		$dbP=DB::connect($dsnP);
		if (DB::isError($dbP)||!$dbP) {
			$ok=false; 
			echo "Keine Verbindung zur ERP<br>"; 
			echo $dbP->userinfo;
		}
		else {
			$rs=$dbP->getall("select id,description from parts where partnumber = '".$_POST["div16NR"]."'");
			$_POST["div16ID"]=$rs[0][0];
			$div16txt=$rs[0][1];
			$rs=$dbP->getall("select id,description from parts where partnumber = '".$_POST["div07NR"]."'");
			$_POST["div07ID"]=$rs[0][0];
			$div07txt=$rs[0][1];
			$rs=$dbP->getall("select id,description from parts where partnumber = '".$_POST["versandNR"]."'");
			$_POST["versandID"]=$rs[0][0];
			$versandtxt=$rs[0][1];
			$rs=$dbP->getall("select id,description from parts where partnumber = '".$_POST["nachnNR"]."'");
			$_POST["nachnID"]=$rs[0][0];
			$nachntxt=$rs[0][1];
			$rs=$dbP->getall("select id,description from parts where partnumber = '".$_POST["minderNR"]."'");
			$_POST["minderID"]=$rs[0][0];
			$mindertxt=$rs[0][1];
			$rs=$dbP->getall("select id,description from parts where partnumber = '".$_POST["paypalNR"]."'");
			$_POST["paypalID"]=$rs[0][0];
			$paypaltxt=$rs[0][1];
			$rs=$dbP->getall("select id,description from parts where partnumber = '".$_POST["treuhNR"]."'");
			$_POST["treuhID"]=$rs[0][0];
			$treuhtxt=$rs[0][1];
			$rs=$dbP->getall("select id from employee where login = '".$_POST["ERPusrN"]."'");
			$_POST["ERPusrID"]=$rs[0][0];
		}
		$dsnM="mysql://".$_POST["SHOPuser"].":".$_POST["SHOPpass"]."@".$_POST["SHOPhost"]."/".$_POST["SHOPdbname"];
		$dbM=DB::connect($dsnM);
		if (DB::isError($dbM)||!$dbM) { 
			$ok=false; 
			echo "Keine Verbindung zum Shop<br>"; 
			echo $dbM->userinfo;
		};
		if (ok) {
			$f=fopen("conf.php","w");
			$v="1.5";
			$d=date("Y/m/d H:i:s");
			fputs($f,"<?\n// Verbindung zur ERP-db\n");
			fputs($f,"\$ERPuser=\"".$_POST["ERPuser"]."\";\n");
			fputs($f,"\$ERPpass=\"".$_POST["ERPpass"]."\";\n");
			fputs($f,"\$ERPhost=\"".$_POST["ERPhost"]."\";\n");
			fputs($f,"\$ERPdbname=\"".$_POST["ERPdbname"]."\";\n");
			fputs($f,"\$ERPdns=\"pgsql://\$ERPuser:\$ERPpass@\$ERPhost/\$ERPdbname\";\n");
			fputs($f,"\$ERPusr[\"Name\"]=\"".$_POST["ERPusrN"]."\";\n");
			fputs($f,"\$ERPusr[\"ID\"]=\"".$_POST["ERPusrID"]."\";\n");
			fputs($f,"\$ERPdir=\"".$_POST["ERPdir"]."\";\n");
			fputs($f,"\$ERPimgdir=\"".$_POST["ERPimgdir"]."\";\n");
			fputs($f,"\$maxSize=\"".$_POST["maxSize"]."\";\n");
			fputs($f,"\$ERPftphost=\"".$_POST["ERPftphost"]."\";\n");
			fputs($f,"\$ERPftpuser=\"".$_POST["ERPftpuser"]."\";\n");
			fputs($f,"\$ERPftppwd=\"".$_POST["ERPftppwd"]."\";\n");
			fputs($f,"//Verbindung zur osCommerce-db\n");
			fputs($f,"\$SHOPuser=\"".$_POST["SHOPuser"]."\";\n");
			fputs($f,"\$SHOPpass=\"".$_POST["SHOPpass"]."\";\n");
			fputs($f,"\$SHOPhost=\"".$_POST["SHOPhost"]."\";\n");
			fputs($f,"\$SHOPdbname=\"".$_POST["SHOPdbname"]."\";\n");
			fputs($f,"\$SHOPdns=\"mysql://\$SHOPuser:\$SHOPpass@\$SHOPhost/\$SHOPdbname\";\n");
			fputs($f,"\$SHOPdir=\"".$_POST["SHOPdir"]."\";\n");
			fputs($f,"\$SHOPimgdir=\"".$_POST["SHOPimgdir"]."\";\n");
			fputs($f,"\$SHOPftphost=\"".$_POST["SHOPftphost"]."\";\n");
			fputs($f,"\$SHOPftpuser=\"".$_POST["SHOPftpuser"]."\";\n");
			fputs($f,"\$SHOPftppwd=\"".$_POST["SHOPftppwd"]."\";\n");
			fputs($f,"\$div16[\"ID\"]=\"".$_POST["div16ID"]."\";\n");
			fputs($f,"\$div07[\"ID\"]=\"".$_POST["div07ID"]."\";\n");
			fputs($f,"\$versand[\"ID\"]=\"".$_POST["versandID"]."\";\n");
			fputs($f,"\$nachn[\"ID\"]=\"".$_POST["nachnID"]."\";\n");
			fputs($f,"\$minder[\"ID\"]=\"".$_POST["minderID"]."\";\n");
			fputs($f,"\$treuh[\"ID\"]=\"".$_POST["treuhID"]."\";\n");
			fputs($f,"\$paypal[\"ID\"]=\"".$_POST["paypalID"]."\";\n");
			fputs($f,"\$div16[\"NR\"]=\"".$_POST["div16NR"]."\";\n");
			fputs($f,"\$div07[\"NR\"]=\"".$_POST["div07NR"]."\";\n");
			fputs($f,"\$versand[\"NR\"]=\"".$_POST["versandNR"]."\";\n");
			fputs($f,"\$nachn[\"NR\"]=\"".$_POST["nachnNR"]."\";\n");
			fputs($f,"\$minder[\"NR\"]=\"".$_POST["minderNR"]."\";\n");
			fputs($f,"\$treuh[\"NR\"]=\"".$_POST["treuhNR"]."\";\n");
			fputs($f,"\$paypal[\"NR\"]=\"".$_POST["paypalNR"]."\";\n");
			fputs($f,"\$div16[\"TXT\"]=\"".$div16txt."\";\n");
			fputs($f,"\$div07[\"TXT\"]=\"".$div07txt."\";\n");
			fputs($f,"\$versand[\"TXT\"]=\"".$versandtxt."\";\n");
			fputs($f,"\$nachn[\"TXT\"]=\"".$nachntxt."\";\n");
			fputs($f,"\$minder[\"TXT\"]=\"".$mindertxt."\";\n");
			fputs($f,"\$treuh[\"TXT\"]=\"".$treuhtxt."\";\n");
			fputs($f,"\$paypal[\"TXT\"]=\"".$paypaltxt."\";\n");
			fputs($f,"\$bgcol[1]=\"#ddddff\";\n");
			fputs($f,"\$bgcol[2]=\"#ddffdd\";\n");
			fputs($f,"\$preA=\"".$_POST["preA"]."\";\n");
			fputs($f,"\$preK=\"".$_POST["preK"]."\";\n");
			fputs($f,"\$auftrnr=\"".$_POST["auftrnr"]."\";\n");
			fputs($f,"\$kdnum=\"".$_POST["kdnum"]."\";\n");
			fputs($f,"\$pricegroup=\"".$_POST["pricegroup"]."\";\n");
			fputs($f,"\$showErr=\"true\";\n");
			fputs($f,"?>");
			fclose($f);
			require "conf.php";
		} else {
			$ERPuser=$_POST["ERPuser"];
			$ERPpass=$_POST["ERPpass"];
			$ERPhost=$_POST["ERPhost"];
			$ERPdbname=$_POST["ERPdbname"];
			$ERPusrN=$_POST["ERPusrN"];
			$ERPdir=$_POST["ERPdir"];
			$ERPimgdir=$_POST["ERPimgdir"];
			$maxSize=$_POST["maxSize"];
			$ERPftphost=$_POST["ERPftphost"];
			$ERPftpuser=$_POST["ERPftpuser"];
			$ERPftppwd=$_POST["ERPftppwd"];
			$SHOPuser=$_POST["SHOPuser"];
			$SHOPpass=$_POST["SHOPpass"];
			$SHOPhost=$_POST["SHOPhost"];
			$SHOPdbname=$_POST["SHOPdbname"];
			$SHOPdir=$_POST["SHOPdir"];
			$SHOPimgdir=$_POST["SHOPimgdir"];
			$SHOPftphost=$_POST["SHOPftphost"];
			$SHOPftpuser=$_POST["SHOPftpuser"];
			$SHOPftppwd=$_POST["SHOPftppwd"];
			$div16NR=$_POST["div16NR"];
			$div07NR=$_POST["div07NR"];
			$versandNR=$_POST["versandNR"];
			$nachnNR=$_POST["nachnNR"];
			$treuhNR=$_POST["treuhNR"];
			$minderNR=$_POST["minderNR"];
			$paypalNR=$_POST["paypalNR"];
			$preA=$_POST["preA"];
			$preK=$_POST["preK"];
			$kdnum=$_POST["kdnum"];
			$pricegroup=$_POST["pricegroup"];
			$auftrnr=$_POST["auftrnr"];
		}
	}	else {
		require "conf.php";
	}
	?>
<html>
<body>
<center>
<table style="background-color:#cccccc" border="0">
<form name="ConfEdit" method="post" action="confedit.php">
<input type="hidden" name="div16ID" value="<?= $div16["ID"] ?>">
<input type="hidden" name="div07ID" value="<?= $div07["ID"] ?>">
<input type="hidden" name="minderID" value="<?= $minder["ID"] ?>">
<input type="hidden" name="versandID" value="<?= $versand["ID"] ?>">
<input type="hidden" name="nachnID" value="<?= $nachn["ID"] ?>">
<input type="hidden" name="paypalID" value="<?= $paypal["ID"] ?>">
<input type="hidden" name="treuhID" value="<?= $treuh["ID"] ?>">
<input type="hidden" name="ERPusrID" value="<?= $ERPusr["ID"] ?>">

<tr><th>Daten</th><th>Lx-ERP</th><th></th><th>Shop</th></tr>
<tr>
	<td>db-Host</td>
	<td colspan="2"><input type="text" name="ERPhost" size="25" value="<?= $ERPhost ?>"></td>
	<td><input type="text" name="SHOPhost" size="25" value="<?= $SHOPhost ?>"></td>
</tr>
<tr>
	<td>Database</td>
	<td colspan="2"><input type="text" name="ERPdbname" size="20" value="<?= $ERPdbname ?>"></td>
	<td><input type="text" name="SHOPdbname" size="20" value="<?= $SHOPdbname ?>"></td>
</tr>
<tr>
	<td>db-User Name</td>
	<td colspan="2"><input type="text" name="ERPuser" size="15" value="<?= $ERPuser ?>"></td>
	<td><input type="text" name="SHOPuser" size="15" value="<?= $SHOPuser ?>"></td>
</tr>
<tr>
	<td>db-User PWD</td>
	<td colspan="2"><input type="text" name="ERPpass" size="15" value="<?= $ERPpass ?>"></td>
	<td><input type="text" name="SHOPpass" size="15" value="<?= $SHOPpass ?>"></td>
</tr>
<tr>
	<td>User-ID</td>
	<td colspan="2"><input type="text" name="ERPusrN" size="10" value="<?= $ERPusr["Name"] ?>">
		<input type="checkbox" name="a1" <?= (empty($ERPusr["ID"])?"":"checked") ?>></td>
	<td></td>
</tr>
<tr>
	<td>CSV-Dir</td>
	<td colspan="2"><input type="text" name="ERPdir" size="30" value="<?= $ERPdir ?>"></td>
	<td><input type="text" name="SHOPdir" size="30" value="<?= $SHOPdir ?>"></td>
</tr>
<tr>
	<td>Image-Dir</td>
	<td colspan="2"><input type="text" name="ERPimgdir" size="30" value="<?= $ERPimgdir ?>"></td>
	<td><input type="text" name="SHOPimgdir" size="30" value="<?= $SHOPimgdir ?>"></td>
</tr>
<tr>
	<td>FTP-Host</td>
	<td colspan="2"><input type="text" name="ERPftphost" size="20" value="<?= $ERPftphost ?>"></td>
	<td><input type="text" name="SHOPftphost" size="20" value="<?= $SHOPftphost ?>"></td>
</tr>
<tr>
	<td>FTP-User</td>
	<td colspan="2"><input type="text" name="ERPftpuser" size="15" value="<?= $ERPftpuser ?>"></td>
	<td><input type="text" name="SHOPftpuser" size="15" value="<?= $SHOPftpuser ?>"></td>
</tr>
<tr>
	<td>FTP-User PWD</td>
	<td colspan="2"><input type="text" name="ERPftppwd" size="15" value="<?= $ERPftppwd ?>"></td>
	<td><input type="text" name="SHOPftppwd" size="15" value="<?= $SHOPftppwd ?>"></td>
</tr>
<tr>
	<td>ID Diverse 16%</td>
	<td><input type="text" name="div16NR" size="10" value="<?= $div16["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($div16["ID"])?"":"checked") ?>></td>
	<td>ID Diverse 7%</td>
	<td><input type="text" name="div07NR" size="10" value="<?= $div07["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($div07["ID"])?"":"checked") ?>></td>
</tr>
<tr>
	<td>ID Versand</td>
	<td><input type="text" name="versandNR" size="10" value="<?= $versand["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($versand["ID"])?"":"checked") ?>></td>
	<td>ID Nachname</td>
	<td><input type="text" name="nachnNR" size="10" value="<?= $nachn["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($nachn["ID"])?"":"checked") ?>></td>
</tr>
<tr>
	<td>ID Paypal</td>
	<td><input type="text" name="paypalNR" size="10" value="<?= $paypal["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($paypal["ID"])?"":"checked") ?>></td>
	<td>ID Treuhand</td>
	<td><input type="text" name="treuhNR" size="10" value="<?= $treuh["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($treuh["ID"])?"":"checked") ?>></td>
</tr>
<tr>
	<td>ID Mindermenge</td>
	<td><input type="text" name="minderNR" size="10" value="<?= $minder["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($minder["ID"])?"":"checked") ?>></td>
	<td>Preisgruppe</td>
	<td><select name="pricegroup">
<? pg($pricegroup); ?>
	    </select></td>
</tr>
<tr>
	<td colspan="2">Auftragsnummern durch</td>
	<td><input type="radio" name="auftrnr" value="1" <?= ($auftrnr==1)?"checked":"" ?>> LxO</td>
	<td><input type="radio" name="auftrnr" value="0" <?= ($auftrnr<>1)?"checked":"" ?>> Shop</td>
</tr>
<tr>
	<td colspan="2">Kundennummern durch</td>
	<td><input type="radio" name="kdnum" value="1" <?= ($kdnum==1)?"checked":"" ?>> LxO</td>
	<td><input type="radio" name="kdnum" value="0" <?= ($kdnum<>1)?"checked":"" ?>> Shop</td>
</tr>
<tr>
	<td colspan="2">Nummernerweiterung</td>
	<td>Auftrag<input type="text" name="preA" size="5" value="<?= $preA ?>"></td>
	<td>Kunde<input type="text" name="preK" size="5" value="<?= $preK ?>"></td>
</tr>
<!--tr>
	<td>Bildergr&ouml;sse (byte)</td>
	<td><input type="text" name="maxSize" size="10" value="<?= $maxSize ?>"></td>
	<td></td>
</tr-->




<tr><td colspan="4" align="center"><input type="submit" name="ok" value="sichern"></td></tr>
</form>
</table>
</center>
</body>
</html>
<? } ?>
