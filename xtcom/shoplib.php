<?php


$login=$_GET["login"];
$debug=false;
require_once "DB.php";
if (file_exists ("conf$login.php")) {
	require "conf$login.php";
} else {
	require "conf.php";
}

$landarray=array("DEUTSCHLAND"=>"D","STEREICH"=>"A","OESTEREICH"=>"A","SCHWEIZ"=>"CH");
$taxarray=array("D"=>0,"A"=>1,"CH"=>2);
$defaultland="D";
$taxid=0;
$log=false;
$erp=false;
$shop=false;

//$PGdns = "user='$ERPuser' password='$ERPpass' host='$ERPhost' dbname='$ERPdbname' port='$ERPport'";

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
               'port'     => $SHOPport);

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


//$shopdata=array("firma"=>"","abteilung"=>"","vorname"=>"","nachname"=>"","strasse"=>"","plz"=>"","ort"=>"","telefon"=>"","email"=>"","land"=>"","fax"=>"","notiz"=>"","postfach"=>"")
$shopdata=array(	"id"=>"customers_id","kdnr"=>"customers_cid","bid"=>"orders_id", "anrede"=>" customers_gender",
			"firma"=>"customers_company", "nachname"=>"customers_lastname", "vorname"=>"customers_firstname",
			"strasse"=>"customers_street_address","plz"=>"customers_postcode","ort"=>"customers_city","land"=>"customers_country",
			"telefon"=>"customers_phone","email"=>"customers_email_address","fax"=>"Fax","notiz"=>"comments",

			"netto"=>"ot_subtotal","steuer"=>"ot_tax","datum"=>" date_purchased","bemerkung"=>"comments",
			"artnr"=>"products_id","preis"=>"final_price","artikeltxt"=>" products_name","menge"=>" products_quantity");

$shopartikel=array(	"id"=>"Artikel_ID","artnr"=>"Artikel_Nr","arttxt"=>"Name","artbeschr"=>"Beschreibung","gruppe"=>"Kategorie_ID",
			"preis"=>"Preis","preis2"=>"Haendlerpreis","preis3"=>"Aktionspreis","gewicht"=>"Gewicht",
			"bild"=>"Bild_gross","bestand"=>"Lagerbestand","minbestand"=>"Mindestlagermenge","steuer"=>"MwSt_Satz");


/****************************************************
* Ab hier Artikelexport aus ERP
****************************************************/
// Ab hier Artikelexport aus ERP nur eine Sprache
function shopartikellang($lang,$alle) {
	$sql="SELECT P.partnumber,L.translation,P.description,L.longdescription,P.notes,PG.partsgroup ";
	$sql.="FROM parts P left join translation L on L.parts_id=P.id left join partsgroup PG on PG.id=P.partsgroup_id ";
	$sql.="WHERE P.shop='t' and (L.language_id = $lang";
	if ($alle) {
		$sql.=" or L.language_id is Null)";
	} else { $sql.=")"; };
	$rs=getAll("erp",$sql,"shopartikellang");
	$data=array();
	if ($rs) foreach ($rs as $row) {
		if (!$data[$row["partnumber"]])	$data[$row["partnumber"]]=$row;
	}
	return $data;
}
// Ab hier alle Artikelexport aus ERP Defaultsprache
function shopartikel() {
global $stdprice,$altprice;
	if ($stdprice>0) {
		$sql="SELECT P.partnumber,P.description,P.weight,(t.rate * 100) as rate,G.price as sellprice,P.sellprice as stdprice, ";
		$sql.="PG.partsgroup,P.notes,P.image,P.onhand,G.pricegroup_id,P.buchungsgruppen_id as bugru FROM ";
		$sql.="chart c left join tax t on c.taxkey_id=t.taxkey, parts P left join partsgroup PG on ";
		$sql.="PG.id=P.partsgroup_id left join prices G on G.parts_id=P.id ";
		$sql.="left join buchungsgruppen B  on P.buchungsgruppen_id = B.id ";
		$sql.="where P.shop='t' and c.id=B.income_accno_id_0  and ";
		$sql.="(G.pricegroup_id=$stdprice or G.pricegroup_id=$altprice or G.pricegroup_id is null) ";
		$sql.="order by P.partnumber";
	} else {
		$sql="SELECT P.partnumber,P.description,P.weight,(t.rate * 100) as rate,P.sellprice,PG.partsgroup,";
		$sql.="P.notes,P.image,P.onhand,P.buchungsgruppen_id as bugru FROM ";
		$sql.="chart c left join tax t on c.taxkey_id=t.taxkey, parts P left join partsgroup PG on ";
		$sql.="PG.id=P.partsgroup_id left join buchungsgruppen B  on P.buchungsgruppen_id = B.id ";
		$sql.="WHERE P.shop='t'  and c.id=B.income_accno_id_0";
	}
	$rs=getAll("erp",$sql,"shopartikel");
	$i=0;
	$data=array();
	if ($rs) foreach ($rs as $row) {
		if (!$data[$row["partnumber"]])	$data[$row["partnumber"]]=$row;
		if ($row["pricegroup_id"]==$altprice) {
			$data[$row["partnumber"]]["altprice"]=($row["sellprice"])?$row["sellprice"]:$row["stdprice"];
		} else {
			$data[$row["partnumber"]]["sellprice"]=($row["sellprice"])?$row["sellprice"]:$row["stdprice"];
		}
		$i++;
	}
	
	return $data;
}

