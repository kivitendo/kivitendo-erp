<?php
/***************************************************************
* $Id: shopimport_db.php,v 1.5 2006/02/06 13:49:11 hli Exp $
*Author: Holger Lindemann
*Copyright: (c) 2004 Lx-System
*License: non free
*eMail: info@lx-system.de
*Version: 1.0.0
*Shop: PHPeppershop 2.0
*ERP: Lx-Office ERP
***************************************************************/
require_once "conf.php";
require_once "DB.php";

$db=DB::connect($SHOPdns);
if (!$db) dbFehler("",$db->getDebugInfo());
if (DB::isError($db)) {
	dbFehler("",$db->getDebugInfo());
	die ($db->getDebugInfo());
};
$db2=DB::connect($ERPdns);
if (!$db2) dbFehler("",$db2->getDebugInfo());
if (DB::isError($db2)) {
	dbFehler("",$db2->getDebugInfo());
	die ($db2->getDebugInfo());
};
/****************************************************
* dbFehler
* in: sql,err = string
* out:
* Fehlermeldungen ausgeben
*****************************************************/
function dbFehler($sql,$err) {
global $showErr;
    if ($showErr)
           echo "</td></tr></table><font color='red'>$sql : $err</font><br>";
}

// Ab hier Artikelexport aus ERP
function shopartikel() {
global $db2,$pricegroup;
	if ($pricegroup>0) {
		$sql="SELECT P.partnumber,P.description,P.weight,(t.rate * 100) as rate,G.price as sellprice,P.sellprice as stdprice, ";
		$sql.="PG.partsgroup,P.notes,P.image,P.onhand FROM ";
		$sql.="chart c left join tax t on c.taxkey_id=t.taxkey, parts P left join partsgroup PG on PG.id=P.partsgroup_id left join prices G on G.parts_id=P.id ";
		$sql.="where P.shop='t' and c.id=p.income_accno_id  and (G.pricegroup_id=$pricegroup or G.pricegroup_id is null)";
	} else {
		$sql="SELECT P.partnumber,P.description,P.weight,(t.rate * 100) as rate,P.sellprice,PG.partsgroup,P.notes,P.image,P.onhand FROM ";
		$sql.="chart c left join tax t on c.taxkey_id=t.taxkey, parts P left join partsgroup PG on ";
		$sql.="PG.id=P.partsgroup_id where P.shop='t'  and c.id=p.income_accno_id";
	}
	$rs=$db2->getAll($sql,DB_FETCHMODE_ASSOC);
	return $rs;
}

