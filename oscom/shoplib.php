<?php

$login=$_GET["login"];
$debug=false;
require_once "DB.php";
if (file_exists ("conf$login.php")) {
echo "User";
        require "conf$login.php";
} else {
echo "Global";
        require "conf.php";
}


$landarray=array("DEUTSCHLAND"=>"D","STEREICH"=>"A","OESTEREICH"=>"A","SCHWEIZ"=>"CH");
$EU=2;  //EU ohne UStID, 1 = EU mit UStID
$taxarray=array(
	'Germany'=>array('code'=>'DE','tax'=>0),		'Austria'=>array('code'=>'AU','tax'=>$EU), 			'Belgium'=>array('code'=>'BE','tax'=>$EU),
	'Bulgaria'=>array('code'=>'BG','tax'=>$EU),		'Czech Republic'=>array('code'=>'CZ','tax'=>$EU), 	'Denmark'=>array('code'=>'DK','tax'=>$EU),
	'Estonia'=>array('code'=>'EE','tax'=>$EU),		'Spain'=>array('code'=>'ES','tax'=>$EU), 			'Finland'=>array('code'=>'FI','tax'=>$EU),
	'France'=>array('code'=>'FR','tax'=>$EU), 		'United Kingdom'=>array('code'=>'GB','tax'=>$EU), 	'Greece'=>array('code'=>'GR','tax'=>$EU),
	'Hungary'=>array('code'=>'HU','tax'=>$EU),		'Ireland'=>array('code'=>'IE','tax'=>$EU), 			'Italy'=>array('code'=>'IT','tax'=>$EU),
	'Luxembourg'=>array('code'=>'LU','tax'=>$EU),	'Malta'=>array('code'=>'MT','tax'=>$EU), 			'Netherlands'=>array('code'=>'NL','tax'=>$EU),
	'Poland'=>array('code'=>'PL','tax'=>$EU),		'Portugal'=>array('code'=>'PT','tax'=>$EU), 		'Romania'=>array('code'=>'RO','tax'=>$EU),
	'Sweden'=>array('code'=>'SE','tax'=>$EU), 		'Slovenia'=>array('code'=>'SI','tax'=>$EU), 		'Slovakia (Slovak Republic)'=>array('code'=>'SK','tax'=>$EU),
	'Cyprus'=>array('code'=>'CY','tax'=>$EU), 		'Lithuania'=>array('code'=>'LT','tax'=>$EU), 		'Latvia'=>array('code'=>'LV','tax'=>$EU));

$defaultland="D";
$taxid=0;
$log=false;
$erp=false;
$shop=false;


$ERPdns= array('phptype'  => 'pgsql',
               'username' => $ERPuser,
               'password' => $ERPpass,
               'hostspec' => $ERPhost,
               'database' => $ERPdbname,
               'port'     => $ERPport);

$SHOPdns=array('phptype'  => 'mysql',
               'username' => $SHOPuser,
               'password' => $SHOPpass,
               'hostspec' => $SHOPhost,
               'database' => $SHOPdbname,
               'port'     => $SHOPport,
	       'AutoCommit' => 0);

/****************************************************
* Debugmeldungen in File schreiben
****************************************************/
if ($debug) { $log=fopen("tmp/shop.log","a"); } // zum Debuggen
else { $log=false; };

/****************************************************
* Shopverbindung aufbauen
****************************************************/
$shop=DB::connect($SHOPdns);
if (!$shop) shopFehler("",$shop->getDebugInfo());
if (DB::isError($shop)) {
	$nun=date("Y-m-d H:i:s");
	if ($log) fputs($log,$nun.": Shop-Connect\n");
	shopFehler("",$shop->getDebugInfo());
	die ($shop->getDebugInfo());
};

