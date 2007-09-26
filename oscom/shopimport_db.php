<?php
/***************************************************************
*Author: Holger Lindemann
*Copyright: (c) 2004 Lx-System
*License: non free
*eMail: info@lx-system.de
*Version: 1.6.0
*Shop: osCommerce 2.2
*ERP: Lx-Office ERP 2.4.x
***************************************************************/
require_once "shoplib.php";
$LAND=array("Germany"=>"D");
$nun=date("d.m.y H:i:s");

// Ab hier Artikelexport aus ERP
function shopartikel() {
global $pricegroup;
	if ($pricegroup>0) {
		$sql="SELECT P.partnumber,P.description,G.price as sellprice,P.sellprice as stdprice, ";
		$sql.="PG.partsgroup,P.notes,P.image,P.onhand,G.pricegroup_id,P.buchungsgruppen_id as bugru FROM ";
		$sql.="parts P left join partsgroup PG on ";
		$sql.="PG.id=P.partsgroup_id left join prices G on G.parts_id=P.id ";
		$sql.="where P.shop='t' and ";
		$sql.="(G.pricegroup_id=$pricegroup or G.pricegroup_id is null) ";
		$sql.="order by P.partnumber";
	} else {
		$sql="SELECT P.partnumber,P.description,P.weight,P.sellprice,PG.partsgroup,";
		$sql.="P.notes,P.image,P.onhand,P.buchungsgruppen_id as bugru ";
		$sql.="FROM parts P left join partsgroup PG on PG.id=P.partsgroup_id ";
		$sql.="left join buchungsgruppen B on P.buchungsgruppen_id = B.id ";
		$sql.="WHERE P.shop='t'";
	}
	$rs=getAll("erp",$sql,"shopartikel");
	return $rs;
}

