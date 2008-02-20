<?
/***************************************************************
*Author: Holger Lindemann
*Copyright: (c) 2004 Lx-System
*License: non free
*eMail: info@lx-system.de
*Version: 1.6
*Shop: xt::Commerce
*ERP: Lx-Office ERP 2.4.x
***************************************************************/
/*
* Noch einzubauen:
*/
//echo <<<EOF
echo "<html>";
echo "	<head><title>Lx-ERP Export der Shopartikel</title>";
echo '	<link type="text/css" REL="stylesheet" HREF="css/main.css"></link>';
echo "<body>";
//EOF;

require_once "shoplib.php";


/**********************************************
* getAttribut($oid,$pid)
*
**********************************************/
function getAttribut($oid,$pid) {
	$sql="select * from orders_products_attributes where orders_id=$oid and orders_products_id=$pid";
	$rs=getAll("shop",$sql,"getAttribut");
	$txt="";
	foreach ($rs as $zeile) {
		$txt.="\n - ".$zeile["products_options"].":".$zeile["products_options_values"];
	};
	return $txt;
}

/**********************************************
* getBrutto($id)
*
**********************************************/
function getBrutto($id) {
	$sql="select * from orders_total where orders_id=$id and class='ot_total'";
	$rs=getAll("shop",$sql,"getBrutto");
	return $rs[0]["value"];
}

/**********************************************
* getMwst($id)
*
**********************************************/
function getMwst($id) {
	$sql="select * from orders_total where orders_id=$id and class='ot_tax'";
	$rs=getAll("shop",$sql,"getMwst");
	$mwst=0;
	if ($rs) {
		foreach ($rs as $zeile) {
			$mwst+=$zeile["value"];
		}
	}
	return $mwst;
}

/**********************************************
* getSonderkosten($id,$art)
*
**********************************************/
function getSonderkosten($id,$art) {
	$sql="select * from orders_total where orders_id=$id and class='".$GLOBALS["skosten"][$art]."'";
	$rs=getAll("shop",$sql,"getSonderkosten");
	if ($rs[0]["value"]) {
		$kosten=round($rs[0]["value"]/(100+$GLOBALS["versand"]["TAX"])*100,2);
	} else {
		$kosten=false;
	}
	return $kosten;
}

/**********************************************
* insBestArtikel($zeile,$transID)
*
**********************************************/
function insBestArtikel($ordersID,$transID) {
global $div07,$div16;
	$sql="select * from orders_products where orders_id=$ordersID";
	$rs=getAll("shop",$sql,"insBestArtikel");
	$ok=true;
	if ($rs) foreach ($rs as $zeile) {
		$sql="select * from parts where partnumber='".$zeile["products_model"]."'";
		$rs2=getAll("erp",$sql,"insBestArtikel");
		if ( $rs2[0]["id"]) {$artID=$rs2[0]["id"]; $artNr=$rs2[0]["partnumber"]; }
		else {
			if ($zeile["products_tax"]=="19.0000") {
				$artID=$div16["ID"];
				$artNr=$div16["NR"];
			} else {
				$artID=$div07["ID"];
				$artNr=$div07["NR"];
			};
		}
		$preis=round($zeile["products_price"]/(100+$zeile["products_tax"])*100,2);
		$text=getAttribut($ordersID,$zeile["orders_products_id"]);
		$sql="insert into orderitems (trans_id, parts_id, description, qty, sellprice, unit, ship, discount) values (";
		$sql.=$transID.",".$artID.",'".$zeile["products_name"].$text."',".$zeile["products_quantity"].",".$preis.",'Stck',0,0)";
		echo " - Artikel:[ BuNr.:$artID ArtNr:<b>$artNr</b> ".$zeile["products_name"]." ]<br>";
		$rc=query("erp",$sql,"insBestArtikel");
		if ($rc === -99) { $ok=false; break; };
	}
	return $ok;
}

