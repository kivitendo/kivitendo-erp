<?php
/***************************************************************
*Author: Holger Lindemann
*Copyright: (c) 2004 Lx-System
*License: non free
*eMail: info@lx-system.de
*Version: 2.1
*Shop: xt:Commerce 3.04
*ERP: Lx-Office ERP 2.4.0
***************************************************************/
require_once "shoplib.php";


/*******************************************
* createCategoryLang($id,$lang,$name)
* Kategorie für eine Sprache anlegen. Ist immer
* in der gleichen Sprache, da ERP nur eine hat.
*******************************************/
function createCategoryLang($id,$lang,$name) {
	$sql="insert into categories_description (categories_id,language_id,categories_name,categories_meta_title) ";
	$sql.="values ($id,$lang,'$name','$name')";
	$rc=query("shop",$sql,"createCategoryLang");
	return $rc;
}

/*******************************************
* createCategory($name,$maingroup,$Lang,$Lanuages)
* Eine Kategorie in der default-Sprache anlegen
*******************************************/
function createCategory($name,$maingroup,$Lang,$Languages) {
	echo "Kategorie: $name<br>";
	//Kategorie nicht vorhanden, anlegen
	$newID=uniqid(rand());
	$sql="insert into categories (categories_image,parent_id,date_added) values ('$newID',$maingroup,now())";
	$rc=query("shop",$sql,"createCategory_1");
	if ($rc === -99) return false;
	$sql="select * from categories where categories_image = '$newID'";
	$rs=getAll("shop",$sql,"createCategory_2");
	$id=$rs[0]["categories_id"];
	$sql="update categories set categories_image = null where categories_id=$id";
	$rc=query("shop",$sql,"createCategory_3");
	if ($rc === -99) return false;
	createCategoryLang($id,$Lang,$name);
	if ($Languages) foreach ($Languages as $erp=>$shop) {
		if ($Lang<>$shop) {
			createCategoryLang($id,$shop,$name);
		}
	}
	return ($rc !== -99)?$id:false;
}

/*******************************************
* getCategory($name,$Lang,$Languages)
* gibt es die Kategorie schon?
*******************************************/
function getCategory($name,$Lang,$Languages) {
	if (empty($name)) $name="Default";
	$tmp=split("!",$name);
	$maingroup=0;
	$found=true;
	$i=0;
	do {
		$sql="select D.*,C.parent_id from categories C left join categories_description D on C.categories_id=D.categories_id ";
		$sql.="where (categories_name = '".$tmp[$i]."' or categories_meta_title ='".$tmp[$i]."') and ";
		$sql.="C.parent_id=$maingroup and language_id=$Lang";
		$rs=getAll("shop",$sql,"getCategory");
		if ($rs) {
			$maingroup=$rs[0]["categories_id"];
			$i++;
		} else {
			$found=false;
		}
	} while ($rs and $found and $i<count($tmp));
	for (;$i<count($tmp); $i++) {
		$maingroup=createCategory($tmp[$i],$maingroup,$Lang,$Languages);
	}
	return $maingroup;
}

/*******************************************
* getCategoryLang($name,$Lang,$defLang,$Languages
* ohne Funktion
*******************************************/
function getCategoryLang($name,$Lang,$defLang,$Languages) {
	if (empty($name)) $name="Default";
	$tmp=split("!",$name);
	$tmpname=$tmp[count($tmp)-1];
	$i=0;
	do {
		$sql="select * from categories_description ";
		$sql.="where (categories_name = '".$tmp[$i]."' or categories_meta_title ='".$tmp[$i]."') and language_id=$Lang";
		$rs=getAll("shop",$sql,"getCategoryLang");
		if ($rs) {
			$i++;
		} else {
			$found=false;
		}
	} while ($rs and $found and $i<count($tmp));
	for (;$i<count($tmp); $i++) {
		$id=getCategory($tmp[$i],$Lang,false);
		createCategoryLang($id,$shop,$tmpname);
	}
	return $id;
}