/****************************************************
* ERPverbindung aufbauen
****************************************************/
$erp=DB::connect($ERPdns);
if (!$erp) shopFehler("",$erp->getDebugInfo());
if (DB::isError($erp)) {
	$nun=date("Y-m-d H:i:s");
	if ($log) fputs($log,$nun.": ERP-Connect\n");
	shopFehler("",$erp->getDebugInfo());
	die ($erp->getDebugInfo());
} else {
	$erp->autoCommit(true);
};


/****************************************************
* SQL-Befehle absetzen
****************************************************/
function query($db,$sql,$function="--") {
	$nun=date("d.m.y H:i:s");
	//if ($db<>"shop") { echo "$sql!$db!<br>"; flush(); };
	if ($GLOBALS["log"]) fputs($GLOBALS["log"],$nun.": ".$function."\n".$sql."\n");
	$rc=$GLOBALS[$db]->query($sql);
 	if ($GLOBALS["log"]) fputs($GLOBALS["log"],print_r($rc,true)."\n");
 	if ($rc!==1) {
		return -99;
	} else {
                if ($GLOBALS["log"]) fputs($GLOBALS["log"],print_r($rs,true)."\n");
		return true;
	}
}

/****************************************************
* Datenbank abfragen
****************************************************/
function getAll($db,$sql,$function="--") {
	$nun=date("d.m.y H:i:s");
	if ($GLOBALS["log"]) fputs($GLOBALS["log"],$nun.": ".$function."\n".$sql."\n");
	$rs=$GLOBALS[$db]->getAll($sql,DB_FETCHMODE_ASSOC);
	if ($rs["message"]<>"") {
	       	if ($GLOBALS["log"]) fputs($GLOBALS["log"],print_r($rs,true)."\n");
		return false;
	} else {
	       	if ($GLOBALS["log"]) fputs($GLOBALS["log"],print_r($rs,true)."\n");
       	 	return $rs;
	}
}

/****************************************************
* shopFehler
* in: sql,err = string
* out:
* Fehlermeldungen ausgeben
*****************************************************/
function shopFehler($sql,$err) {
global $showErr;
	if ($showErr)
		echo "</td></tr></table><font color='red'>$sql : $err</font><br>";
}

/****************************************************
* Nächste Auftragsnummer (ERP) holen
****************************************************/
function getNextAnr() {
	$sql="select * from defaults";
	$sql1="update defaults set sonumber=";
	$rs2=getAll("erp",$sql,"getNextAnr");
	if ($rs2[0]["sonumber"]) {
		$auftrag=$rs2[0]["sonumber"]+1;
		$rc=query("erp",$sql1.$auftrag,"getNextAnr");
		if ($rc === -99) {
			echo "Kann keine Auftragsnummer erzeugen - Abbruch";
			exit();
		}
		return $auftrag;
	} else {
		return false;
	}
}

/****************************************************
* Nächste Kundennummer (ERP) holen
****************************************************/
function getNextKnr() {
	$sql="select * from defaults";
	$sql1="update defaults set customernumber='";
	$rs2=getAll("erp",$sql,"getNextKnr");
	if ($rs2[0]["customernumber"]) {
		$kdnr=$rs2[0]["customernumber"]+1;
		$rc=query("erp",$sql1.$kdnr."'","getNextKnr");
		if ($rc === -99) {
			echo "Kann keine Kundennummer erzeugen - Abbruch";
			exit();
		}
		return $kdnr;
	} else {
		return false;
	}
}


$buchungsgruppen=array();
$warengruppen=array();

function getBugru() {
	$sql ="select B.id,tax.rate from buchungsgruppen B left join chart on income_accno_id_0=chart.id left join taxkeys T on ";
	$sql.="T.chart_id=income_accno_id_0 left join tax on tax.id=T.tax_id where T.startdate<=now()";
	$rs=getAll("erp",$sql,"getBugru");
	if ($rs) foreach ($rs as $row) {
		$steuer=sprintf("%0.2f",$row["rate"]*100);
		$GLOBALS["buchungsgruppen"][$steuer]=$row["id"];
	}
}

$wg=1000;

getBugru();
?>