function insAuftrag($data) {
global $ERPusr,$versand,$nachn,$minder,$paypal,$auftrnr;
	$Zahlmethode=array("authorizenet"=>"Authorize.net","banktransfer"=>"Lastschriftverfahren","cc"=>"Kreditkarte",
		"cod"=>"Nachnahme","eustandardtransfer"=>"EU-Standard Bank Transfer","iclear"=>"iclear Rechnungskauf",
		"invoice"=>"Rechnung","ipayment"=>"iPayment","liberecobanktransfer"=>"Lastschriftverfahren",
		"liberecocc"=>"Kreditkarte","moneybookers"=>"Moneybookers.com","moneyorder"=>"Scheck/Vorkasse",
		"nochex"=>"NOCHEX","paypal"=>"PayPal","pm2checkout"=>"2CheckOut","psigate"=>"PSiGate",
		"qenta"=>"qenta.at","secpay"=>"SECPay");
	$brutto=getBrutto($data["orders_id"]);
	$mwst=getMwst($data["orders_id"]);
	$netto=$brutto-$mwst;
	$versandK=getSonderkosten($data["orders_id"],"Versand");
	$nachnK  =getSonderkosten($data["orders_id"],"NachName");
	$mindermK=getSonderkosten($data["orders_id"],"Minder");
	$paypalK =getSonderkosten($data["orders_id"],"Paypal");
	// Hier beginnt die Transaktion
	$rc=query("erp","BEGIN WORK","insAuftrag");
	if ($rc === -99) { echo "Probleme mit Transaktion. Abbruch!"; exit(); };
	if ($auftrnr) {
		$auftrag=$GLOBALS["preA"].getNextAnr();
	} else {
		$auftrag=$GLOBALS["preA"].$data["orders_id"];
	}
	$sql="select count(*) as cnt from oe where ordnumber = '$auftrag'";
	$rs=getAll("erp",$sql,"insAuftrag 1");
	if ($rs[0]["cnt"]>0) {
		$auftrag=$GLOBALS["preA"].getNextAnr();
	}
	$newID=uniqid (rand());
	$sql="insert into oe (notes,ordnumber,cusordnumber) values ('$newID','$auftrag','".$data["kdnr"]."')";
	$rc=query("erp",$sql,"insAuftrag 2");
	if ($rc === -99) {
		echo "Auftrag ".$data["orders_id"]." konnte nicht angelegt werden.<br>";
		$rc=query("erp","ROLLBACK WORK","chkKunde");
		echo "Auftrag ".$data["orders_id"]." konnte nicht angelegt werden.<br>";
		return false;
	}
	$sql="select * from oe where notes = '$newID'";
	$rs2=getAll("erp",$sql,"insAuftrag 3");
	if (!$rs2>0) {
		echo "Auftrag ".$data["orders_id"]." konnte nicht angelegt werden.<br>";
		$rc=query("erp","ROLLBACK WORK","chkKunde");
		echo "Auftrag ".$data["orders_id"]." konnte nicht angelegt werden.<br>";
		return false;
	}
	$BEZAHLEN=$Zahlmethode[$data["payment_method"]]."\n";
	if ($data["cc_type"]) {
		$BEZAHLEN.=$data["cc_type"]."\n".$data["cc_owner"]."\n".$data["cc_number"]."\n".$data["cc_expires"]."\n";
	} else if ($data["banktransfer_blz"]) {
		$BEZAHLEN.="Kontoinhaber: ".$data["banktransfer_owner"]."\nBanknummer: ".$data["banktransfer_blz"];
		$BEZAHLEN.="\nBank: ".$data["banktransfer_bankname"]."\nKontonummer: ".$data["banktransfer_number"]."\n";
	}
	$sql="update oe set cusordnumber=".$data["orders_id"].", transdate='".$data["date_purchased"]."', customer_id=".$data["kdnr"].", ";
	$sql.="amount=".$brutto.", netamount=".$netto.", reqdate='".$data["date_purchased"]."', taxincluded='f', ";
	if ($data["shipto"]>0) $sql.="shipto_id=".$data["shipto"].", ";
	$sql.="intnotes='".$data["comments"]."',notes='".$BEZAHLEN."', curr='EUR',employee_id=".$ERPusr["ID"].", vendor_id=0 ";
	$sql.="where id=".$rs2[0]["id"];
	$rc=query("erp",$sql,"insAuftrag 4");
	if ($rc === -99) {
		echo "Auftrag ".$data["orders_id"]." konnte nicht angelegt werden.<br>";
		$rc=query("erp","ROLLBACK WORK","chkKunde");
		if ($rc === -99) { echo "Probleme mit Transaktion. Abbruch!"; exit(); };
		return false;
	}
	echo "Auftrag:[ Buchungsnummer:".$rs2[0]["id"]." AuftrNr:<b>".$auftrag."</b> ]<br>";
	if (!insBestArtikel($data["orders_id"],$rs2[0]["id"])) {
		echo "Auftrag ".$data["orders_id"]." konnte nicht angelegt werden.<br>";
		$rc=query("erp","ROLLBACK WORK","chkKunde");
		if ($rc === -99) { echo "Probleme mit Transaktion. Abbruch!"; exit(); };
		return false;
	};
	if ($versandK) {
		$sql="insert into orderitems (trans_id, parts_id, description, qty, sellprice, unit, ship, discount) values (";
		$sql.=$rs2[0]["id"].",".$versand["ID"].",'".$versand["TXT"]."',1,".$versandK.",'mal',0,0)";
		$rc=query("erp",$sql,"insAuftrag 8");
		if ($rc === -99) echo "Auftrag $auftrag : Fehler bei den Versandkosten<br>";
	}
	if ($nachnK) {
		$sql="insert into orderitems (trans_id, parts_id, description, qty, sellprice, unit, ship, discount) values (";
		$sql.=$rs2[0]["id"].",".$nachn["ID"].",'".$nachn["TXT"]."',1,".$nachnK.",'mal',0,0)";
		$rc=query("erp",$sql,"insAuftrag 9");
		if ($rc === -99) echo "Auftrag $auftrag : Fehler bei den Nachnamekosten<br>";
	}
	if ($mindermK) {
		$sql="insert into orderitems (trans_id, parts_id, description, qty, sellprice, unit, ship, discount) values (";
		$sql.=$rs2[0]["id"].",".$minder["ID"].",'".$minder["TXT"]."',1,".$mindermK.",'mal',0,0)";
		$rc=query("erp",$sql,"insAuftrag 10");
		if ($rc === -99) echo "Auftrag $auftrag : Fehler beim Mindermengenzuschlag<br>";
	}
	if ($paypalK) {
		$sql="insert into orderitems (trans_id, parts_id, description, qty, sellprice, unit, ship, discount) values (";
		$sql.=$rs2[0]["id"].",".$paypal["ID"].",'".$paypal["TXT"]."',1,".$paypalK.",'mal',0,0)";
		$rc=query("erp",$sql,"insAuftrag 11");
		if ($rc === -99) echo "Auftrag $auftrag : Fehler bei den PayPal-Kosten<br>";
	}
	$sql="update orders set orders_status ='3' WHERE orders_id =".$data["orders_id"];
	$rc=query("shop",$sql,"insBestArtikel 12");
	if ($rc === -99) echo "Bestellung im Shop nicht geschlossen";
	$rc=query("erp","COMMIT WORK","chkKunde");
	if ($rc === -99) { echo "Probleme mit Transaktion. Abbruch!"; exit(); };
	return true;
}