/****************************************************
* Artikelexport in ERP importieren
****************************************************/
function insertArtikel($data) {
global $shopartikel;
	foreach ($data as $row) {
		$pg=$GLOBALS["warengruppen"][$row[$shopartikel["gruppe"]]]["partsgroup"];
		$bg=$GLOBALS["buchungsgruppen"][sprintf("%0.2f",$row[$shopartikel["steuer"]])];
		$artnr=($row[$shopartikel["artnr"]])?$row[$shopartikel["artnr"]]:getArtnr();
		$sqltmp="insert into parts (partnumber,description,notes,weight,onhand,rop,image,sellprice,unit,partsgroup_id,buchungsgruppen_id) ";
		$sqltmp.="values ('%s','%s','%s',%0.5f,%0.5f,%0.5f,'%s',%0.5f,'%s',%d,%d)";
		$sql=sprintf($sqltmp,$artnr,$row[$shopartikel["arttxt"]],$row[$shopartikel["artbeschr"]],
				$row[$shopartikel["gewicht"]],$row[$shopartikel["bestand"]],$row[$shopartikel["minbestand"]],
				$row[$shopartikel["bild"]],$row[$shopartikel["preis"]],$row[$shopartikel["einheit"]],$pg,$bg);
		$rc=query("erp",$sql,"insertArtikel");
		if ($rc === -99) {
			echo $row[$shopartikel["id"]]." ".$row[$shopartikel["arttxt"]]." nicht importiert<br>";
		} else {
			echo "";
		}
		echo $sql."<br>";
	}
}

/****************************************************
* Nächste Artikelnummer (ERP) holen
****************************************************/
function getArtnr() {
	$sql="select * from defaults";
	$sql1="update defaults set articlenumber='";
	if ($rc === -99) {
		echo "Kann keine Artikelnummer erzeugen - Abbruch";
		exit();
	}
	$rs2=getAll("erp",$sql,"getArtnr");
	$artnr=$rs2[0]["articelnumber"]+1;
	$rc=query("erp",$sql1.$artnr."'","getArtnr");
	if ($rc === -99) {
		echo "Kann keine Artikelnummer erzeugen - Abbruch";
		$rc=query("erp","ROLLBACK","getArtnr");
		exit();
	}
	return $artnr;
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

function insPartgroup($kat) {
	$sql="insert into partsgroup () value ()";
	$GLOBALS["wg"]++;
	//$rc=query("erp",$sql,"insPartgroup");
	if ($rc === -99) { return false; }
	else { return $GLOBALS["wg"]; }
}
getBugru();
?>