// Ab hier Import der Daten in den Shop
function createCategory($name,$maingroup) {
global $defLang;
	$newID=uniqid(rand());
	$sql="insert into categories (categories_image,parent_id,date_added) values ('$newID',$maingroup,now())";
	$rc=query("shop",$sql,"createCategory");
	$sql="select * from categories where categories_image = '$newID'";
	$rs=getAll("shop",$sql,"createCategory");
	$id=$rs[0]["categories_id"];
	$sql="update categories set categories_image = 'pixel_trans.gif' where categories_id=$id";
	$rc=query("shop",$sql,"createCategory");
	echo "($name) ";
	$sql="insert into categories_description (categories_id,language_id,categories_name) values ($id,$defLang,'$name')";
	$rc=query("shop",$sql,"createCategory");
	return ($rc)?$id:false;
}
function getCategory($name) {
	if (empty($name)) $name="Default";
	$tmp=split("!",$name);
	$maingroup=0;
	$found=true;
	$i=0;
	do {
		$sql="select D.*,C.parent_id from categories C left join categories_description D on C.categories_id=D.categories_id ";
		$sql.="where categories_name like '".$tmp[$i]."' and C.parent_id=$maingroup";
		$rs=getAll("shop",$sql,"getCategory");
		if ($rs[0]["categories_id"]) {
			$maingroup=$rs[0]["categories_id"];
			$i++;
		} else {
			$found=false;
		}
	} while ($rs and $found and $i<count($tmp));
	for (;$i<count($tmp); $i++) {
		$maingroup=createCategory($tmp[$i],$maingroup);
	}
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
function uploadImage($image,$id) {
global $ERPftphost,$ERPftpuser,$ERPftppwd,$ERPimgdir,$maxSize,$SHOPftphost,$SHOPftpuser,$SHOPftppwd,$SHOPimgdir;
	$tmp=split("/",$image);
	$cnt=count($tmp)-1;
	$name=(strrpos($image,"/")>0)?substr($image,strrpos($image,"/")+1):$image;
	$ok=true;
	if ($ERPftphost==$SHOPftphost and $ERPftphost=="localhost") {
		$destdir=$SHOPimgdir."/".substr($image,0,strrpos($image,"/"));
		$ret=exec("mkdir -p $destdir/".$tmp[$i],$out,$rc);
		$rc=exec("cp $ERPimgdir/$image $SHOPimgdir/$image",$o2,$rc2);
		if ($rc2>0) { $ok=false; echo "Kopieren nicht erfolgreich $image<br>"; }
	} else if ($ERPftphost=="localhost") 	{
		$rc3=exec("cp $ERPimgdir/$image ./tmp/tmp.file",$o2,$rc2);
		if ($rc2>0) {
			echo "Kopieren nicht erfolgreich. ";
		} else {
			$conn_id = ftp_connect($SHOPftphost);
			ftp_login($conn_id,$SHOPftpuser,$SHOPftppwd);
			ftp_chdir($conn_id,$SHOPimgdir);
			for ($i=0; $i<$cnt; $i++) {
				@ftp_mkdir($conn_id,$tmp[$i]);
				@ftp_chdir($conn_id,$tmp[$i]);
			}
			$src=$SHOPimgdir."/".$image;
			$upload=ftp_put($conn_id,"$src","tmp/tmp.file",FTP_BINARY);
			if (!$upload) { $ok=false; echo "Ftp upload war fehlerhaft!";};
			ftp_quit($conn_id);
		}
	} else if ($SHOPftphost=="localhost") {
		$conn_id = ftp_connect($ERPftphost);
		ftp_login($conn_id,$ERPftpuser,$ERPftppwd);
		$src=$ERPimgdir."/".$image;
		$upload=ftp_get($conn_id,"tmp/tmp.file","$src",FTP_BINARY);
		if (!$upload) { $ok=false; echo "Ftp download war fehlerhaft!";};
		ftp_quit($conn_id);
		exec("cp tmp/tmp.file $SHOPimgdir/$image",$o2,$rc2);
		if ($rc2) { $ok=false; echo "Kopieren nicht erfolgreich"; }
	} else {
		$conn_id = ftp_connect($ERPftphost);
		ftp_login($conn_id,$ERPftpuser,$ERPftppwd);
		$src=$ERPimgdir."/".$image;
		$upload=ftp_get($conn_id,"tmp/tmp.file","$src",FTP_BINARY);
		if (!$upload) { $ok=false; echo "Ftp download war fehlerhaft!";};
		ftp_quit($conn_id);
		$conn_id = ftp_connect($SHOPftphost);
		ftp_login($conn_id,$SHOPftpuser,$SHOPftppwd);
		ftp_chdir($conn_id,$SHOPimgdir);
		for ($i=0; $i<$cnt; $i++) {
			@ftp_mkdir($conn_id,$tmp[$i]);
			@ftp_chdir($conn_id,$tmp[$i]);
		}
		$src=$SHOPimgdir."/".$image;
		$upload=ftp_put($conn_id,"$src","tmp/tmp.file",FTP_BINARY);
		if (!$upload) { $ok=false; echo "Ftp upload war fehlerhaft!";};
		ftp_quit($conn_id);
	}
	if ($ok) {
		$sql="update products set products_image='%s',products_last_modified=now() where products_id=%d";
		$sql=sprintf($sql,$image,$id);
		$rc=query("shop",$sql,"uploadImage");
	}
}
function insartikel($data) {
global $header,$defLang;
	echo " insert ";
	$newID=uniqid(rand());
	$sql="insert into products (products_model,products_image) values ('".$data["partnumber"]."','$newID')";
	$rc=query("shop",$sql,"insartikel");
	if ($rc === -99) { echo "Fehler.<br>"; return false; };
	$sql="select * from products where products_image='$newID'";
	$rs=getAll("shop",$sql,"insartikel");
	$sql="update products set products_image='pixel_trans.gif' where products_id=".$rs[0]["products_id"];
	$rc=query("shop",$sql,"insartikel");
	if ($rc === -99) { echo "Fehler.<br>"; return false; };
	$sql="insert into products_description (products_id,language_id,products_name) values (".$rs[0]["products_id"].",$defLang,' ')";
	$rc=query("shop",$sql,"insartikel");
	if ($rc === -99) { echo "Fehler.<br>"; return false; };
	$sql="insert into products_to_categories (products_id,categories_id) values (".$rs[0]["products_id"].",".$data["categories_id"].")";
	$rc=query("shop",$sql,"insartikel");
	if ($rc === -99) { echo "Fehler.<br>"; return false; };
	if (updartikel($data,$rs[0]["products_id"])) {
		return $rs[0]["products_id"];
	} else {
		return false;
	}
}
function updartikel($data,$id) {
global $header,$defLang,$tax;
	$sql="update products set products_status=1,products_price=%01.2f,products_weight=%01.2f,products_tax_class_id=%d,";
	$sql.="products_last_modified=now(),products_quantity=%d where products_id=%d";
	$sql=sprintf($sql,$data["preis"],$data["weight"],$tax[sprintf("%1.4f",$data["rate"])],$data["onhand"],$id);
	$rc=query("shop",$sql,"updartikel");
	if ($rc === -99) { echo "Fehler <br>"; return false; };
	$sql="update products_description set products_name='%s',products_description='%s' where products_id=%d and language_id=$defLang";
	$sql=sprintf($sql,$data["description"],$data["notes"],$id);
	$rc=query("shop",$sql,"updartikel");
	if ($rc === -99) { echo "Fehler <br>"; return false; };
	$sql="update products_to_categories set categories_id=".$data["categories_id"]." where products_id=$id";
	$rc=query("shop",$sql,"updartikel");
	if ($rc === -99) { echo "Fehler <br>"; return false; };
	echo "+++<br>";
	return true;
}
function chkartikel($data) {
global $header,$shop2erp,$erptax,$defLang;
	if ($data["partnumber"]=="") { echo "Artikelnummer fehlt!<br>"; return;};
	$sql="select * from products P left join products_description D on P.products_id=D.products_id left join products_to_categories C on ";
	$sql.="P.products_id=C.products_id where  products_model like '".$data["partnumber"]."' and language_id=$defLang";
	echo "(".$data["partnumber"]."->".$rs[0]["products_id"].":".$data["description"].")";
    if ($data["image"]) {
            $data["picname"]=(strrpos($data["image"],"/")>0)?substr($data["image"],strrpos($data["image"],"/")+1):$data["image"];
    } else if ($nopic) {
            $data["picname"]=(strrpos($nopic,"/")>0)?substr($nopic,strrpos($nopic,"/")+1):$nopic;
            $data["image"]=$nopic;
    }
	$data["onhand"]=floor($data["onhand"]);
	$data["rate"]=$erptax[$data["bugru"]]["rate"];
	$data["preis"]=($data["sellprice"]>0)?$data["sellprice"]:$data["stdprice"];
	$rs=getAll("shop",$sql,"chkartikel");
	if ($rs) {
		$rc=updartikel($data,$rs[0]["products_id"]);
		if ($rs[0]["products_image"]<>$data["image"] and $data["picname"] and $rc) uploadImage($data["image"],$rs[0]["products_id"]);
	} else {
		$id=insartikel($data);
		if ($data["image"] and $id) uploadImage($data["image"],$id);
	}
}
if ($SHOPlang>0) {
	$defLang=$SHOPlang;
} else {
	$sql="select * from languages L left join configuration C on L.code=C.configuration_value where  configuration_key = 'DEFAULT_LANGUAGE'";
	$rs=getAll("shop",$sql,"SHOPlang");
	if ($rs) {
		$defLang=$rs[0]["languages_id"];
	} else {
		$defLang=1;
	}
}

$sql="select * from tax_rates";
$rs=getAll("shop",$sql,"tax_rates");
if ($rs) {
	foreach ($rs as $zeile) {
		$tax[$zeile["tax_rate"]]=$zeile["tax_class_id"];
	}
} else {
	$tax[0]="";
}


/*******************************************
* Steuern
*******************************************/
//Steuertabelle ERP
$sql ="select  BG.id as bugru,T.rate,TK.startdate from buchungsgruppen BG left join chart C ";
$sql.="on BG.income_accno_id_0=C.id left join taxkeys TK on TK.chart_id=C.id left join tax T ";
$sql.="on T.id=TK.tax_id where TK.startdate <= now()";
$rs=getAll("erp",$sql,"Tax ERP");
$erptax=array();
foreach ($rs as $row) {
        if ($erptax[$row["bugru"]]["startdate"]<$row["startdate"]) {
                $erptax[$row["bugru"]]["startdate"]=$row["startdate"];
                $erptax[$row["bugru"]]["rate"]=$row["rate"]*100;
        }
}


$artikel=shopartikel();
echo "Artikelexport ERP -&gt; osCommerce :".count($artikel)." Artikel markiert.<br>";
if ($artikel) {
	foreach ($artikel as $data) {
		$data["categories_id"]=getCategory($data["partsgroup"]);
		chkartikel($data);
	}
	require ("diff.php");
}

?>