/**********************************************
* getBestellung()
*
**********************************************/
function getBestellung() {
	$sql="select b.*,h.comments,o.*,cn.kdnr from orders o left join orders_status_history h on h.orders_id=o.orders_id ";
	$sql.="left join banktransfer b on b.orders_id =o.orders_id left join customers_number cn on ";
	$sql.="cn.customers_id=o.customers_id where o.orders_status=1 order by o.orders_id";
	$rs=getAll("shop",$sql,"getBestellung");
	return $rs;
}

/**********************************************
* chkKdData()
*
**********************************************/
function chkKunden() {
	$felder=array("firstname","lastname","company","street_address","city","postcode","country");
	foreach ($GLOBALS["bestellungen"] as $bestellung) {
		$rc=query("erp","BEGIN WORK","chkKunden");
		if ($rc === -99) { echo "Probleme mit Transaktion. Abbruch!"; exit(); };
		if ($bestellung["kdnr"]>0) { // Bestandskunde; kdnr == ID in customers
			$msg="update ";
			$kdnr=chkOldKd($bestellung);
			if ($kdnr == -1) { //Kunde nicht gefunden, neu anlegen.
				$msg="insert ";
				$kdnr=insNewKd($bestellung);
				$GLOBALS["neuKd"]++;
			} else if (!$kdnr) {
				echo $msg." ".$bestellung["customers_name"]." fehlgeschlagen!<br>";
				$GLOBALS["gesKd"]++;
				continue;
			}
		} else { // Neukunde
			$msg="insert ";
			$kdnr=insNewKd($bestellung);
			$GLOBALS["neuKd"]++;
		}
		echo $bestellung["customers_company"]." ".$bestellung["customers_name"]." $kdnr<br>";
		$GLOBALS["bestellungen"][$GLOBALS["gesKd"]]["kdnr"]=$kdnr;
		$sql="delete from customers_number where customers_id=".$bestellung["customers_id"];
        	$rc=query("shop",$sql,"chkKunde");
        	$sql="insert into customers_number (customers_id,kdnr) values(".$bestellung["customers_id"].",".$kdnr.")";
        	$rc=query("shop",$sql,"chkKunde");
		if ($kdnr>0) {
			foreach($felder as $feld) {
				if ($bestellung["delivery_$feld"]<>$bestellung["customers_$feld"]) {
					$rc=insShData($bestellung,$kdnr);
					if ($rc>0) $GLOBALS["bestellungen"][$GLOBALS["gesKd"]]["shipto"]=$rc;
					break;
				}
			}
		}
		if (!$kdnr || $rc === -99) {
			echo $msg." ".$bestellung["customers_name"]." fehlgeschlagen! ($kdnr,$rc)<br>";
			$rc=query("erp","ROLLBACK WORK","chkKunde");
			if ($rc === -99) { echo "Probleme mit Transaktion. Abbruch!"; exit(); };
		} else {
			$rc=query("erp","COMMIT WORK","chkKunde");
			if ($rc === -99) { echo "Probleme mit Transaktion. Abbruch!"; exit(); };
		}		$GLOBALS["gesKd"]++;
	}
	return true;
}

