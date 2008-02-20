<?
/***************************************************************
* $Id: trans.php,v 1.1 2004/06/29 08:50:30 hli Exp $
*Author: Holger Lindemann
*Copyright: (c) 2004 Lx-System
*License: non free
*eMail: info@lx-system.de
*Version: 1.0.0
*Shop: xt:Commerce 2.2
*ERP: Lx-Office ERP
***************************************************************/
$login=($_GET["login"])?$_GET["login"]:$_POST["login"];
require_once "DB.php";
if (file_exists ("conf$login.php")) {
                require "conf$login.php";
        } else {
                require "conf.php";
        }
$ERPdsn = array(
                    'phptype'  => 'pgsql',
                    'username' => $ERPuser,
                    'password' => $ERPpass,
                    'hostspec' => $ERPhost,
                    'database' => $ERPdbname,
                    'port'     => $ERPport
                );

$LAND=array("Germany"=>"D");
$db=@DB::connect($SHOPdns);
if (DB::isError($db)||!$db) { $shop="<font color='red'>Fehler</font>"; } else { $shop="ok"; };
$db2=DB::connect($ERPdsn);
if (DB::isError($db2)||!$db2) { $erp="<font color='red'>Fehler</font>"; } else { $erp="ok"; };

?>
<html>
	<head>
		<title>Datenaustausch ERP-xt:Commerce</title>
	</head>
<body>
<center>
<table>
	<tr>
		<td colspan="2">
			Eine direkte Verbindung beider Datenbanken ist erforderlich!<br>
			Folgende Verbindungsdaten wurden gefunden:
		</td>
	</tr>
	<tr>
		<td>
			<b>Lx-ERP</b>
		</td>
		<td><?= $erp ?></td>
	</tr>
	<tr>
		<td>Datenbank-Server</td>
		<td><?= $ERPhost ?></td>
	</tr>
	<tr>
		<td>Datenbank</td>
		<td><?= $ERPdbname ?></td>
	</tr>
	<tr>
		<td>
			<b>xt:Commerce</b>
		</td>
		<td><?= $shop ?></td>
	</tr>
	<tr>
		<td>Datenbank-Server</td>
		<td><?= $SHOPhost ?></td>
	</tr>
	<tr>
		<td>Datenbank</td>
		<td><?= $SHOPdbname ?></td>
	</tr>
	<tr>
		<td colspan="2">
			<hr>
		</td>
	</tr>
	<tr>
		<td align="center"><a href="shopimport_db.php"><img src="e2s.gif" border="0"></a></td>
		<td align="center"><a href="xtcomexport.php"><img src="s2e.gif" border="0"></a></td>
	</tr>
	<tr>
		<td colspan="2">
			<hr>
		</td>
	</tr>
	<tr>
		<td colspan="2">
			F&uuml;r den Export der Artikeldaten aus der ERP in eine CSV-Datei<br>
			oder den Import der Artikeldaten in den Shop ist nur die Verbindung<br>
			zur entsprechenden	Datenbank notwendig.<br>
			Die CSV-Dateien werden in den konfigurierten Verzeichnissen erwartet.<br>
			Der Webserver ben&ouml;tigt hier Schreibrechte.
		</td>
	</tr>
	<tr>
		<td>
			<b>Lx-ERP</b>
		</td>
		<td><a href="<?= $ERPdir ?>"><?= $ERPdir ?></a></td>
	</tr>
	<tr>
		<td>
			<b>xt:Commerce</b>
		</td>
		<td><a href="<?= $SHOPdir ?>"><?= $SHOPdir ?></a></td>
	</tr>
	<tr>
		<td align="center"><a href="erpexport.php"><img src="e2c.gif" border="0"></a></td>
		<td align="center"><a href="shopimport_csv.php"><img src="c2s.gif" border="0"></a></td>
	</tr>
	<tr>
		<td colspan="2">
			<hr>
		</td>
	</tr>
	<tr>
		<td colspan="2">
			Copyright (c) 2004 Lx-System - Version: 1.0 - <a href="mailto:info@lx-system.de">info@lx-system.de</a>
		</td>
	</tr>
</table>
</center>
</body>
</html>
