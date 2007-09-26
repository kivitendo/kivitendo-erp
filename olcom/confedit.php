<?
// $Id: confedit.php,v 1.3 2004/06/30 11:34:30 hli Exp $
if (!isset($_SERVER['PHP_AUTH_USER'])) {
       Header("WWW-Authenticate: Basic realm=\"Configurations-Editor\"");
       Header("HTTP/1.0 401 Unauthorized");
       echo "Sie m&uuml;ssen sich autentifizieren\n";
       exit;
} else {
	$login=($_GET["login"])?$_GET["login"]:$_POST["login"];
        if (file_exists ("conf$login.php")) {
                require "conf$login.php";
        } else {
                require "conf.php";
        }
	if ($_SERVER['PHP_AUTH_USER']<>$ERPftpuser || $_SERVER['PHP_AUTH_PW']<>$ERPftppwd) {
		Header("WWW-Authenticate: Basic realm=\"My Realm\"");
		Header("HTTP/1.0 401 Unauthorized");
		echo "Sie m&uuml;ssen sich autentifizieren\n";
		exit;
	}
	require_once "DB.php";
	function pg($sel) {
	global $dbP;
		echo "\t<option value=0";
		if ($sel==0) echo " selected";
		echo ">Standard VK\n";
		if (!$dbP) return;
		$sql="select id,pricegroup from pricegroup";
		$pgs=$dbP->getall($sql);
		if ($pgs) foreach ($pgs as $row) {
			echo "\t<option value=".$row[0];
			if ($sel==$row[0]) echo " selected";
			echo ">".$row[1]."\n";
		}
	}
	function shoplang($sel,$default) {
	global $dbM;
		$sql="SELECT L.*, C.configuration_value FROM languages L LEFT JOIN configuration C ";
		$sql.="ON L.code = C.configuration_value";
		$rs=$dbM->getAll($sql,DB_FETCHMODE_ASSOC);
	        if (!$rs) {
        	      echo "\t\t<option value='0'>keine Sprachen\n";
	        } else {
			echo "\t\t<option value='0' ".(($sel==0)?"selected":"").">nicht verwenden\n";
			foreach ($rs as $row) {
				if ($default["id"]<>$row["languages_id"]) {
					echo "\t\t<option value='".$row["languages_id"]."' ";
					echo (($row["languages_id"]==$sel)?"selected":"").">";
					echo ($row["code"]==$row["configuration_value"])?"!":" ";
					echo $row["name"]."\n";
				}
			}
		}
	}
	function erplang($sel) {
	global $dbP;
		$sql="select * from language";
		$rs=$dbP->getAll($sql,DB_FETCHMODE_ASSOC);
	        if (!$rs) {
        	      echo "\t\t<option>keine Sprachen\n";
	        } else {
			//echo "\t\t<option value='0' ".(($sel==0)?"selected":"").">Standard\n";
			foreach ($rs as $row) {
				echo "\t\t<option value='".$row["id"]."' ";
				echo ($sel==$row["id"])?"selected":"";
				echo ">".$row["description"]."\n";
			}
		}
	}
	function getERPlangs() {
	global $dbP;
		$sql="select * from language";
		$rs=$dbP->getAll($sql,DB_FETCHMODE_ASSOC);
		return $rs;
	}
	function getShopDefault() {
	global $dbM;
		if (!$dbM) return false;
		$sql="select * from languages L left join configuration C on L.code=C.configuration_value ";
		$sql.="where  configuration_key = 'DEFAULT_LANGUAGE'";
		$rs=$dbM->getAll($sql,DB_FETCHMODE_ASSOC);
		if ($rs) {
		        return array("id"=>$rs[0]["languages_id"],"name"=>$rs[0]["name"]);
		} else  {
			return 0;
		}
	}
	if ($_POST["ok"]=="sichern") {
		$ok=true;
		if ($_POST["ERPpass"]) {
			$dsnP="pgsql://".$_POST["ERPuser"].":".$_POST["ERPpass"]."@".$_POST["ERPhost"]."/".$_POST["ERPdbname"];
		} else {
			$dsnP="pgsql://".$_POST["ERPuser"]."@".$_POST["ERPhost"]."/".$_POST["ERPdbname"];
		}
		$dbP=@DB::connect($dsnP);
		if (DB::isError($dbP)||!$dbP) {
			$ok=false;
			echo "Keine Verbindung zur ERP<br>";
			echo $dbP->userinfo;
			$dbP=false;
		} else {
			//Steuertabelle ERP
            $sql ="select  BG.id as bugru,T.rate,TK.startdate from buchungsgruppen BG left join chart C ";
            $sql.="on BG.income_accno_id_0=C.id left join taxkeys TK on TK.chart_id=C.id left join tax T ";
            $sql.="on T.id=TK.tax_id where TK.startdate <= now()";
            $rs=$dbP->getAll($sql,DB_FETCHMODE_ASSOC);
            $erptax=array();
            foreach ($rs as $row) {
                 if ($erptax[$row["bugru"]]["startdate"]<$row["startdate"]) {
                      $erptax[$row["bugru"]]["startdate"]=$row["startdate"];
                      $erptax[$row["bugru"]]["rate"]=sprintf("%1.4f",$row["rate"]*100);
                 }
            }
            $sql ="select  P.id,P.description,P.buchungsgruppen_id as bugru from ";
            $sql.="parts P where P.partnumber = '%s'";
			$rs=$dbP->getall(sprintf($sql,$_POST["div16NR"]));
			$_POST["div16ID"]=$rs[0][0];
			$div16txt=$rs[0][1];
			$_POST["div16TAX"]=$erptax[$rs[0][2]]["rate"];
			$rs=$dbP->getall(sprintf($sql,$_POST["div07NR"]));
			$_POST["div07ID"]=$rs[0][0];
			$_POST["div07TAX"]=$erptax[$rs[0][2]]["rate"];
			$div07txt=$rs[0][1];
			$rs=$dbP->getall(sprintf($sql,$_POST["versandNR"]));
			$_POST["versandID"]=$rs[0][0];
			$_POST["versandTAX"]=$erptax[$rs[0][2]]["rate"];
			$versandtxt=$rs[0][1];
			$rs=$dbP->getall(sprintf($sql,$_POST["nachnNR"]));
			$_POST["nachnID"]=$rs[0][0];
			$_POST["nachnTAX"]=$erptax[$rs[0][2]]["rate"];
			$nachntxt=$rs[0][1];
			$rs=$dbP->getall(sprintf($sql,$_POST["minderNR"]));
			$_POST["minderID"]=$rs[0][0];
			$_POST["minderTAX"]=$erptax[$rs[0][2]]["rate"];
			$mindertxt=$rs[0][1];
			$rs=$dbP->getall(sprintf($sql,$_POST["paypalNR"]));
			$_POST["paypalID"]=$rs[0][0];
			$_POST["paypalTAX"]=$erptax[$rs[0][2]]["rate"];
			$paypaltxt=$rs[0][1];
			$rs=$dbP->getall("select id from employee where login = '".$_POST["ERPusrN"]."'");
			$_POST["ERPusrID"]=$rs[0][0];
		}
		if ($_POST["SHOPpass"]) {
			$dsnM="mysql://".$_POST["SHOPuser"].":".$_POST["SHOPpass"]."@".$_POST["SHOPhost"]."/".$_POST["SHOPdbname"];
		} else {
			$dsnM="mysql://".$_POST["SHOPuser"]."@".$_POST["SHOPhost"]."/".$_POST["SHOPdbname"];
		}
		$dbM=@DB::connect($dsnM);
		if (DB::isError($dbM)||!$dbM) {
			$ok=false;
			echo "Keine Verbindung zum Shop<br>";
			echo $dbM->userinfo;
			$dbM=false;
		};
		if ($ok) {
			$ShopDefaultLang=getShopDefault();
			$f=fopen("conf$login.php","w");
			$v="1.6";
			$d=date("Y/m/d H:i:s");
			fputs($f,"<?\n// Verbindung zur ERP-db\n");
			fputs($f,"\$ERPuser=\"".$_POST["ERPuser"]."\";\n");
			fputs($f,"\$ERPpass=\"".$_POST["ERPpass"]."\";\n");
			fputs($f,"\$ERPhost=\"".$_POST["ERPhost"]."\";\n");
			fputs($f,"\$ERPport=\"".$_POST["ERPport"]."\";\n");
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
			fputs($f,"\$SHOPport=\"".$_POST["SHOPport"]."\";\n");
			fputs($f,"\$SHOPdbname=\"".$_POST["SHOPdbname"]."\";\n");
			fputs($f,"\$dbprefix=\"".$_POST["dbprefix"]."\";\n");
			fputs($f,"\$SHOPlang=\"".$_POST["SHOPlang"]."\";\n");
			fputs($f,"\$SHOPdns=\"mysql://\$SHOPuser:\$SHOPpass@\$SHOPhost/\$SHOPdbname\";\n");
			fputs($f,"\$SHOPdir=\"".$_POST["SHOPdir"]."\";\n");
			fputs($f,"\$SHOPimgdir=\"".$_POST["SHOPimgdir"]."\";\n");
			fputs($f,"\$SHOPftphost=\"".$_POST["SHOPftphost"]."\";\n");
			fputs($f,"\$SHOPftpuser=\"".$_POST["SHOPftpuser"]."\";\n");
			fputs($f,"\$SHOPftppwd=\"".$_POST["SHOPftppwd"]."\";\n");
			fputs($f,"\$versand[\"ID\"]=\"".$_POST["versandID"]."\";\n");
			fputs($f,"\$div16[\"ID\"]=\"".$_POST["div16ID"]."\";\n");
			fputs($f,"\$div07[\"ID\"]=\"".$_POST["div07ID"]."\";\n");
			fputs($f,"\$nachn[\"ID\"]=\"".$_POST["nachnID"]."\";\n");
			fputs($f,"\$minder[\"ID\"]=\"".$_POST["minderID"]."\";\n");
			fputs($f,"\$paypal[\"ID\"]=\"".$_POST["paypalID"]."\";\n");
			fputs($f,"\$versand[\"TAX\"]=\"".$_POST["versandTAX"]."\";\n");
			fputs($f,"\$div16[\"TAX\"]=\"".$_POST["div16TAX"]."\";\n");
			fputs($f,"\$div07[\"TAX\"]=\"".$_POST["div07TAX"]."\";\n");
			fputs($f,"\$nachn[\"TAX\"]=\"".$_POST["nachnTAX"]."\";\n");
			fputs($f,"\$minder[\"TAX\"]=\"".$_POST["minderTAX"]."\";\n");
			fputs($f,"\$paypal[\"TAX\"]=\"".$_POST["paypalTAX"]."\";\n");
			fputs($f,"\$versand[\"NR\"]=\"".$_POST["versandNR"]."\";\n");
			fputs($f,"\$div16[\"NR\"]=\"".$_POST["div16NR"]."\";\n");
			fputs($f,"\$div07[\"NR\"]=\"".$_POST["div07NR"]."\";\n");
			fputs($f,"\$nachn[\"NR\"]=\"".$_POST["nachnNR"]."\";\n");
			fputs($f,"\$minder[\"NR\"]=\"".$_POST["minderNR"]."\";\n");
			fputs($f,"\$paypal[\"NR\"]=\"".$_POST["paypalNR"]."\";\n");
			fputs($f,"\$div16[\"TXT\"]=\"".$div16txt."\";\n");
			fputs($f,"\$div07[\"TXT\"]=\"".$div07txt."\";\n");
			fputs($f,"\$versand[\"TXT\"]=\"".$versandtxt."\";\n");
			fputs($f,"\$nachn[\"TXT\"]=\"".$nachntxt."\";\n");
			fputs($f,"\$minder[\"TXT\"]=\"".$mindertxt."\";\n");
			fputs($f,"\$paypal[\"TXT\"]=\"".$paypaltxt."\";\n");
			fputs($f,"\$bgcol[1]=\"#ddddff\";\n");
			fputs($f,"\$bgcol[2]=\"#ddffdd\";\n");
			fputs($f,"\$preA=\"".$_POST["preA"]."\";\n");
			fputs($f,"\$preK=\"".$_POST["preK"]."\";\n");
			fputs($f,"\$auftrnr=\"".$_POST["auftrnr"]."\";\n");
			fputs($f,"\$debug=".$_POST["debug"].";\n");
			fputs($f,"\$kdnum=\"".$_POST["kdnum"]."\";\n");
			fputs($f,"\$stdprice=\"".$_POST["stdprice"]."\";\n");
			fputs($f,"\$altprice=\"".$_POST["altprice"]."\";\n");
			fputs($f,"\$KDGrp=\"".$_POST["KDGrp"]."\";\n");
			fputs($f,"\$nopic=\"".$_POST["nopic"]."\";\n");
			fputs($f,"\$showErr=\"true\";\n");
			$Language=array();
			$DefaultLangOk=false;
			if ($_POST["ERPlang"]) foreach ($_POST["ERPlang"] as $key=>$val) {
				if ($_POST["SHOPlang"][$key]==$ShopDefaultLang["id"]) $DefaultLangOk=true;
					$sl=($_POST["SHOPlang"][$key])?$_POST["SHOPlang"][$key]:0;
					fputs($f,"\$Language[$key]=array(\"ERP\"=>$val,\"SHOP\"=>".$sl.");\n");
			}
			if (!$DefaultLangOk) {
				fputs($f,"\$SHOPdbname=\"\";\n");
				echo "Es wurde keine ERP-Sprache der Shopdefaultsprache zugewiesen.";
				echo "Verbindung zum Shop abgebrochen<br>";
			}
			fputs($f,"\$SHOPdefaultlang=\"".$ShopDefaultLang["id"]."\";\n");
			fputs($f,"\$SpracheAlle=\"".$_POST["SpracheAlle"]."\";\n");
			fputs($f,"?>");
			fclose($f);
			require "conf$login.php";
			if ($dbprefix<>"") $pre=$dbprefix."_";
			$sql="select count(*) from ".$pre."customers_number";
			$rc=@$dbM->query($sql);
			if ($rc->code==-18) {
				$sql="CREATE TABLE ".$pre."customers_number (  cid int(6) NOT NULL auto_increment,  customers_id int(3) NOT NULL default '0', ";
				$sql.="kdnr int NOT NULL default '0', shipto int,  PRIMARY KEY  (cid)) TYPE=MyISAM";
				$rc=@$dbM->query($sql);
				if ($rc->code==-1) {
					echo "Fehler beim Erzeugen der Tabelle '".$pre."customers_number' in der Shop-db";
				} else {
					echo "Tabelle '".$pre."customers_number' in der Shop-db angelegt.";
				}
			} else {
				$sql="select shipto from ".$pre."customers_number limit 1";
				$rc=@$dbM->query($sql);
				if ($rc->code==-19) {
					$sql="alter table ".$pre."customers_number add column shipto int";
					$rc=@$dbM->query($sql);
                                	if ($rc->code==-1) {
						echo "Fehler beim Anlegen der Spalte 'shipto' in 'customers_number'";
					} else {
						echo "'shipto' in 'customers_number' angelegt.";
					}
				}
			}
		} else {
			$ERPuser=$_POST["ERPuser"];
			$ERPpass=$_POST["ERPpass"];
			$ERPhost=$_POST["ERPhost"];
			$ERPport=$_POST["ERPport"];
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
			$SHOPport=$_POST["SHOPport"];
			$SHOPdbname=$_POST["SHOPdbname"];
			$dbprefix=$_POST["dbprefix"];
			$SHOPlang=$_POST["SHOPlang"];
			$SHOPdir=$_POST["SHOPdir"];
			$SHOPimgdir=$_POST["SHOPimgdir"];
			$SHOPftphost=$_POST["SHOPftphost"];
			$SHOPftpuser=$_POST["SHOPftpuser"];
			$SHOPftppwd=$_POST["SHOPftppwd"];
			$div16NR=$_POST["div16NR"];
			$div07NR=$_POST["div07NR"];
			$versandNR=$_POST["versandNR"];
			$nachnNR=$_POST["nachnNR"];
			$minderNR=$_POST["minderNR"];
			$paypalNR=$_POST["paypalNR"];
			$preA=$_POST["preA"];
			$preK=$_POST["preK"];
			$kdnum=$_POST["kdnum"];
			$auftrnr=$_POST["auftrnr"];
			$debug=$_POST["debug"];
			$altprice=$_POST["altprice"];
			$stdprice=$_POST["stdprice"];
			$nopic=$_POST["nopic"];
		}
		$ERPlangs=getERPlangs();
                $CntERPLang=count($ERPlangs); //$rs[0][0];
	} else {
		if (file_exists ("conf$login.php")) {
                	require "conf$login.php";
	       	} else {
               		require "conf.php";
	       	}
		$dsnP = array(
                    'phptype'  => 'pgsql',
                    'username' => $ERPuser,
                    'password' => $ERPpass,
                    'hostspec' => $ERPhost,
                    'database' => $ERPdbname,
                    'port'     => $ERPport
                );
                $dbP=@DB::connect($dsnP);
                if (DB::isError($dbP)||!$dbP) {
                        echo "Keine Verbindung zur ERP<br>";
                        $dbP=false;
                        //echo $dbP->userinfo;
                } else {
                        //$rs=$dbP->getAll("select count(*) from language");
                        $ERPlangs=getERPlangs();
                        $CntERPLang=count($ERPlangs); //$rs[0][0];
                }
                $dsnM = array(
                    'phptype'  => 'mysql',
                    'username' => $SHOPuser,
                    'password' => $SHOPpass,
                    'hostspec' => $SHOPhost,
                    'database' => $SHOPdbname,
                    'port'     => $SHOPport
                );
                $dbM=@DB::connect($dsnM);
                if (DB::isError($dbM)||!$dbM) {
                        echo "Keine Verbindung zum SHOP<br>";
                        //echo $dbM->userinfo;
                		$dbM=false;
                } else {
                        $ShopDefaultLang=getShopDefault();
                }
	}
	?>
<html>
<body>
<center>
<table style="background-color:#cccccc">
<form name="ConfEdit" method="post" action="confedit.php">
<input type="hidden" name="div16ID" value="<?= $div16["ID"] ?>">
<input type="hidden" name="div07ID" value="<?= $div07["ID"] ?>">
<input type="hidden" name="minderID" value="<?= $minder["ID"] ?>">
<input type="hidden" name="versandID" value="<?= $versand["ID"] ?>">
<input type="hidden" name="nachnID" value="<?= $nachn["ID"] ?>">
<input type="hidden" name="paypalID" value="<?= $paypal["ID"] ?>">
<input type="hidden" name="ERPusrID" value="<?= $ERPusr["ID"] ?>">
<input type="hidden" name="login" value="<?= $login ?>">
<tr><th>Daten</th><th>Lx-ERP</th><th></th><th>Shop</th></tr>
<tr>
	<td>db-Host</td>
	<td colspan="2"><input type="text" name="ERPhost" size="25" value="<?= $ERPhost ?>"></td>
	<td><input type="text" name="SHOPhost" size="25" value="<?= $SHOPhost ?>"></td>
</tr>
<tr>
	<td>Port</td>
	<td colspan="2"><input type="text" name="ERPport" size="25" value="<?= $ERPport ?>"></td>
	<td><input type="text" name="SHOPport" size="25" value="<?= $SHOPport ?>"></td>
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
		<input type="checkbox" name="a1" <?= (empty($ERPusr["ID"])?"":"checked") ?> onFocus="blur();">
		&nbsp;&nbsp;&nbsp;&nbsp;db-Prefix
	</td>
	<td><input type="text" name="dbprefix" size="15" value="<?= $dbprefix ?>"></td>
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
	<td>ID Mindemenge</td>
	<td><input type="text" name="minderNR" size="10" value="<?= $minder["NR"] ?>">
		<input type="checkbox" name="a1" <?= (empty($minder["ID"])?"":"checked") ?>></td>
</tr>
<tr>
        <td >Sprachen</td>
        <td ><input type="hidden" name="ERPlang[0]" value="0">Standard</td>
        <td >--&gt;</td>
        <td ><input type="hidden" name="SHOPlang[0]" value="<?= $ShopDefaultLang["id"] ?>"><?= $ShopDefaultLang["name"] ?></td>
</tr>
<? for($i=0; $i < $CntERPLang; $i++) {  ?>
<tr>
        <td >Sprachen</td>
        <td><input type="hidden" name="ERPlang[<?= $i+1 ?>]" value="<?= $ERPlangs[$i]["id"] ?>"><?= $ERPlangs[$i]["description"] ?>
        <td >--&gt;</td>
        <td ><select name="SHOPlang[<?= $i+1 ?>]">
<?= shoplang($Language[$i+1]["SHOP"],$ShopDefaultLang); ?>
        </select></td>
</tr>
<? } ?>
<tr>
        <td colspan="2">Nur &uuml;bersetzte Artikel</td>
        <td><input type="radio" name="SpracheAlle" value="true"  <?= ($SpracheAlle=="true")?"checked":"" ?>> Ja</td>
        <td><input type="radio" name="SpracheAlle" value="false" <?= ($SpracheAlle<>"true")?"checked":"" ?>> Nein</td>
</tr>
<tr>
	<td>Standardpreis</td>
	<td><select name="stdprice">
<? pg($stdprice); ?>
	    </select></td>
	<td>Defaultbild</td>
	<td><input type="text" name="nopic" size="20" value="<?= $nopic ?>">
<tr>
	<td>abweichender Preis</td>
	<td><select name="altprice">
<? pg($altprice); ?>
	    </select></td>
	<td>Kundengruppe</td>
	<td><input type="text" name="KDGrp" size="3" value="<?= $KDGrp ?>">
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
<tr>
	<td>Logging</td>
	<td>ein<input type="radio" name="debug" value="true" <?= ($debug=="true")?"checked":"" ?>>
	aus<input type="radio" name="debug" value="false" <?= ($debug!="true")?"checked":"" ?>></td>
	<td></td><td></td>
</tr>

<tr><td colspan="4" align="center"><input type="submit" name="ok" value="sichern"></td></tr>
</form>
</table>
</center>
</body>
</html>
<? } ?>
