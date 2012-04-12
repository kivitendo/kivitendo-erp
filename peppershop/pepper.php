<?php
/*
Funktionen für den Zugriff auf den Peppershop
*/

class pepper {

    var $db = false;
    var $error = false;
    var $divStd = false;
    var $divVerm = false;
    var $minder = false;
    var $paypal = false;
    var $treuh = false;
    var $nachn = false;
    var $shopcode = 'ISO-8859-1';
    var $erpcode = 'UTF-8';
    var $VariantNr = true;
    var $EU = array('AT','BE','BG','CZ','DK','EE','ES','FI','FR','GB','GR','HR','HU','IE','IT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK');
    var $Kategorien = False;
    var $dezimal = 2;

    var $tableerp  = array("partnumber"=>"artikel_nr","description"=>"name","notes"=>"beschreibung",
                           "unit"=>"anzahl_einheit","weight"=>"gewicht","sellprice"=>"preis",
                           "tax"=>"mwst_satz","image"=>"bild_gross","onhand"=>"lagerbestand");
    var $tableshop = array("datum"=>"transdate","rechnungsbetrag"=>"amount","nettobetrag"=>"netamount","waehrung"=>"curr",
                           "anmerkung"=>"notes","mwst"=>"mwst","bestellungs_id"=>"cusordnumber","bezahlungsart"=>"bezahlung",
                           "kreditkarte"=>"kreditkarte","versandart"=>"shipvia");
    var $custshop   = array("kontakt"=>"contact","ort"=>"city","plz"=>"zipcode","land"=>"country","tel"=>"phone",
                            "fax"=>"fax","email"=>"email","beschreibung"=>"notes","strasse"=>"street","firma"=>"name",
                            "kunden_nr"=>"customer_id","anrede"=>"greeting","k_id"=>"shopid",
                            "bankname"=>"bank","blz"=>"bank_code","kontonummer"=>"account_number",
                            "iban"=>"iban","bic"=>"bic","attributwert1"=>"ustid");
    var $ordershop  = array("datum"=>"transdate","rechnungsbetrag"=>"amount","rechnungs_nr"=>"",
                            "waehrung"=>"currency","beschreibung"=>"notes",
                            "mwst"=>"mwst","versandart"=>"shipvia");
    var $orderparts = array("artikelname"=>"description","name"=>"description","preis"=>"sellprice","anzahl"=>"qty","artikel_nr"=>"partnumber",
                            "partsgroup"=>"partsgroup","beschreibung"=>"longdescription","gewicht"=>"weight","shoppreis"=>"shoppreis",
                            "mwst_satz"=>"taxrate","bild_gross"=>"image","anzahl_einheit"=>"unit","lagerbestand"=>"onhand");
    var $pic = false;

