<?php
/*
Funktionen für den Zugriff auf den xtc 3.04 newxtc 1.05
*/


class xtc {

    var $db = false;
    var $error = false;
    var $divStd = false;
    var $divVerm = false;
    var $minder = false;
    var $paypal = false;
    var $nachn = false;
    var $shopcode = 'ISO-8859-1';
    var $erpcode = 'UTF-8';
    var $VariantNr = 1;
    var $EU = array('AT','BE','BG','CZ','DK','EE','ES','FI','FR','GB','GR','HR','HU','IE','IT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK');
    var $Kategorien = False;
    var $dezimal = 2;
    var $tax_zone = 5;
    var $language = 2;
    var $geozone = 5;

    var $tableerp  = array("partnumber"=>"products_model","description"=>"products_name","notes"=>"products_description","ean"=>"products_ean",
                           "unit"=>"products_vpe","weight"=>"products_weight","sellprice"=>"products_price","partsgroup"=>"products_partsgroup",
                           "tax"=>"products_tax","image"=>"products_image","onhand"=>"products_quantity");
    var $custshop   = array("kontakt"=>"contact","ort"=>"city","plz"=>"zipcode","land"=>"country","tel"=>"phone",
                            "fax"=>"fax","email"=>"email","beschreibung"=>"notes","strasse"=>"street","firma"=>"name",
                            "kunden_nr"=>"customer_id","anrede"=>"greeting","k_id"=>"shopid",
                            "bankname"=>"bank","blz"=>"bank_code","kontonummer"=>"account_number",
                            "iban"=>"iban","bic"=>"bic","attributwert1"=>"ustid");
    var $ordershop  = array("datum"=>"transdate","rechnungsbetrag"=>"amount","rechnungs_nr"=>"",
                            "waehrung"=>"currency","beschreibung"=>"notes",
                            "mwst"=>"mwst","versandart"=>"shipvia");
    var $orderparts = array("products_name"=>"description","products_description"=>"longdescription","products_price"=>"sellprice",
                            "products_quantity"=>"qty","products_model"=>"partnumber",
                            "partsgroup"=>"partsgroup","products_weight"=>"weight","products_ean"=>"ean",
                            "products_tax"=>"taxrate","products_image"=>"image","products_vpe_name"=>"unit");