function chkOldKd($data) {
	$sql="select * from customer where id = ".$data["kdnr"];
	$rs=getAll("erp",$sql,"chkKdData");
	if (!$rs || $rs[0]["id"]<>$data["kdnr"]) { return -1; }; // Kunde nicht gefunden
	if ($rs[0]["zipcode"]<>$data["customers_postcode"]) $set.="zipcode='".$data["customers_postcode"]."',";
	if ($rs[0]["city"]<>$data["customers_city"]) $set.="city='".$data["customers_city"]."',";
	if (in_array($data["customers_country"],$GLOBALS["LAND"])) {
		if ($rs[0]["country"]<>$GLOBALS["LAND"][$data["customers_country"]]) $set.="country='".$GLOBALS["LAND"][$data["customers_country"]]."',";
	} else {
		if ($rs[0]["country"]<>$data["customers_country"]) $set.="country='".$data["customers_country"]."',";
	}
	if ($rs[0]["phone"]<>$data["customers_phone"])$set.="phone='".$data["customers_phone"]."',";
	if ($rs[0]["email"]<>$data["customers_email_address"])$set.="email='".$data["customers_mail_address"]."',";
	if ($data["customers_company"]) {
		if ($rs[0]["name"]<>$data["customers_company"]) $set.="name='".$data["customers_company"]."',";
		if ($rs[0]["contact"]<>$data["customers_name"]) $set.="contact='".$data["customers_name"]."',";
	} else {
		if ($rs[0]["name"]<>$data["customers_name"]) $set.="name='".$data["customers_lastname"].", ".$data["customers_firstname"]."',";
	}
	if ($rs[0]["street"]<>$data["customers_street_address"]) $set.="street='".$data["customers_street_address"]."',";
	if ($set) {
		$sql="update customer set ".substr($set,0,-1)." where id=".$rs[0]["id"];
		$rc=query("erp",$sql,"chkKdData");
		if ($rc === -99) {
			return false;
		} else {
			return $data["kdnr"];
		}
	} else {
		return $data["kdnr"];
	}
}

/**********************************************
* insShData($data,$id)
*
**********************************************/
function insShData($data,$id) {
	$set=$id;
	if ($data["delivery_company"]) { $set.=",'".$data["delivery_company"]."','".$data["delivery_name"]."',"; }
	else { $set.=",'".$data["delivery_name"]."','',"; }
	$set.="'".$data["delivery_street_address"]."',";
	$set.="'".$data["delivery_postcode"]."',";
	$set.="'".$data["delivery_city"]."',";
	if (in_array($data["delivery_country"],$GLOBALS["LAND"])) {
		$set.="'".$GLOBALS["LAND"][$data["delivery_country"]]."',";
	} else {
		$set.="'".$data["delivery_country"]."',";
	}
	$set.="'".$data["customers_telephone"]."',";
	$set.="'".$data["customers_email_address"]."'";
	$sql="insert into shipto (trans_id,shiptoname,shiptodepartment_1,shiptostreet,shiptozipcode,shiptocity,";
	$sql.="shiptocountry,shiptophone,shiptoemail,module) values ($set,'CT')";
	$rc=query("erp",$sql,"insShData");
	if ($rc === -99) return false;
	$sql="select shipto_id from shipto where trans_id = $id and module='CT' order by itime desc limit 1";
	$rs=getAll("erp",$sql,"insKdData");
	if ($rs[0]["shipto_id"]>0) {
		$sid=$rs[0]["shipto_id"];
		$sql="update customers_number set shipto = $sid where kdnr = $id";
		$rc2=query("shop",$sql,"insShData");
        	if ($rc2 === -99) {
        		$sql="delete from shipto where shipto_id=$sid";
        		$rc=query("shop",$sql,"insShData");
			return false;
		}
		return $sid;
	} else  {
		echo "Fehler bei abweichender Anschrift ".$data["delivery_name"];
		$sql="delete from shipto where shipto_id=$sid";
        	$rc=query("shop",$sql,"insShData");
		return false;
	}
}