/*******************************************
* bilder($width,$height,$dest
* Bild in der gewünschten Größe erzeugen
*******************************************/
function bilder($width,$height,$dest) {
	//Wenn auf dem Server die php_imagick nicht installiert werden kann:
        //$rc=@exec("/usr/bin/convert -resize ".$width."x".$height." tmp/tmp.file_org tmp/tmp.file_$dest",$aus,$rc2);
        //if ($rc2>0) { echo "[Bildwandeln: $image.$dest]<br>";  return false; };

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

/*******************************************
* uploadImage($image,$id)
* Ein Bild zum Shop übertragen
*******************************************/
function uploadImage($image,$id) {
global $ERPftphost,$ERPftpuser,$ERPftppwd,$ERPimgdir,$SHOPftphost,$SHOPftpuser,$SHOPftppwd,
		$SHOPimgdir,$picsize;
	$picdest = array("thumb"=>"thumbnail_images","info"=>"info_images","popup"=>"popup_images","org"=>"original_images");
	$ok=true;
	// Bilder holen
	if ($ERPftphost=="localhost")
	{
		$aus=""; $rc2=0;
		if (is_file($ERPimgdir."/".$image)) {
			$rc3=@exec("cp $ERPimgdir/$image ./tmp/tmp.file_org",$aus,$rc2);
			if ($rc2>0) { $ok=false; echo "[Downloadfehler: $image]<br>"; };
		} else {
                        echo "[Downloadfehler: $ERPimgdir/$image nicht gefunden]";
                        return false;
                }
	} else {
		$conn_id = ftp_connect($ERPftphost);
		if ($conn_id==false) {
			echo "[Kein FTP-Verbindung ERP]";
			return false;
		}
		ftp_login($conn_id,$ERPftpuser,$ERPftppwd);
		$src=$ERPimgdir."/".$image;
		$upload=ftp_get($conn_id,"tmp/tmp.file_org","$src",FTP_BINARY);
		if (!$upload) { $ok=false; echo "[Ftp Downloadfehler: $image]<br>";};
		ftp_quit($conn_id);
	}
	if ($ok) {
		//Bildergrößen erzeugen
		if (!bilder($picsize["PRODUCT_IMAGE_THUMBNAIL_WIDTH"],$picsize["PRODUCT_IMAGE_THUMBNAIL_HEIGHT"],"thumb")) return false;
		if (!bilder($picsize["PRODUCT_IMAGE_INFO_WIDTH"],$picsize["PRODUCT_IMAGE_INFO_HEIGHT"],"info")) return false;
		if (!bilder($picsize["PRODUCT_IMAGE_POPUP_WIDTH"],$picsize["PRODUCT_IMAGE_POPUP_HEIGHT"],"popup")) return false;
		$name=(strrpos($image,"/")>0)?substr($image,strrpos($image,"/")+1):$image;
		//zum Shop übertragen
		if ($SHOPftphost=="localhost") {
			foreach ($picdest as $key => $val) {
				if (is_dir($SHOPimgdir."/".$val."/")) {
					$src=$SHOPimgdir."/".$val."/".$name;
					$rc2=0; $aus="";
					$rc3=@exec("cp ./tmp/tmp.file_$key $src",$aus,$rc2);
					print "!$rc2,$rc3!";
					if ($rc2>0) { $ok=false; echo "[Uploadfehler: $src]"; };
				} else {
					echo "[Uploadfehler: $val nicht gefunden]";
					return false;
				}
			}
		} else {
			$conn_id = ftp_connect($SHOPftphost);
			if ($conn_id==false) {
				echo "[Kein FTP-Verbindung Shop]";
				return false;
			}
			ftp_login($conn_id,$SHOPftpuser,$SHOPftppwd);
			foreach ($picdest as $key => $val) {
				$src=$SHOPimgdir."/".$val."/".$name;
				$upload=ftp_put($conn_id,"$src","tmp/tmp.file_".$key,FTP_BINARY);
				if (!$upload) { $ok=false; echo $key."[FTP Uploadfehler $src]<br>";};
			}
			ftp_quit($conn_id);
		}
		if ($ok) {
			$sql="update products set products_image='%s',products_last_modified=now() where products_id=%d";
			$sql=sprintf($sql,$name,$id);
			$rc=query("shop",$sql,"uploadImage");
			if ($rc === -99) return false;
			echo "i";
		}
	}
	return true;
}

/*******************************************
* insartikel($data,$defLang
* Einen neuen Artikel im Shop anlegen
*******************************************/
function insartikel($data,$defLang) {
	$newID=uniqid(rand());
	$sql="insert into products (products_model,products_image) values ('".$data["partnumber"]."','$newID')";
	$rc=query("shop",$sql,"insartikel_1");
	if ($rc === -99) return false;
	$sql="select * from products where products_image='$newID'";
	$rs=getAll("shop",$sql,"insartikel_2");
	$sql="update products set products_image=null where products_id=".$rs[0]["products_id"];
	$rc=query("shop",$sql,"insartikel_3");
	$sql="insert into products_to_categories (products_id,categories_id) values ";
	$sql.="(".$rs[0]["products_id"].",".$data["categories_id"].")";
	$rc=query("shop",$sql,"insartikel_4");
	if ($rc === -99) return false;
	echo " + ";
	updartikel($data,$rs[0]["products_id"],$defLang);
	return $rs[0]["products_id"];
}

/*******************************************
*
*
*******************************************/
function updartikel($data,$id,$defLang) {
global $tax,$KDGrp;
	echo $id." ";
	$sql="update products set products_status=1,products_price=%01.2f,products_weight=%01.2f,";
	$sql.="products_tax_class_id=%d,products_last_modified=now(),products_quantity=%d where products_id=%d";
	$price=($data["sellprice"]>0)?$data["sellprice"]:$data["stdprice"];
	$sql=sprintf($sql,$price,$data["weight"],$tax[sprintf("%1.4f",$data["rate"])],$data["onhand"],$id);
	$rc=query("shop",$sql,"updartikel_1");
	$sql="update products_to_categories set categories_id=".$data["categories_id"]." where products_id=$id";
	$rc=query("shop",$sql,"updartikel_2");
	echo "~";
	if ($KDGrp>0) personal_offer ($data["altprice"],$id);
	$sql="select * from products_description where products_id=$id and language_id=$defLang";
	$rs=getAll("shop",$sql,"updartikel_3");
	if ($rs) {  // bestehende Sprachen abgleichen
		$sql="update products_description set products_name='%s',products_description='%s' where ";
		$sql.="products_id=%d and language_id=$defLang";
		$sql=sprintf($sql,$data["description"],$data["notes"],$id);
		echo "l";
	} else {  // neue Sprache einfügen
		$sql="insert into products_description (products_id,products_name,products_description,language_id) ";
		$sql.="values (%d,'%s','%s',%d)";
		$sql=sprintf($sql,$id,$data["description"],$data["notes"],$defLang);
		echo "L";
	}
	$rc=query("shop",$sql,"updartikel_4");
	if ($rc === -99) return false;
}

/*******************************************
* personal_offer ($personal_offer,$products_id)
* Spezialangebote anlegen
*******************************************/
function personal_offer ($personal_offer,$products_id) {
global $KDGrp;
	$sql="select * from personal_offers_by_customers_status_$KDGrp where ";
	$sql.="products_id=$products_id order by quantity limit 1";
	$rs=getAll("shop",$sql,"personal_offer_1");
	if ($rs) {
		if ($personal_offer) {
			$sql="update personal_offers_by_customers_status_$KDGrp ";
			$sql.="set personal_offer=$personal_offer where price_id = ".$rs[0]["price_id"];
			echo "p";
		} else {
			$sql="delete from personal_offers_by_customers_status_$KDGrp where price_id = ".$rs[0]["price_id"];
			echo "q";
		}
		$rc=query("shop",$sql,"personal_offer_2");
	} else {
		if ($personal_offer) {
			$sql="insert into personal_offers_by_customers_status_$KDGrp ";
			$sql.="(price_id,products_id,quantity,personal_offer) ";
			$sql.="values (0,$products_id,1,$personal_offer)";
			$rc=query("shop",$sql,"personal_offer_3");
			if ($rc === -99) return false;
			echo "P";
		}
	};
}

/*******************************************
* chkartikellang($data,$Lang)
* Gibt es den Artikel und hat er sich geändert
*******************************************/
function chkartikellang($data,$Lang) {
global $tax,$KDGrp;
	if ($data["partnumber"]=="") { echo "Artikelnummer fehlt!<br>"; return;};
	echo $data["partnumber"]." ".$data["translation"]." -> ";
	$sql ="select P.products_id from products P left join products_description PD on P.products_id=PD.products_id where ";
	$sql.="products_model like '".$data["partnumber"]."' and language_id=$Lang";
	$rs=getAll("shop",$sql,"chkartikellang");
	if (count($rs)>0) {
		$sql="update products_description set products_name='".$data["translation"]."', products_description='".$data["longdescription"]."' ";
		$sql.="where products_id='".$rs[0]["products_id"]."' and language_id=$Lang";
		$rc=query("shop",$sql,"chkartikellang_u");
	} else {
		$sql ="select products_id from products where products_model like '".$data["partnumber"]."'";
		$rs=getAll("shop",$sql,"chkartikellang");
		$sql="insert into products_description (products_id,language_id,products_name,products_description) values (";
		$sql.=$rs[0]["products_id"].",$Lang,'".$data["translation"]."','".$data["longdescription"]."')";
		$rc=query("shop",$sql,"chkartikellang_i");
		if ($rc === -99) return false;
	}
	echo $rs[0]["products_id"]."<br>\n";
	return true;
}

/*******************************************
* chkartikel($data,$defLang)
* Hat sich der Artikel verändert
*******************************************/
function chkartikel($data,$defLang) {
global $tax,$erptax,$shop2erp,$KDGrp,$GeoZone,$nopic;
	if ($data["partnumber"]=="") { echo "Artikelnummer fehlt!<br>"; return;};
	if ($data["image"]) {
		$data["picname"]=(strrpos($data["image"],"/")>0)?substr($data["image"],strrpos($data["image"],"/")+1):$data["image"];
	} else if ($nopic) {
		$data["picname"]=(strrpos($nopic,"/")>0)?substr($nopic,strrpos($nopic,"/")+1):$nopic;
		$data["image"]=$nopic;
	}
	$data["onhand"]=floor($data["onhand"]);
	echo $data["partnumber"]." ".$data["description"]." -> ";
	$sql ="select * from products where products_model like '".$data["partnumber"]."'";
	$rs=getAll("shop",$sql,"chkartikel");
	$data["rate"]=$erptax[$data["bugru"]]["rate"];
	if ($rs) {
		updartikel($data,$rs[0]["products_id"],$defLang);
		if ($rs[0]["products_image"]<>$data["picname"] and $data["picname"]) uploadImage($data["image"],$rs[0]["products_id"]);
	} else {
		$id=insartikel($data,$defLang);
		if ($data["image"]) uploadImage($data["image"],$id);
	}
	echo "<br>\n";
}

/*******************************************
* Grafiken
*******************************************/
//Defaultwerte
$picsize= array("PRODUCT_IMAGE_THUMBNAIL_WIDTH" => 120,"PRODUCT_IMAGE_THUMBNAIL_HEIGHT" => 80,
		"PRODUCT_IMAGE_INFO_WIDTH" => 200,"PRODUCT_IMAGE_INFO_HEIGHT" => 160,
		"PRODUCT_IMAGE_POPUP_WIDTH" => 300,"PRODUCT_IMAGE_POPUP_HEIGHT" => 240,"IMAGE_QUALITY" => 80);
//persönliche Werte
foreach ($picsize as $key => $val) {
	$sql=sprintf("select configuration_value from configuration where configuration_key='%s'",$key);
	$rs=getAll("shop",$sql,"Picsize");
	if ($rs[0]["configuration_value"]>0) $picsize[$key]=$rs[0]["configuration_value"];
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

//Steuerzone Shop
$sql="select GZ.geo_zone_id from configuration C, zones_to_geo_zones GZ ";
$sql.="where C.configuration_key='STORE_COUNTRY' and GZ.zone_country_id=C.configuration_value";
$rs=getAll("shop",$sql,"GZ");
if ($rs) {
	$GeoZone=$rs[0]["geo_zone_id"];
} else {
	echo "Steuerzone nicht gefunden";
	exit;
}

//Steuersätze
$sql="select * from tax_rates where tax_zone_id=$GeoZone";
$rs=getAll("shop",$sql,"tax_rates");
if ($rs) {
	foreach ($rs as $zeile) {
		$tax[$zeile["tax_rate"]]=$zeile["tax_class_id"];
	}
} else {
	$tax[0]="";
}

/*******************************************
* Sprache
*******************************************/
if (empty($Language) || !$Language) {
	echo "Keine Sprachzuordnung definiert!";
	exit;
}

//Default Shopsprache ermitteln
$sql="select * from languages L left join configuration C on L.code=C.configuration_value ";
$sql.="where  configuration_key = 'DEFAULT_LANGUAGE'";
$rs=getAll("shop",$sql,"DefaultLang");

if ($rs) {
        $ShopdefaultLang=$rs[0]["languages_id"];
	if ($SHOPdefaultlang<>$ShopdefaultLang) {
                echo "Defaultsprache im Shop wurde geändert ($SHOPdefaultlang<>$ShopdefaultLang)";
		exit;
	}
} else  {
	echo "Keine Defaultsprache im Shop eingestellt.";
	exit;
}

$Languages=array();
foreach ($Language as $Langrow) {
	if ($Langrow["SHOP"]>0 and $Langrow["ERP"]>0) $Languages[$Langrow["ERP"]]=$Langrow["SHOP"];
}

/*******************************************
* Import starten
*******************************************/
$artikel=shopartikel(); //array_keys($Languages));

echo "Artikelexport ERP -&gt; xt:Commerce (Standardsprache $ShopdefaultLang): ".count($artikel)." Artikel markiert.<br>";

if ($artikel) { //Mit jedem Artikel in der Defaultsprache:
	foreach ($artikel as $data) {
		//Kategorie abfragen/anlegen
		$data["categories_id"]=getCategory($data["partsgroup"],$ShopdefaultLang,$Languages);
		chkartikel($data,$ShopdefaultLang,false);
	}

	foreach ($Languages as $erplang=>$shoplang) { //Mit jeder weiteren Sprache
		$artikel=shopartikellang($erplang,$SpracheAlle);
		echo "Shopsprache: $shoplang<br>";
		if ($artikel) {
			foreach ($artikel as $data) {
				//Kategorie abfragen
				$data["categories_id"]=getCategory($data["partsgroup"],$shoplang,$Languages);
				if ($SpracheAlle) {
					if ($data["translation"]=="") $data["translation"]=$data["description"];
					if ($data["longdescription"]=="") $data["longdescription"]=$data["notes"];
				}
				chkartikellang($data,$shoplang);
			}
		}
	}
} else {
	if ($debug) {
		$log=fopen("tmp/shop.log","a");
		fputs($log,$nun.": Fehler\n");
	} 
}
require ("diff.php");

?>