// Ab hier Import der Daten in den Shop
function createCategory($name,$maingroup,$tab) {
global $db,$langs;
	$newID=uniqid(rand());
	$sql="insert into kategorien (Bild_gross,Bild_last_modified) values ('$newID',now())";
	$rc=$db->query($sql);
	$sql="select * from kategorien where Bild_gross = '$newID'";
	$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
	if ($rs) {
		$id=$rs[0]["Kategorie_ID"];
		$u=($maingroup=="Null")?"is Null":"=$maingroup";
		$sql="select max(Positions_Nr) as Max from kategorien where  Unterkategorie_von $u";
		$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
		$pos=$rs[0]["Max"]+1;
		$sql="update kategorien set Unterkategorie_von=%s, Name='%s', Positions_Nr=%d,MwSt_Satz=%0.2f, Details_anzeigen='N', Bild_gross = Null where kategorie_ID=%d";
		echo "($name) ";
		$rc=$db->query(sprintf($sql,$maingroup,$name,$pos,$mwst,$id));
		return ($rc)?$id:false;
	} else {
		return false;
	}
}
function getCategory($name) {
global $db;
	if (empty($name)) $name="Default";
	preg_match("/^(\[(.*)\])?([^!]+)!?(.*)/",$name,$ref);
	if ($ref[1]<>""){
		$tab=$ref[2];
		$main=$ref[3];
		if ($ref[4]<>"") {
			$sub=$ref[4];
		} else {
			$sub=false;
		}
	} else if ($ref[3]<>"" and $ref[3]<>$ref[0]) {
		$tab=false;
		$main=$ref[3];
		if ($ref[4]<>"") {
			$sub=$ref[4];
		} else {
			$sub=false;
		}
	} else  {
		$tab=false;
		$sub=false;
		if (substr($name,0,1)=="[") {
			$main="Default";			
		} else {
			$main=$name;
		}
	}
	$found=true;
	// suche die Hauptgruppe
	$sql="select * from kategorien where Name like '".$main."' and  Unterkategorie_von is Null";
	$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
	if ($rs[0]["Kategorie_ID"]) {  // gefunden
		$maingroup=$rs[0]["Kategorie_ID"];
	} else {					// nicht gefunden, anlegen
		$maingroup=createCategory($main,"Null","$tab");
	}
	echo $maingroup.":".$main." ";
	if ($sub && $maingroup) {
		// suche Unterkategorie wenn eine gegeben
		$sql="select * from kategorien where Name like '$sub' and  Unterkategorie_von = '$main'";
		$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
		if ($rs[0]["Kategorie_ID"]) {  // gefunden
			$maingroup=$rs[0]["Kategorie_ID"];
		} else {					// nicht gefunden, anlegen
			$maingroup=createCategory($sub,"'$main'","");
		}
	};
	echo $sub." ";
	return $maingroup;
}
function bilder($width,$height,$dest) {
	if (!function_exists("imagick_readimage")) { echo "Imagick-Extention nicht installiert"; return false; };
	$handle=imagick_readimage("./tmp/tmp.file_org");
	if (!$handle) {
		$reason      = imagick_failedreason( $handle ) ;
		print "Lesen: $reason<BR>\n" ; flush();
		return false;
	}
	if (!imagick_resize( $handle, $width, $height, IMAGICK_FILTER_UNKNOWN, 0)) {
		$reason      = imagick_failedreason( $handle ) ;
		print "Resize: $reason<BR>\n" ;	flush();
		return false;
	}
	if (!imagick_writeimage( $handle,"./tmp/tmp.file_$dest")) {
		$reason      = imagick_failedreason( $handle ) ;
		print "Schreiben: $reason<BR>\n" ; 	flush();
		return false;
	}
	return true;
}
function uploadImage($image,$ArtNr) {
global $db,$ERPftphost,$ERPftpuser,$ERPftppwd,$ERPimgdir,
		   $SHOPftphost,$SHOPftpuser,$SHOPftppwd,$SHOPimgdir,$iconsize;
	if ($ERPftphost=="localhost") {
		exec("cp $ERPimgdir/$image ./tmp/tmp.file_org",$aus,$rc2);
		if ($rc2>0) { echo "[Downloadfehler: $image]<br>"; return false; };
	} else {
		$conn_id = ftp_connect($ERPftphost);
		ftp_login($conn_id,$ERPftpuser,$ERPftppwd);
		$src=$ERPimgdir."/".$image;
		$upload=ftp_get($conn_id,"tmp/tmp.file_org","$src",FTP_BINARY);
		if (!$upload) { echo "[Ftp Downloadfehler! $image]<br>"; return false;};
		ftp_quit($conn_id);
	};
	bilder($iconsize,$iconsize,"smal");
	$rc=preg_match("#(.+/)?([^\.]+)\.(.+)$#",$image,$treffer);
	$gr=$treffer[2]."_gr.".$treffer[3];
	$kl=$treffer[2]."_kl.".$treffer[3];
	if ($SHOPftphost=="localhost") {
		$dst=$SHOPimgdir."/".$gr;
		exec("cp ./tmp/tmp.file_org $dst",$aus,$rc2);
		if ($rc2>0) { echo "[Uploadfehler: $dst]<br>";  return false; };
		$dst=$SHOPimgdir."/".$kl;
		exec("cp ./tmp/tmp.file_smal $dst",$aus,$rc2);
		if ($rc2>0) { echo "[Uploadfehler: $dst]<br>"; return false; };
	} else {
		$conn_id = ftp_connect($SHOPftphost);
		ftp_login($conn_id,$SHOPftpuser,$SHOPftppwd);
		ftp_chdir($conn_id,$SHOPimgdir);
		$upload=ftp_put($conn_id,$SHOPimgdir."/$gr","tmp/tmp.file_org",FTP_BINARY);
		if (!$upload) { echo "[Ftp Uploadfehler! $gr]<br>"; return false; };
		$upload=ftp_put($conn_id,$SHOPimgdir."/$kl","tmp/tmp.file_smal",FTP_BINARY);
		if (!$upload) { echo "[Ftp Uploadfehler! $kl]<br>"; return false; };
		ftp_quit($conn_id);
	}
	$sql="update artikel set Bild_gross='$gr', Bild_klein='$kl' where Artikel_ID=$ArtNr";
	$rc=$db->query($sql);
}
function insartikel($data) {
global $db;
	$newID=uniqid(rand());
	$sql="insert into artikel (Artikel_Nr,Name) values ('".$data["partnumber"]."','$newID')";
	$rc=$db->query($sql);
	$sql="select * from artikel where Name='$newID'";
	$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
	if ($rs) {
		$sql="insert into artikel_kategorie (FK_Artikel_ID,FK_Kategorie_ID) values (".$rs[0]["Artikel_ID"].",".$data["categories_id"].")";
		$rc=$db->query($sql);
		echo " insert ";
		updartikel($data,$rs[0]["Artikel_ID"]);
	} else { return false; }
}
function updartikel($data,$id) {
global $db;
	$sql ="update artikel set Preis=%01.2f,Gewicht=%0.2f,MwSt_Satz=%0.2f,letzteAenderung=now(),";
	$sql.="Name='%s',Beschreibung='%s',Lagerbestand=%d  where Artikel_ID=%d";
	$preis=($data["sellprice"]>0)?$data["sellprice"]:$data["stdprice"];
	$sql=sprintf($sql,$preis,$data["weight"],$tax[sprintf("%1.4f",$data["rate"])],$data["description"],$data["notes"],$data["onhand"],$id);
	$rc=$db->query($sql);
	$sql="update artikel_kategorie set FK_Kategorie_ID=".$data["categories_id"]." where FK_Artikel_ID=$id";
	$rc=$db->query($sql);
	echo "+++<br>";
}
function chkartikel($data) {
global $db,$shop2erp;
	if ($data["partnumber"]=="") { echo "Artikelnummer fehlt!<br>"; return false;};
	$sql="select * from artikel A left join artikel_kategorie K on A.Artikel_id=K.FK_Artikel_ID where Artikel_Nr like '".$data["partnumber"]."'";
	$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
	echo "(".$data["partnumber"]."->".$rs[0]["Artikel_ID"].":".$data["description"].")";
	if ($rs) {
		if ($data["image"]) {
			$rc=preg_match("#(.+/)?([^\.]+)\.(.+)$#",$data["image"],$treffer);
			if ($treffer) {	$data["picname"]=$treffer[2]."_gr.".$treffer[3]; }
			else {	$data["picname"]=""; };
		}
		$preis=($data["sellprice"]>0)?$data["sellprice"]:$data["stdprice"];
		     if ($rs[0]["Preis"]<>$preis)						{ updartikel($data,$rs[0]["Artikel_ID"]); }
		else if ($rs[0]["Gewicht"]<>$data["weight"])			{ updartikel($data,$rs[0]["Artikel_ID"]); }
		else if ($rs[0]["Name"]<>$data["description"])			{ updartikel($data,$rs[0]["Artikel_ID"]); }
		else if ($rs[0]["Beschreibung"]<>$data["notes"])		{ updartikel($data,$rs[0]["Artikel_ID"]); }
		else if ($rs[0]["MwSt_Satz"]<>$tax[sprintf("%1.4f",$data["rate"])])	{ updartikel($data,$rs[0]["Artikel_ID"]); }
		else if ($rs[0]["FK_Kategorie_ID"]<>$data["$categories_id"])		{ updartikel($data,$rs[0]["Artikel_ID"]); }
		else if ($rs[0]["Lagerbestand"]<>$data["onhand"])		{ updartikel($data,$rs[0]["Lagerbestand"]); }
		else { echo "...<br>"; };
		if ($rs[0]["Bild_gross"]<>$data["picname"] and $data["picname"])	{ uploadImage($data["image"],$rs[0]["Artikel_ID"]); }
		else if ($rs[0]["Bild_gross"] and !$data["picname"]) 		{
			$sql="update artikel set Bild_gross='', Bild_klein='' where Artikel_ID=".$rs[0]["Artikel_ID"];
			$rc=$db->query($sql);
		}
	} else {
		$Artikel_ID=insartikel($data);
		if ($data["image"]) 	uploadImage($data["image"],$Artikel_ID); 
	}
}

$artikel=shopartikel();
echo "Artikelexport ERP -&gt; PHPepper :".count($artikel)." Artikel markiert.<br>";
if ($artikel) {
	$sql="select Thumbnail_Breite from shop_settings";
	$rs=$db->getAll($sql,DB_FETCHMODE_ASSOC);
	if ($rs) {
		$iconsize=$rs[0]["Thumbnail_Breite"];
	} else {
		$iconsize=100;
	}
	foreach ($artikel as $data) {
		$data["categories_id"]=getCategory($data["partsgroup"]);
		$x=chkartikel($data);
	}
	require ("diff.php");
}

?>