/**********************************************
* insKdData($BID)
*
**********************************************/
function insNewKd($data) {
	$taxid=array("DE"=>0,"CH"=>2,"AU"=>1,"FR"=>1,"IT"=>1,"ES"=>1,"NL"=>1); // Muß erweitert werden
	$taxidL=array("Germany"=>0,"Switzerland"=>2,"Austria"=>1,"France"=>1,"Italy"=>1,"Spain"=>1,"Netherlands"=>1); // Muß erweitert werden
	$newID=uniqid(rand(time(),1));
	//Kundennummer generieren
	if ($GLOBALS["kdnum"]==1) { // von der ERP
		$kdnr=$GLOBALS["preK"].getNextKnr();
	} else {		    // durch Shop
		$kdnr=$GLOBALS["preK"].$data["customers_id"];
	}
	$sql="select count(*) as cnt from customer where customernumber = '$kdnr'";
	$rs=getAll("erp",$sql,"insKdData");
	if ($rs[0]["cnt"]>0) {  // Kundennummer gibt es schon, eine neue aus ERP
		$kdnr=$GLOBALS["preK"].getNextKnr();
	}
	$sql="insert into customer (name,customernumber) values ('$newID','$kdnr')";
	$rc=query("erp",$sql,"insKdData");
	if ($rc === -99) return false;
	$sql="select * from customer where name = '$newID'";
	$rs=getAll("erp",$sql,"insKdData");
	if (!$rs) return false;
	if ($data["customers_company"]) {
		$set.="set name='".$data["customers_company"]."',contact='".$data["customers_name"]."',";
	}else {
		$set.="set name='".$data["customers_lastname"].", ".$data["customers_firstname"]."',";
		$set.="contact='".$data["customers_name"]."',";
	}
	$set.="street='".$data["customers_street_address"]."',";
	$set.="zipcode='".$data["customers_postcode"]."',";
	$set.="city='".$data["customers_city"]."',";
	$set.="country='".$data["delivery_country_iso_code_2"]."',";
	$set.="phone='".$data["customers_telephone"]."',";
	$set.="email='".$data["customers_email_address"]."',";
	if ($data["delivery_country_iso_code_2"]) {
		$tid=(in_array($data["delivery_country_iso_code_2"],$taxid))?$taxid[$data["delivery_country_iso_code_2"]]:0;
	} else {
		$tid=(in_array($data["delivery_country"],$taxidL))?$taxidL[$data["delivery_country"]]:0;
	}
	if (!$tid) $tid=0;
	$set.="taxzone_id=$tid,";
	$set.="taxincluded='f' ";
	$sql="update customer ".$set;
	$sql.="where id=".$rs[0]["id"];
	$rc=query("erp",$sql,"insKdData");
	if ($rc === -99) {
		$sql="delete from customer where id=".$rs[0]["id"];
        	$rc=query("shop",$sql,"insNewKd");
		return false;
	} else { return $rs[0]["id"]; }
}

$LAND=array("Germany"=>"D","Austria"=>"A","Switzerland"=>"CH");
$skosten=array("Versand"=>"ot_shipping","NachName"=>"ot_cod_fee","Paypal"=>"ot_paypal","Minder"=>"ot_loworderfee");
$bestellungen=getBestellung();
$ok=count($bestellungen);
$gesKd=0;
$neuKd=0;
if ($ok) {
	echo "Es liegen $ok Bestellungen vor. <br>";
	chkKunden();
	echo $gesKd." Kunde(n), davon ".$neuKd." neue(r) Kunde(n).<br>";
	foreach ($bestellungen as $bestellung) {
		insAuftrag($bestellung);
	}
} else { echo "Es liegen keine Bestellungen vor!<br>"; };
?>
<!--a href='trans.php'>zur&uuml;ck</a-->
</body>
</html>