    function xtc($db,$error,$dbname,$divStd,$divVerm,$minder,$nachn,$versandS,$versandV,$paypal,$mwstLX,$mwstS,$variantnr,$unit,
                 $pic=false,$nopic=false,$nopicerr=false,$nofiles=false,
                 $erpcode='UTF-8',$shopcode='ISO-8859-1') {
        $this->db       = $db;
        $this->error    = $error;
        $this->divStd   = $divStd  ;
        $this->divVerm  = $divVerm ;
        $this->minder   = $minder  ;
        $this->nachn    = $nachn   ;
        $this->versandS = $versandS ;
        $this->versandV = $versandV ;
        $this->paypal   = $paypal  ;
        $this->erpcode  = $erpcode;
        $this->mwstLX   = $mwstLX;
        $this->mwstS    = $mwstS;
        $this->unit     = $unit;
        $this->VariantNr = $variantnr;
        $this->language  = $this->defaultLang();        
        $this->geozone   = $this->getDefaultGZ();
        $this->pic       = $pic;
        $this->nopic     = ( $nopic != '' )?$nopic:false;
        $this->nopicerr  = ( $nopicerr != '' )?true:false;
        $this->nofiles     = $nofiles;
        if ($shopcode == 'AUTO') {
            $sql = "SELECT TABLE_COLLATION FROM information_schema.TABLES WHERE table_schema = '$dbname' AND table_name = 'customers'";
            $rs = $this->db->getOne($sql);
            if ($rs) {
                preg_match('/([^_]+)/',$rs['table_collation'],$hits);
                if (count($hits)>0) {
                    $this->shopcode = $hits[1];
                } else {
                    $this->shopcode =  'ISO-8859-1';
                }
            }
        } else {
            $this->shopcode = $shopcode;
        }
    }
    function getDefaultGZ() {
        $sql  = "SELECT geo_zone_id FROM  zones_to_geo_zones Z ";
        $sql .= "LEFT JOIN countries CO ON Z.zone_country_id=CO.countries_id ";
        $sql .= "LEFT JOIN configuration CF ON CO.countries_iso_code_2=CF.configuration_value ";
        $sql .= "WHERE configuration_key = 'DEFAULT_LANGUAGE'";
        $rs = $this->db->getOne($sql);
        return $rs['geo_zone_id'];
    }
    function defaultLang() {
        $sql  = "SELECT languages_id FROM languages L LEFT JOIN configuration C ON L.code = C.configuration_value ";
        $sql .= "WHERE C.configuration_key = 'DEFAULT_LANGUAGE'";
        $rs = $this->db->getOne($sql);
        return $rs['languages_id'];
    }
    function _toERP($txt) {
        return mb_convert_encoding($txt,$this->erpcode,$this->shopcode);
    }
    function _toShop($txt) {
        return mb_convert_encoding($txt,$this->shopcode,$this->erpcode);
    }
    function translateTable($data,$table) {
        $newdata = array();
        foreach ($data as $key=>$val) {
             if ($this->{$table}[$key]) 
                 $newdata[$this->{$table}[$key]] = $val;
        }
        return $newdata;
    }
    function getCategoryID($name) {
        if (empty($name)) {
              $name = "Default";
        } else {
              $name = $this->_toShop($name);
        }
        //Kategorien werden durch die ERP mit "!" getrennt
        preg_match_all("/([^!]+)!?/",$name,$kat);
        if (count($kat)>0) {
            $kat = $kat[1];
        } else {
            return false;
        };
        $parent = 0;
        $sql="select D.*,C.parent_id from categories C left join categories_description D on C.categories_id=D.categories_id ";
        $sql.="where categories_name = '%s' and ";
        $sql.="C.parent_id=%d and language_id=".$this->language;
        if (count($kat)>0) foreach ($kat as $wg) {
            $sql_ = sprintf($sql,$wg,$parent);
            $rs=$this->db->getOne($sql_);
            if ($rs["categories_id"]) {                   // gefunden
                $parent=$rs["categories_id"];
            } else {                    // nicht gefunden, anlegen
                $parent=$this->createCategory($wg,$parent);
            }
        }
        return $parent;
    }
    function createCategory($name,$parent) {
        echo "Kategorie: $name<br>";
        //Kategorie nicht vorhanden, anlegen
        $newID = uniqid(rand());
        $sql = "INSERT INTO categories (categories_image,parent_id,date_added) VALUES  ('$newID',$parent,now())";
        $rc = $this->db->query($sql);
        if ( !$rc ) return false;
        $sql = "SELECT * FROM categories WHERE categories_image = '$newID'";
        $rs = $this->db->getOne($sql);
        $id = $rs["categories_id"];
        $sql = "UPDATE categories SET categories_image = null WHERE categories_id=$id";
        $rc = $this->db->query($sql);
        if ( !$rc ) return false;
        $rc = $this->createCategoryLang($id,$name);
        return $id;
    }
    /*******************************************
    * createCategoryLang($id,$lang,$name)
    * Kategorie für eine Sprache anlegen. Ist immer
    * in der gleichen Sprache, da ERP nur eine hat.
    *******************************************/
    function createCategoryLang($id,$name) {
        $sql  = "INSERT INTO categories_description (categories_id,language_id,categories_name,categories_meta_title) ";
        $sql .= "VALUES ($id,".$this->language.",'$name','$name')";
        $rc = $this->db->query($sql);
        return $rc;
    }
    function getTax($tax) {
        $sql = "SELECT * FROM tax_rates WHERE tax_rate = $tax and tax_zone_id =".$this->geozone;
        $rs = $this->db->getOne($sql);
        return $rs['tax_class_id'];
    }
    function getVPE($vpe) {
        $sql  = "SELECT products_vpe_id FROM products_vpe WHERE products_vpe_name = '$vpe' AND language_id = ".$this->language;
        $rs = $this->db->getOne($sql);
        return $rs['products_vpe_id'];
    }
    function saveArtikel($data,$lang) {
         $values = $this->translateTable($data,"tableerp"); //$this->tableerp);
         if ($this->mwstLX) { //ERP-Bruttopreis
              $values['products_price'] = round($values['products_price'] / (1 + $values["products_tax"]),2);
         }
         $values["products_name"] = $this->_toShop($values["products_name"]);
         $values["products_description"] = $this->_toShop($values["products_description"]);
         $values["products_tax_class_id"] = $this->getTax($values["products_tax"]*100);
         $values["categories_id"] = $this->getCategoryID($values["products_partsgroup"]);
         $values["products_vpe"] = $this->getVPE($values["products_vpe"]);
         $values["products_id"] = $this->checkArtikelOK($values["products_model"]);  
         if ($values["products_id"]>0)  {
             $rc = $this->updateArtikel($values);
         } else {
             $rc = $this->insertArtikel($values);
         };
         return $rc;
    }
    function checkArtikelOK($nr) {
        $sql = "SELECT * FROM products WHERE products_model = '".$nr."'";
        $rs = $this->db->getOne($sql);
        return $rs["products_id"];
    }
    function insertArtikel($data) {
        $newID = uniqid(rand());
        $this->db->Begin();
    	$sql = "INSERT INTO products (products_model,products_image,products_status) VALUES ('".$data["products_model"]."','$newID',1)";
	    $rc = $this->db->query($sql);
    	$sql = "SELECT * FROM products WHERE products_image='$newID'";
	    $rs = $this->db->getOne($sql);
        $sql = "INSERT INTO products_description (products_id,products_name,language_id) VALUES (".$rs['products_id'].",'".$data['products_name']."',".$this->language.")";
	    $rc = $this->db->query($sql);
	    if ($rs['products_image'] == $newID) {
            $data["products_id"] = $rs["products_id"];
	        $statement = "INSERT INTO products_to_categories (products_id,categories_id) VALUES (?,?)";
            $values = array($rs["products_id"],$data["categories_id"]);
	        $rc = $this->db->insert($statement,$values);
            if (!$rc) {
                 echo $data['products_model'].' konnte nicht zur Gruppe '.$data['categories_id'].' zugef&uuml;gt werden.';
                 $this->error->write('xtc',$data['products_model'].' konnte nicht zur Gruppe '.$data['categories_id'].' zugefügt werden.');
                 $this->db->Rollback();
                 return false;
            }
            $this->db->Commit();
	    echo " insert ";
	    $rc = $this->updateArtikel($data,true);
	} else { return false; }
        return $rc;
    }
    function updateArtikel($values,$insert=false) {
        if ($this->mwstLX) $values['products_price'] = round($values['products_price'] / (100+$values['products_tax'])*100,2);
        $sql  = "UPDATE products SET products_price = :products_price, products_weight = :products_weight, ";
        if ( !$this->nofiles || $insert) {
             //vorhandene Bilder übertragen
             $sql .= "products_image = :products_image,  ";
             if ( $values['products_image'] != '' ) {
                 preg_match("/(.+)\.(jpg|png|jpeg|gif)/i",$values['products_image'],$tmp);
                 $sql .= "products_image = :products_image,  ";
                 if ( count($tmp) == 3 ) {
                     if ( $this->pic &&  $this->pic->copyImage($values['products_id'],$values['products_image'],$tmp[2]) ) {
                         $values['products_image'] = $values['products_id']."_0.".$tmp[2];
                     } else if ( $this->nopic ){
                         $values['products_image'] = $this->nopic;
                     }
                 } 
             } else if ( $this->nopic && !$this->nopicerr ){
                 $values['products_image'] = $this->nopic;
             }
        }
        $sql .= "products_tax_class_id = :products_tax_class_id, products_vpe = :products_vpe, products_ean = :products_ean ";
        //Kein Lagerbestand übergeben, also nichts ändern
        if ($values['products_quantity'] != '') $sql .= ",products_quantity = :products_quantity ";
        $sql .= "WHERE products_id = :products_id ";
        $rc = $this->db->update($sql,$values);
        $sql  = "UPDATE products_description SET products_name = :products_name, products_description = :products_description ";
        #products_short_description products_keywords <== aus CVars
        $sql .= "WHERE products_id = :products_id AND language_id = ".$this->language;
        $rc = $this->db->update($sql,$values);
        if ($rc) { 
            return $values["products_id"];
        } else {
            return false;
        }
    }
    function getVersand($class,$orderid,$country) {
        $tmp = explode("_",$class);
        if ( $tmp[1] == "" ) $tmp[1] = "dp";
        $sql  = "SELECT geo_zone_id FROM zones_to_geo_zones WHERE zone_country_id = (";
        $sql .= "SELECT countries_id FROM countries WHERE countries_name = '$country')";
        $rs = $this->db->getOne($sql);
        $sql  = "SELECT tax_rate FROM tax_rates WHERE tax_zone_id = ".$rs['geo_zone_id']." AND tax_class_id = (";
        $sql .= "SELECT configuration_value FROM  configuration WHERE configuration_key = 'MODULE_SHIPPING_".strtoupper($tmp[1])."_TAX_CLASS') ";
        $rs = $this->db->getOne($sql);
        $preis = $this->getTotal($orderid,'ot_shipping');
        if ( $preis > 0 ) {
            if ($this->mwstS) {
                $preis = round($preis/(100+$rs['tax_rate'])*100,2);
            } 
            if ($rs['tax_rate'] ==  $this->versandV['TAX']) {
                     $artikel  = array("partnumber"=>$this->versandV['NR'],"description"=>$this->versandV['TXT'],
                                       "qty"=>1,"unit"=>$this->versandV['Unit'],"sellprice"=>$preis);
            } else {
                     $artikel  = array("partnumber"=>$this->versandS['NR'],"description"=>$this->versandS['TXT'],"taxrate"=>$this->versandS['TAX'],
                                       "qty"=>1,"unit"=>$this->versandS['Unit'],"sellprice"=>$preis);
            }
            return $artikel;
        }
        return false;
    }
    function getKosten($kosten,$orderid,$country) {
        $sql  = "SELECT geo_zone_id FROM zones_to_geo_zones WHERE zone_country_id = (";
        $sql .= "SELECT countries_id FROM countries WHERE countries_name = '$country')";
        $rs = $this->db->getOne($sql);
        $sql  = "SELECT tax_rate FROM tax_rates WHERE tax_zone_id = ".$rs['geo_zone_id']." AND tax_class_id = (";
        $sql .= "SELECT configuration_value FROM  configuration WHERE configuration_key = 'MODULE_SHIPPING_".strtoupper($kosten)."_TAX_CLASS') ";
        $rs = $this->db->getOne($sql);
        $preis = $this->getTotal($orderid,'ot_'.$kosten);
        if ( $preis > 0 ) {
            //Shop muß immer Nettopreise liefern.
            if ( $this->mwstS ) {
                $preis = round($preis / (100+$rs['tax_rate'])*100,2);
            } 
                 if ( $kosten == 'cod_fee' )     { $erp = $this->nachn; }
            else if ( $kosten == 'loworderfee' ) { $erp = $this->minder; }
            else if ( $kosten == 'paypal_fee' )      { $erp = $this->paypal; }
            $artikel  = array("partnumber"=>$erp['NR'],"description"=>$erp['TXT'],
                               "qty"=>1,"unit"=>$erp['Unit'],"sellprice"=>$preis);
            return $artikel;
        }
        return false;
    }
    function getTotal($orderid,$type) {
        $sql = "SELECT value FROM orders_total WHERE orders_id = $orderid AND class = '$type'";
        $rs = $this->db->getOne($sql);
        return $rs['value'];
    }
    function getBestellung($employee_id) {
        $sql = "SELECT * FROM orders WHERE orders_status=1 order by orders_id limit 1";
        $rs=$this->db->getAll($sql);
        if (!$rs) return array(); 
        $data = false; 
        foreach ($rs as $row) {
             $artikel = $this->getBestellArtikel($row["orders_id"]);
             $versand = $this->getVersand($row["shipping_class"],$row['orders_id'],$row['delivery_country']);
             if ($versand) $artikel[] = $versand;
             $nachn = $this->getKosten('cod_fee',$row['orders_id'],$row['delivery_country']);
             if ($nachn) $artikel[] = $nachn;
             $minder = $this->getKosten('loworderfee',$row['orders_id'],$row['delivery_country']);
             if ($minder) $artikel[] = $minder;
             $paypal = $this->getKosten('paypal',$row['orders_id'],$row['delivery_country']);
             if ($paypal) $artikel[] = $paypal;
             if ($row["delivery_country_iso_code_2"] == "DE") {
                 $rowdata['taxzone_id'] = 0;
             } else if (in_array($this->EU,$row["delivery_country_iso_code_2"])) {
                 if (preg_match('/^[^0-9]{2,3}[ 0-9]+$/',$row["customers_vat_id"])) {
                     $rowdata['taxzone_id'] = 1;
                 } else {
                     $rowdata['taxzone_id'] = 2;
                 }
             } else {
                 $rowdata['taxzone_id'] = 3;
             }
             if ($rowdata["cc_number"]) {
                 $rowdata["kreditkarte"] = $row['cc_type']."\n";
                 $rowdata["kreditkarte"] = $row['cc_number']." ID:".$row['cc_cvv']."\n";
                 $rowdata["kreditkarte"] = $row['cc_expires']."\n";
                 $rowdata["kreditkarte"] = $row['cc_owner']."\n";
             }
             $rowdata['cusordnumber']   = $row['orders_id'];
             $rowdata["versandart"] = $this->_toERP($row["shipping_method"]);
             $rowdata["notes"] = $this->_toERP($row["comments"]);
             $rowdata["curr"] = $this->_toERP($row["currency"]);
             $rowdata["transdate"] = substr($row["date_purchased"],0,10);
             $rowdata["shipvia"] = $this->_toERP($row["shipping_method"]);
             $rowdata["employee_id"] = $employee_id;
             $rowdata["parts"] = $artikel;
             $rowdata["mwst"] = $this->getTotal($row['orders_id'],'ot_tax');
             $rowdata["amount"]= $this->getTotal($row['orders_id'],'ot_total');
             $rowdata["netamount"] = $this->getTotal($row['orders_id'],'ot_subtotal');
             if ($row['delivery_company']) {
                 $delivery['name']    = $row['delivery_company'];
                 $delivery['contact'] = $row['delivery_firstname']." ".$row['delivery_lastname'];
             } else {
                 $delivery['name']  = $row['delivery_lastname'].', '.$row['delivery_firstname'];
             }
             $delivery['street']    = $row['delivery_street_address'];
             $delivery['city']      = $row['delivery_city'];
             $delivery['zipcode']   = $row['delivery_postcode'];
             $delivery['country']   = $row['delivery_country'];
             $delivery['phone']     = $row['delivery_telephone'];
             $delivery['email']     = $row['delivery_email_address'];
             if ($row['customers_company']) {
                 $customer['name']    = $row['customers_company'];
                 $customer['contact'] = $row['customers_firstname']." ".$row['customers_lastname'];
                 $customer['greeting']  = 'Firma';
             } else {
                 $customer['name']  = $row['customers_lastname'].', '.$row['customers_firstname'];
                 $customer['greeting']  = ($row['customers_gender'] == 'm')?'Herr':'Frau';
             }
             $customer['shopid']    = $row['customers_id'];
             $customer['street']    = $row['customers_street_address'];
             $customer['city']      = $row['customers_city'];
             $customer['zipcode']   = $row['customers_postcode'];
             $customer['country']   = $row['customers_country'];
             $customer['phone']     = $row['customers_telephone'];
             $customer['email']     = $row['customers_email_address'];
             $customer['contact']   = $row['customers_name'];
             $customer['customer_id']   = $row['customers_cid'];
             $rowdata['customer']   = $customer;
             if ( $customer != $delivery ) $rowdata['delivery'] = $delivery;
             $rowdata["customer"]['customernumber'] = $row['customers_cid'];
             $data[] = $rowdata;
        }
        return $data;
    }
    function getBestellArtikel($bestellung) {
        if (!$this->kategorien) $this->getKategorien();
    	$sql  = "SELECT OP.*,D.products_description,PC.categories_id as katid,PV.products_vpe_name,P.products_ean,P.products_image,P.products_weight ";
        $sql .= "FROM orders_products OP ";
        $sql .= "LEFT JOIN products_description D on OP.products_id=D.products_id ";
        $sql .= "LEFT JOIN products P on OP.products_id=P.products_id ";
        $sql .= "LEFT JOIN products_to_categories PC on OP.products_id = PC.products_id ";
        $sql .= "LEFT JOIN products_vpe PV ON PV.products_vpe_id = P.products_vpe ";
        $sql .= "WHERE (PV.language_id = ".$this->language." OR PV.language_id is Null) AND D.language_id = ".$this->language;
        $sql .= " AND OP.orders_id = $bestellung";
        $rs=$this->db->getAll($sql);
        if (!$rs) {
             $this->error->write("xtc","Die Artikel der Bestellung $bestellung konnte nicht gelesen werden");
             return false;
        }
        foreach ($rs as $row) {
            $row['partsgroup'] = $this->_toERP($this->Kategorien[$row['katid']]);
            $variant = $this->getVariant($row['orders_id'],$row['orders_products_id']);
            if ( $this->variantnr == 1 ) {
                $row['products_name'] = $this->_toERP($row['products_name'].$variant);
                $row['products_description'] = $this->_toERP($row['products_description']);
            } else {
                $row['products_name'] = $this->_toERP($row['products_name']);
                $row['products_description'] = $this->_toERP($variant.$row['products_description']);
            }
            //Shop muß immer Nettopreise liefern.
            if ($this->mwstS) {
                $row['products_price'] = round($row['products_price'] / (100+$row['products_tax'])*100,2);
            }
            $row['products_vpe_name'] = ( $row['products_vpe_name'] )?$this->_toERP($row['products_vpe_name']):$this->unit;
            $row['partsgroup'] = $this->_toERP($this->Kategorien[$row['katid']]);
            $data[] = $this->translateTable($row,"orderparts");
        }
        return $data;
    }
    function getVariant($oid,$aid) {
        $sql  = "SELECT * FROM orders_products_attributes WHERE orders_id = $oid AND orders_products_id = $aid";
        $rs = $this->db->getAll($sql);
        if ( $this->variantnr == 1 ) { $start = "\n"; $end = ""; }
        else { $start = ""; $end = "\n"; }
        $txt = '';
        if ($rs) foreach ($rs as $row) {
            $txt .= $start.sprintf('%s: %s %s%0.2f',$row['products_options'],$row['products_options_values'],$row['price_prefix'],$row['options_values_price']).$end;
        };
        return $txt;
    }
    function setAbgeholt($bestellung) {
        $sql = "UPDATE orders SET orders_status ='3' WHERE orders_id = $bestellung"; // in ($bestellungen)";
        $rc = $this->db->query($sql);
        if (!$rc) {
            $this->error->write("xtc","Die Bestellung $bestellung konnten nicht als abgeholt markiert werden");
            return false;
        } else {
            return true;
        }
    }
    function setKundenNr($id,$nr) {
        $sql = "UPDATE customers SET customers_cid = '$nr' WHERE customers_id = $id";
        $rc = $this->db->query($sql);
        if (!$rc) {
            $this->error->write("xtc","Die Kundennummer $nr konnte nicht dem Kunden $id zugeordnet werden");
            return false;
        } else {
            return true;
        }
    }
    function getAllArtikel() {
        if (!$this->Kategorien) $this->getKategorien();
    	$sql  = "SELECT P.*,D.*,PC.categories_id as katid,T.tax_rate as products_tax,PV.products_vpe_name FROM products P ";
        $sql .= "LEFT JOIN products_description D on P.products_id=D.products_id ";
        $sql .= "LEFT JOIN products_to_categories PC on P.products_id = PC.products_id ";
        $sql .= "LEFT JOIN tax_rates T ON T.tax_class_id = P.products_tax_class_id ";
        $sql .= "LEFT JOIN products_vpe PV ON PV.products_vpe_id = P.products_vpe ";
        $sql .= "WHERE T.tax_zone_id = ".$this->tax_zone." AND ";
        $sql .= "PV.language_id = ".$this->language." AND D.language_id = ".$this->language;
        $rs = $this->db->getAll($sql);
        if ($rs) foreach ($rs as $row) {
            $row['partsgroup'] = $this->_toERP($this->Kategorien[$row['katid']]);
            $row['name'] = $this->_toERP($row['products_name']);
            $row['beschreibung'] = $this->_toERP($row['products_description']);
            //if (!$this->mwstLX) $row['products_price'] = round(($row['products_price'] / (100 + $row['mwst_satz']) * 100),$this->dezimal);
            $data[] = $this->translateTable($row,"orderparts");
        }
        return $data;
    }
    function getKategorien() {
        $sql  = "SELECT C.categories_id,D.categories_name,C.parent_id ";
        $sql .= "FROM categories C LEFT JOIN categories_description D ON C.categories_id=D.categories_id ";
        $sql .= "WHERE C.parent_id >= 0 order by C.parent_id AND D.language_id = ".$this->language;
        $rs = $this->db->getAll($sql);
        if ($rs) {
            foreach($rs as $row) { $this->katrs[$row['categories_id']] = $row;};
            foreach($this->katrs as $row) {
            if ($row['parent_id'] == '0') {
                $name = $row['categories_name'];
            } else {
                $name = $this->mkKategorien($row['categories_id'],'');
            }
            $this->Kategorien[$row['categories_id']] = $name;
            }
        }
    }
    function mkKategorien($id,$name) {
        if ($this->katrs[$id]['parent_id'] == '0') {
           if ($name) {
                return $this->katrs[$id]['categories_name'].'!'.$name;
            } else {
                return $this->katrs[$id]['categories_name']."#";
            }
        } else {
           if (!$name) {
               $name = $this->katrs[$id]['categories_name'];
           } else {
               $name = $this->katrs[$id]['categories_name'].'!'.$name;
           }
               $name = $this->mkKategorien($this->katrs[$id]['parent_id'],$name);
        }
        return $name;
    }
}
?>