    function pepper($db,$error,$dbname,
                    $divStd,$divVerm,$minder,$nachn,$versandS,$versandV,$paypal,$treuhand,
                    $mwstLX,$mwstS,$variantnr,$pic=false,$nopic=false,$nopicerr=false,$nofiles=false,
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
        $this->treuhand = $treuhand;
        $this->erpcode  = $erpcode;
        $this->mwstLX   = $mwstLX;
        $this->mwstS    = $mwstS;
        $this->VariantNr = ($variantnr==1)?true:false;
        $this->pic       = $pic;
        $this->nopic     = ( $nopic != '' )?$nopic:false;
        $this->nopicerr  = ( $nopicerr != '' )?true:false;
        $this->nofiles     = $nofiles;
        if ($shopcode == 'AUTO') {
            $sql = "SELECT TABLE_COLLATION FROM information_schema.TABLES WHERE table_schema = '$dbname' AND table_name = 'kunde'";
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
    function getCategoryID($name,$mwst) {
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
        $sql = "select * from kategorien where name like '%s' and parent_id = %d";
        if (count($kat)>0) foreach ($kat as $wg) {
            $sql_ = sprintf($sql,$wg,$parent);
            $rs=$this->db->getOne($sql_);
            if ($rs["kategorie_id"]) {                   // gefunden
                $parent=$rs["kategorie_id"];
                $mwst=$rs["mwst_satz"];
            } else {                    // nicht gefunden, anlegen
                $parent=$this->createCategory($wg,$mwst,$parent);
            }
        }
        return $parent;
    }
    function createCategory($name,$mwst,$parent) {
        $sql = "select max(positions_nr) as cnt from kategorien WHERE parent_id = ".$parent;
        $rs=$this->db->getOne($sql);
        $pos = $rs['cnt'] + 1;
        $sql  = "INSERT INTO kategorien (positions_nr,name,mwst_satz,ist_sichtbar,parent_id) ";
        $sql .= "VALUES (".$pos.",'".$name."',".$mwst.",'Y',".$parent.")";
        $rc = $this->db->query($sql);
        if ($rc) {
            $sql = "SELECT kategorie_id FROM kategorien where name = '".$name."' and parent_id = ".$parent;
            $rs = $this->db->getOne($sql);
            return $rs['kategorie_id'];
        } else {
            return false;
        }
    }
    function getLang($lang) {
         $sql = "SELECT * FROM locale WHERE iso_639_1_code like '$lang' and aktiviert = 'Y'";
         $rs = $this->db->getOne($sql);
         return $rs['locale_id'];
    }
    function saveArtikel($data,$lang) {
         $langID = $this->getLang(strtolower($lang));
         $values = $this->translateTable($data,"tableerp"); //$this->tableerp);
         if ($this->mwstLX and !$this->mwstS) { //ERP-Bruttopreis Shop-Nettopreis
              $values['preis'] = round($values['preis'] / (1 + $values["mwst_satz"]),2);
         } else if (!$this->mwstLX and $this->mwstS) { //ERP-Nettopreis Shop-Bruttopreis
              $values['preis'] = round($values['preis'] * (1 + $values["mwst_satz"]),2);
         }
         $values["name"] = $this->_toShop($values["name"]);
         $values["beschreibung"] = $this->_toShop($values["beschreibung"]);
         $values["mwst_satz"] = $values["mwst_satz"] * 100;
         $values["kategorie_id"] = $this->getCategoryID($data["partsgroup"],$values["mwst_satz"]);
         $values["artikel_id"] = $this->checkArtikelOK($values["artikel_nr"]);  
         if ($values["artikel_id"]>0)  {
             $rc = $this->updateArtikel($values);
         } else {
             $rc = $this->insertArtikel($values);
         };
         return $rc;
    }
    function checkArtikelOK($nr) {
        $sql = "SELECT artikel_id,artikel_nr FROM artikel WHERE artikel_nr = '".$nr."'";
        $rs = $this->db->getOne($sql);
        if ( $rs["artikel_nr"] == $nr ) {
            return $rs["artikel_id"];
        } else {
            return false;
        }
    }
    function insertArtikel($data) {
        $newID = uniqid(rand());
        $this->db->Begin();
        $sql = "INSERT INTO artikel (artikel_nr,name) VALUES ('".$data["artikel_nr"]."','$newID')";
        $rc = $this->db->query($sql);
        $sql = "SELECT * FROM artikel WHERE name='$newID'";
        $rs = $this->db->getOne($sql);
        if ($rs['name'] == $newID) {
            $data["artikel_id"] = $rs["artikel_id"];
            $statement = "INSERT INTO artikel_kategorie (fk_artikel_id,fk_kategorie_id) VALUES (?,?)";
            $values = array($rs["artikel_id"],$data["kategorie_id"]);
            $rc = $this->db->insert($statement,$values);
            if (!$rc) {
                 $this->error->out($data['artikel_nr'].' konnte nicht zur Gruppe '.$data['kategorie_id'].' zugef&uuml;gt werden.');
                 $this->error->write('pepper',$data['artikel_nr'].' konnte nicht zur Gruppe '.$data['kategorie_id'].' zugefügt werden.');
                 $this->db->Rollback();
                 return false;
            }
            $this->db->Commit();
            $this->error->out($data['artikel_nr']." insert ",true);
            $rc = $this->updateArtikel($data);
        } else { return false; }
        return $rc;
    }
    function updateArtikel($values) {
        $sql  = "UPDATE artikel SET name = :name, beschreibung = :beschreibung, preis = :preis, gewicht = :gewicht, ";
        if ( !$this->nofiles ) {
             //vorhandene Bilder übertragen
             if ( $values['bild_gross'] != '' ) {
                 preg_match("/(.+)\.(jpg|png|jpeg|gif)/i",$values['bild_gross'],$tmp);
                 $sql .= "bild_gross = :bild_gross, bild_klein = :bild_klein, bildtyp = :bildtyp, ";
                 if ( count($tmp) == 3 ) {
                     if ( $this->pic &&  $this->pic->copyImage($values['artikel_id'],$values['bild_gross'],$tmp[2]) ) {
                         $values['bild_gross'] = $values['artikel_id']."_gr.".$tmp[2];
                         $values['bild_klein'] = $values['artikel_id']."_kl.".$tmp[2];
                         $values['bildtyp'] = $tmp[2];
                     } else if ( $this->nopic ){
                         $sql .= "bild_gross = :bild_gross, bild_klein = :bild_klein, bildtyp = :bildtyp, ";
                         $values['bild_gross'] = $this->nopic."_gr.jpg";
                         $values['bild_klein'] = $this->nopic."_kl.jpg";
                         $values['bildtyp'] = 'jpg';
                     }
                 } 
             } else if ( $this->nopic && !$this->nopicerr ){
                 $sql .= "bild_gross = :bild_gross, bild_klein = :bild_klein, bildtyp = :bildtyp, ";
                 $values['bild_gross'] = $this->nopic."_gr.jpg";
                 $values['bild_klein'] = $this->nopic."_kl.jpg";
                 $values['bildtyp'] = 'jpg';
             }
        }
        $sql .= "mwst_satz = :mwst_satz, anzahl_einheit = :anzahl_einheit ";
        //Kein Lagerbestand übergeben, also nichts ändern
        if ( $values['lagerbestand'] != '' ) $sql .= ",lagerbestand = :lagerbestand ";
        $sql .= "WHERE artikel_id = :artikel_id ";
        $rc = $this->db->update($sql,$values);
        if ($rc) { 
            return $values["artikel_id"];
        } else {
            return false;
        }
    }
    function getBestellung($employee_id) {
        $sql = "SELECT * FROM mehrwertsteuer WHERE beschreibung = 'Porto und Verpackung'";
        $rs = $this->db->getOne($sql);
        $versandsteuer = $rs["mwst_satz"];
        $sql = "SELECT * FROM bestellung WHERE bestellung_bezahlt='N' ";
        $sql .= "AND rechnungs_nr != '' AND session_id = '' ";
        $sql .= 'ORDER BY bestellungs_id';
        $rs=$this->db->getAll($sql);
        if (!$rs) return array(); 
        $data = false; 
        foreach ($rs as $row) {
             $tmp = $this->getBestellArtikel($row["bestellungs_id"]);
             $artikel = $tmp['data'];
             if ($versandsteuer == -2) $versandsteuer = $tmp['mwst'];
             if ($row["versandkosten"]>0) {
                 if ($versandsteuer ==  $this->versandV['TAX']) {
                     $artikel[]  = array("partnumber"=>$this->versandV['NR'],"description"=>$this->versandV['TXT'],
                                          "qty"=>1,"unit"=>$this->versandV['Unit'],"sellprice"=>$row["versandkosten"]);
                 } else {
                     $artikel[]  = array("partnumber"=>$this->versandS['NR'],"description"=>$this->versandS['TXT'],"taxrate"=>$this->versandS['TAX'],
                                          "qty"=>1,"unit"=>$this->versandS['Unit'],"sellprice"=>$row["versandkosten"]);
                 }
             }
             if ($row["nachnamebetrag"]>0) 
                 $artikel[] = array("partnumber"=>$this->nachn['NR'],"description"=>$this->nachn['TXT'],"taxrate"=>$this->nachn['TAX'],
                                    "qty"=>1,"unit"=>$this->nachn['Unit'],"sellprice"=>$row["nachnamebetrag"]);
             if ($row["paypalkosten"]>0) 
                 $artikel[]   = array("partnumber"=>$this->paypal['NR'],"description"=>$this->paypal['TXT'],"taxrate"=>$this->paypal['TAX'],
                                      "qty"=>1,"unit"=>$this->paypal['Unit'],"sellprice"=>round($row["paypalkosten"],2));
             if ($row["treuhandkosten"]>0) 
                 $artikel[] = array("partnumber"=>$this->treuh['NR'],"description"=>$this->treuh['TXT'],"taxrate"=>$this->treuh['TAX'],
                                      "qty"=>1,"unit"=>$this->treuh['Unit'],"sellprice"=>$row["treuhandkosten"]);
             if ($row["mindermengenzuschlag"]>0) 
                 $artikel[] = array("partnumber"=>$this->minder['NR'],"description"=>$this->minder['TXT'],"taxrate"=>$this->minder['TAX'],
                                    "qty"=>1,"unit"=>$this->minder['Unit'],"sellprice"=>$row["mindermengenzuschlag"]);
             if ($row["versandland_id"] == "DE") {
                 $taxzone_id = 0;
             } else if (in_array($this->EU,$row["versandland_id"])) {
                 if (preg_match('/^[^0-9]{2,3}[ 0-9]+$/',$row["customer"]['ustid'])) {
                     $taxzone_id = 1;
                 } else {
                     $taxzone_id = 2;
                 }
             } else {
                 $taxzone_id = 3;
             }
             if ($row["kreditkarten_nummer"]) {
                 $row["kreditkarte"] = $row['kreditkarten_hersteller']."\n";
                 $row["kreditkarte"] = $row['kreditkarten_nummer']." ID:".$row['kreditkarten_id']."\n";
                 $row["kreditkarte"] = $row['kreditkarten_ablaufdatum']."\n";
                 $row["kreditkarte"] = $row['kreditkarten_vorname']." ".$row['kreditkarten_nachname']."\n";
             }
             $row["versandart"] = $this->_toERP($row["versandart"]);
             $row = $this->translateTable($row,"tableshop");
             $row["taxzone_id"] = $taxzone_id;
             $row["notes"] = $this->_toERP($row["notes"]);
             $row["employee_id"] = $employee_id;
             $row["parts"] = $artikel;
             $row["mwst"] = round($row["mwst"],2);
             $row["amount"]= round($row["amount"],2);
             $row["netamount"] = $row["amount"] - $row["mwst"];
             $row["customer"] = $this->getBestellungKunde($row["cusordnumber"]);
             $data[] = $row;
        }
        return $data;
    }
    function getBestellungKunde($bestellung) {
        $sql  = "SELECT * FROM kunde LEFT JOIN bestellung_kunde ON Kunden_ID=FK_Kunden_ID ";
        $sql .= "WHERE  FK_Bestellungs_ID=$bestellung";
        $rs=$this->db->getOne($sql);
        if ($rs["firma"]) {
            $rs["kontakt"] = $this->_toERP($rs["vorname"]." ".$rs["nachname"]);
            $rs["firma"]  = $this->_toERP($rs["firma"]);
        } else {
            $rs["kontakt"] = $this->_toERP($rs["vorname"]." ".$rs["nachname"]);
            $rs["firma"] = $this->_toERP($rs["nachname"].", ".$rs["vorname"]);
        }
        $rs["strasse"] = $this->_toERP($rs["strasse"])." ".$rs['hausnummer'];
        $rs["ort"] = $this->_toERP($rs["ort"]);
        $rs["bankname"] = $this->_toERP($rs["bankname"]);
        if ($rs) {
            return $this->translateTable($rs,"custshop");
        } else {
            $this->error->write("pepper","Die Kunde der Bestellung $bestellung konnte nicht gelesen werden");
            return false;
        }
    }
    function getBestellArtikel($bestellung) {
        if (!$this->kategorien) $this->getKategorien();
        $sql  = "SELECT B.*,P.artikel_nr,P.beschreibung,P.mwst_satz,P.anzahl_einheit,P.bild_gross,";
        $sql .= "AK.fk_kategorie_id as partsgroup ";
        $sql .= "FROM artikel_bestellung B LEFT JOIN artikel P ";
        $sql .= "ON B.fk_artikel_id=P.artikel_id LEFT JOIN artikel_kategorie AK on AK.fk_artikel_id=P.artikel_id ";
        $sql .= "WHERE fk_bestellungs_id=".$bestellung;
        $rs=$this->db->getAll($sql);
        if (!$rs) {
             $this->error->write("pepper","Die Artikel der Bestellung $bestellung konnte nicht gelesen werden");
             return false;
        }
        $a_b_ID = array();
        foreach ($rs as $row) {
            if (in_array($row['a_b_id'],$a_b_ID)) continue; 
            $row['artikelname'] = $this->_toERP($row['artikelname']);
            $row['beschreibung'] = $this->_toERP($row['beschreibung']);
            if ($row['variation'] != '') {
                  $tmp = $this->splitVariant($row['variation'],$row['anzahl'],$row['fk_artikel_id']);
                  $row['artikelname'] .= $this->_toERP($tmp['text']);
                  $row['preis'] += $tmp['preis'];
                  if ($tmp['nr']) $row['artikel_nr'] .= '-'.$tmp['nr'];
            }
            if ($row['optionen'] != '') {
                  $tmp = $this->splitOption($row['optionen'],$row['anzahl']);
                  $row['artikelname'] .= $this->_toERP($tmp['text']);
                  $row['preis'] += $tmp['preis'];
            }
            $row['anzahl_einheit'] = $this->_toERP($row['anzahl_einheit']);
            $row['partsgroup'] = $this->_toERP($this->Kategorien[$row['partsgroup']]);
            $mwst[$row['mwst_satz']] = $row['preis'] * $row['anzahl'] / (100+$row['mwst_satz']) * 100;
            $data[] = $this->translateTable($row,"orderparts");
            $a_b_ID[] = $row['a_b_id'];
        }
        arsort($mwst);
        $tmp = each($mwst); //MwSt-Satz mit grösstem Anteil
        return array('data'=>$data,'mwst'=>$tmp['key']);
    }
    function splitVariant($txt,$qty,$artnr) {
          $vari=split(chr(254),$txt);
          $text = '';
          $preis = 0;
          if ($vari) { 
              for($cnt=0; $cnt<count($vari); $cnt++) {
                  $nr = false;
                  $tmp = split('<::>',$vari[$cnt]);
                  if ($this->VariantNr) {
                      //$nr = $this->_getVariantNr($tmp[0],$tmp[1],$artnr);
                      $sql  = 'SELECT variations_nr FROM artikel_variationen where fk_artikel_id = '.$artnr;
                      $sql .= ' and variationstext = \''.$tmp[1].'\' and variations_grp = (';
                      $sql .= 'SELECT gruppen_nr FROM artikel_variationsgruppen WHERE fk_artikel_id = '.$artnr;
                      $sql .= ' AND gruppentext = \''.$tmp[0].'\')';
                      $rs=$this->db->getOne($sql);
                      $nr = $rs['variations_nr'];
                  } 
                  //$text.="\n".$tmp[0].": ".$tmp[1];
                  $text.=", ".$tmp[0].": ".$tmp[1];
                  $cnt++;
                  $preis+=trim($vari[$cnt]) * $qty;
              }
          };
          return array("preis"=>$preis,"text"=>$text,"nr"=>$nr);
    }
    function splitOption($txt,$qty) {
          $vari=split(chr(254),$txt);
          $text = '';
          $preis = 0;
          if ($vari) { 
              for($cnt=0; $cnt<count($vari); $cnt++) {
                  $text.="\n".str_replace('<::>',': ',$vari[$cnt]);
                  $cnt++;
                  $preis+=trim($vari[$cnt]) * $qty;
              }
          };
          return array("preis"=>$preis,"text"=>$text);
    }
    function setAbgeholt($bestellung) {
        $sql = "UPDATE bestellung SET Bestellung_bezahlt='Y' WHERE Bestellungs_ID = $bestellung"; // in ($bestellungen)";
        $rc = $this->db->query($sql);
        if (!$rc) {
            $this->error->write("pepper","Die Bestellung $bestellung konnten nicht als abgeholt markiert werden");
            return false;
        } else {
            return true;
        }
    }
    function setKundenNr($id,$nr) {
        $sql = "UPDATE kunde SET kunden_nr = '$nr' WHERE k_id = $id";
        $rc = $this->db->query($sql);
        if (!$rc) {
            $this->error->write("pepper","Die Kundennummer $nr konnte nicht dem Kunden $id zugeordnet werden");
            return false;
        } else {
            return true;
        }
    }
    function getAllArtikel() {
        if (!$this->Kategorien) $this->getKategorien();
        $sql = "SELECT a.*,k.fk_kategorie_id as katid FROM artikel a LEFT JOIN artikel_kategorie k on a.artikel_id = k.fk_artikel_id";
        $rs = $this->db->getAll($sql);
        if ($rs) foreach ($rs as $row) {
            $row['partsgroup'] = $this->_toERP($this->Kategorien[$row['katid']]);
            $row['name'] = $this->_toERP($row['name']);
            $row['beschreibung'] = $this->_toERP($row['beschreibung']);
            $row['shoppreis'] = $row['preis'];
            if (!$this->mwstLX) $row['preis'] = round(($row['preis'] / (100 + $row['mwst_satz']) * 100),$this->dezimal);
            $data[] = $this->translateTable($row,"orderparts");
        }
        return $data;
    }
    function getKategorien() {
        $sql = "SELECT kategorie_id,name,parent_id FROM kategorien WHERE parent_id >= 0 order by parent_id";
        $rs = $this->db->getAll($sql);
        if ($rs) {
            foreach($rs as $row) { $this->katrs[$row['kategorie_id']] = $row;};
            foreach($this->katrs as $row) {
            if ($row['parent_id'] == '0') {
                $name = $row['name'];
            } else {
                $name = $this->mkKategorien($row['kategorie_id'],'');
            }
            $this->Kategorien[$row['kategorie_id']] = $name;
            }
        }
    }
    function mkKategorien($id,$name) {
        if ($this->katrs[$id]['parent_id'] == '0') {
            if ($name) {
                return $this->katrs[$id]['name'].'!'.$name;
            } else {
                return $this->katrs[$id]['name']."#";
            }
        } else {
            if (!$name) {
            $name = $this->katrs[$id]['name'];
        } else {
            $name = $this->katrs[$id]['name'].'!'.$name;
        }
            $name = $this->mkKategorien($this->katrs[$id]['parent_id'],$name);
        }
        return $name;
    }
}
?>
