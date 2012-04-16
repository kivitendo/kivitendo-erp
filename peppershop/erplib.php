<?php
/*

shop muß gesetzt sein, obsolet nicht

Multishop: Hierfür müssen benutzerdefinierte Variablen angelegt werden.
Typ:checkbox,  Name=shop[0-9A-Z]+, Bearbeitbar=nein 


*/

class erp {

    var $db = false;
    var $error = false;
    var $pricegroup = 0;
    var $TAX = false;
    var $mkPart = true;
    var $divStd = false;
    var $divVerm = false;
    var $doordnr = false;
    var $docustnr = false;
    var $lager = 1;
    var $warehouse_id = 0;
    var $transtype = 0;
    var $preordnr = '';
    var $precustnr = '';
    var $OEinsPart = false;
    var $INVnetto = true; //Rechnungen mit Nettopreisen
    var $SHOPincl = true; //Shoppreise sind Brutto

    function erp($db,$error,$divStd,$divVerm,$doordnr,$docustnr,$preordnr,$precustnr,$INVnetto,$SHOPincl,$OEinsPart,$lager,$pricegroup,$ERPusrID) {
        $this->db = $db;
        $this->pricegroup = $pricegroup;
        $this->employee_id = $ERPusrID;
        $this->error = $error;
        $this->divStd  = $divStd;
        $this->divVerm = $divVerm;
        $this->doordnr = $doordnr;
        $this->preordnr = $preordnr;
        $this->docustnr = $docustnr;
        $this->precustnr = $precustnr;
        $this->INVnetto = ($INVnetto == 1)?true:false;
        $this->SHOPincl = ($SHOPincl == 1)?true:false;
        $this->OEinsPart = ($OEinsPart == 1)?true:false;
        $this->lager = ($lager)?$lager:1;
        $this->getTax();
        if ( $lager > 1 ) {
            $sql  = "SELECT warehouse_id from bin where id = ".$this->lager;
            $rs = $this->db->getOne($sql);
            if ( $rs['warehouse_id'] > 0 ) {
		$this->warehouse_id = $rs['warehouse_id'];
                $sql = "SELECT id from transfer_type WHERE direction = 'in' and description = 'stock'";
                $rs = $this->db->getOne($sql);
                $this->transtype = $rs['id'];
            } else {
                $this->lager = 1;
            }
        }
    }

    function getTax() {
        $sql  = "SELECT  BG.id AS bugru,T.rate,TK.startdate,C.taxkey_id, ";
        $sql .= "(SELECT id FROM chart WHERE accno = T.taxnumber) AS tax_id, ";
        $sql .= "BG.income_accno_id_0,BG.expense_accno_id_0 ";
        $sql .= "FROM buchungsgruppen BG LEFT JOIN chart C ON BG.income_accno_id_0=C.id ";
        $sql .= "LEFT JOIN taxkeys TK ON TK.chart_id=C.id ";
        $sql .= "LEFT JOIN tax T ON T.id=TK.tax_id WHERE TK.startdate <= now()";
        $rs = $this->db->getAll($sql);
        if ($rs) foreach ($rs as $row) {
            $nr = $row['bugru'];
            if (!$this->TAX[$nr]) {
                $data = array();
                $data['startdate'] =     $row['startdate'];
                $data['rate'] =     $row['rate'];
                $data['taxkey'] =     $row['taxkey_id'];
                $data['taxid'] =     $row['tax_id'];
                $data['income'] =     $row['income_accno_id_0'];
                $data['expense'] =     $row['expense_accno_id_0'];
                $this->TAX[$nr] = $data;
            } else if ($this->TAX[$nr]['startdate'] < $row['startdate']) {
                $this->TAX[$nr]["startdate"] =     $row['startdate'];
                $this->TAX[$nr]["rate"] =     $row['rate'];
                $this->TAX[$nr]["taxkey"] =     $row['taxkey_id'];
                $this->TAX[$nr]["taxid"] =     $row['tax_id'];
                $this->TAX[$nr]["income"] =     $row['income_accno_id_0'];
                $this->TAX[$nr]["expense"] =     $row['expense_accno_id_0'];
            }
        }
    }

    function getParts($stdprice=0,$shop=0) {
        $where = "WHERE 1=1 ";
        if ($stdprice>0) {
             $sql  = "SELECT P.partnumber,P.description,P.notes,P.weight,G.price as sellprice,P.sellprice as stdprice,";
             $sql .= "PG.partsgroup,P.image,P.buchungsgruppen_id as bugru,P.unit";
             if ($this->lager>1) {
                   $sql .= ",(select sum(qty) from inventory where bin_id = ".$this->lager." and parts_id = P.id) as onhand ";
             } else {
                   $sql .= ",P.onhand ";
             }
             $sql .= "FROM parts P ";
             $sql .= "LEFT JOIN partsgroup PG on PG.id=P.partsgroup_id ";
             $sql .= "LEFT JOIN prices G on G.parts_id=P.id ";
             $where .= "AND (G.pricegroup_id=$stdprice ";
             $where .= "or G.pricegroup_id is null) ";
        } else {
             $sql  = "SELECT P.partnumber,P.description,P.notes,P.weight,P.sellprice,";
             $sql .= "PG.partsgroup,P.image,P.buchungsgruppen_id as bugru,P.unit ";
             if ($this->lager>1) {
                   $sql .= ",(select sum(qty) from inventory where bin_id = ".$this->lager." and parts_id = P.id) as onhand ";
             } else {
                   $sql .= ",P.onhand ";
             }
             $sql .= "FROM parts P left join partsgroup PG on PG.id=P.partsgroup_id ";
        }
        if ($shop>0) {  
            $sql .= "LEFT JOIN custom_variables CV on CV.trans_id=P.id ";
            $where .= "AND (CV.config_id = $shop AND bool_value = 't')";
        }
        $where .= "AND shop = 't' ";
        $where .= "AND obsolete = 'f' ORDER BY P.partnumber";
        $rs = $this->db->getAll($sql.$where);
        if ($rs) for($i = 0; $i < count($rs); $i++) {
           $rs[$i]['tax'] = $this->TAX[$rs[$i]['bugru']]['rate'];
        }
        return $rs;
    }

    function getPartsLang($lang,$alle) {
        $sql  = "SELECT P.partnumber,L.translation,P.description,L.longdescription,P.notes,PG.partsgroup ";
        $sql .= "FROM parts P left join translation L on L.parts_id=P.id left join partsgroup PG on PG.id=P.partsgroup_id ";
        $sql .= "WHERE P.shop='t' and (L.language_id = $lang";
        if ($alle) {
            $sql .= " or L.language_id is Null)";
        } else { 
            $sql.=")"; 
        };
        $rs = $this->getAll($sql);
        $data=array();
        if ($rs) foreach ($rs as $row) {
            if (!$data[$row["partnumber"]]) $data[$row["partnumber"]]=$row;
        }
        return $data;
    }
    function getNewNr($typ) {
        /*
          so = Auftragsnummer
          customer = Kundennummer 
        */
        $typ .= "number";
        $sql = "SELECT $typ FROM defaults";
        $rs = $this->db->getOne($sql);
        $i=strlen($rs["$typ"])-1;
        //Nummern können Buchstaben, Zeichen und Zahlen enthalten
        //nur die Zahlen von rechts werden aber inkrementiert.
        while($i>=0) {
            if ($rs["$typ"][$i] >= "0" and $rs["$typ"][$i]<="9") {
                $n=$rs["$typ"][$i].$n;
                $i--;
            } else {
                $pre = substr($rs["$typ"],0,$i+1);
                $i=-1;
            }
        };
        $nr = (int)$n + 1;
        $sonr = $pre.$nr;
        $sql = "UPDATE defaults SET $typ = '$sonr'";
        $rc = $this->db->query($sql);
        if (!$rc) {
            $this->error->write('erplib','Neue Nummer ($typ) nicht gesichert: '.$sonr);
        }
        return $sonr;
    }
    function newOrder($data) {
        /*Einen neuen Auftrag anlegen. Folgendes Array muß übergeben werden:
        $data = array(ordnumber,customer_id,employee_id,taxzone_id,amount,netamount,transdate,notes,intnotes,shipvia)
        Rückgabe oe.id */
        $this->db->begin();
        $incltax = ($this->INVnetto)?'f':'t';
        $sql  = "INSERT INTO oe (ordnumber,customer_id,employee_id,taxzone_id,taxincluded,curr,amount,netamount,transdate,notes,intnotes,shipvia,cusordnumber) ";
        $sql .= "values (:ordnumber,:customer_id,:employee_id,:taxzone_id,'$incltax',:curr,:amount,:netamount,:transdate,:notes,:intnotes,:shipvia,:cusordnumber)";
        $rc = $this->db->insert($sql,$data);
        $sql = "SELECT * FROM oe where ordnumber = '".$data["ordnumber"]."'";
        $rs = $this->db->getOne($sql);
        if (!$rs['id']) {
            $this->error->write('erplib','Auftrag erzeugen: '.$data["ordnumber"]);
            $this->db->rollback();
            return false;
        } else {
            $this->error->out(" Auftrag: ".$data["ordnumber"]." ");
            return $rs['id'];
        }
    }
    function insParts($trans_id,$data,$longtxt) {
        /*Artikel in die orderitem einfügen. Folgende Daten müssen übergeben werden:
        $trans_id = (int) oe.id
        $data = array(trans_id,partnumber,description,longdescription,qty,sellprice,unit)*/
        foreach ($data as $row) {
             $row['trans_id'] = $trans_id;
             //$sql = "SELECT id FROM parts WHERE partnumber = '".$row['partnumber']."'";
             //$tmp = $this->db->getOne($sql);
             $tmp = $this->chkPartnumber($row,$this->OEinsPart,true);
             if ($tmp) {
                 $row['parts_id'] = $tmp['id'];
             } else {
                 if ($this->TAX[$this->divStd['BUGRU']]['rate'] == $row['mwst']/100) {
                      $row['parts_id'] = $this->divStd['ID'];
                 } else if ($this->TAX[$this->divVerm['BUGRU']]['rate'] == $row['mwst']/100) {
                      $row['parts_id'] = $this->divVerm['ID'];
                 } else {
                      $row['parts_id'] = $this->divStd['ID'];
                 }
             }
             if ($this->INVnetto) {
                 if ($this->SHOPincl) 
                     $row['sellprice'] = round($row['sellprice'] / (100 + $row['taxrate']) * 100,2);
             } else {
                 if (!$this->SHOPincl) 
                     $row['sellprice'] = round($row['sellprice'] * (100 + $row['taxrate']) * 100,2);
             }
             $row['unit'] = $this->chkUnit($row['unit']);
             if ($longtxt == 1) {
                 //$row['longdescription'] = addslashes($row['longdescription']);
                 $row['longdescription'] = $row['longdescription'];
             } else {
                 //$row['longdescription'] = addslashes($tmp['longdescription']);
                 $row['longdescription'] = $tmp['longdescription'];
             }
             //$row['description'] = addslashes($row['description']);
             $sql  = "INSERT INTO orderitems (trans_id,parts_id,description,longdescription,qty,sellprice,unit,pricegroup_id,discount) ";
             $sql .= "VALUES (:trans_id,:parts_id,:description,:longdescription,:qty,:sellprice,:unit,0,0)";
             $row["trans_id"]=$trans_id;
             $rc = $this->db->insert($sql,$row);
             if (!$rc) {
                 $this->db->rollback();
                 return false;
             };
        };
        $this->db->commit();
        return true;
    }
    function insCustomer($data) {
        $this->error->out('Insert:'.$data["name"].' ');
        if ($this->docustnr == 1) {
            $data['customernumber'] = $this->getNewNr('customer');
        } else {
            $data['customernumber'] = $data['shopid'];
        }
        $data['customernumber'] = $this->precustnr.$data['customernumber'];
            if ($data['customernumber']>0) {
                if (!$data['greeting']) $data['greeting'] = '';
                $sql  = "INSERT INTO customer (greeting,name,street,city,zipcode,country,contact,phone,email,customernumber)";
                $sql .= " VALUES (:greeting,:name,:street,:city,:zipcode,:country,:contact,:phone,:email,:customernumber)";
                $rc =  $this->db->insert($sql,$data);
                $sql = "SELECT id FROM customer WHERE customernumber = '".$data['customernumber']."'";
                $rs = $this->db->getOne($sql);
                $rc = $rs['id'];
                $this->error->out("Kd-Nr: ".$data['customernumber'].":".$rs['id']);
            } else {
                $this->error->write('erplib','Kunde anlegen: '.$data["name"]);
                $this->db->rollback();
                return false;
            }
            return $rc;
    }
    function chkCustomer($data) {
        if ($data['customer_id']>0) {
            $sql = "SELECT * FROM customer WHERE id = ".$data['customer_id'];
            $rs = $this->db->getOne($sql);
            if ($rs['id'] == $data['customer_id']) {
                 $this->error->out('Update:'.$data['customer_id'].' ');
                 $sql  = "UPDATE customer SET greeting = :greeting,name = :name,street = :street,city = :city,country = :country,";
                 $sql .= "zipcode = :zipcode,contact = :contact,phone = :phone,email = :email WHERE id = :customer_id";
                 $rc =  $this->db->update($sql,$data);
                 if ($rc) $rc = $data['customer_id'];
            } else {
                $rc = $this->insCustomer($data);
            }
        } else {
            $rc = $this->insCustomer($data);
        }
        return $rc;
    }
    function mkAuftrag($data,$shop,$longtxt) {
        $this->db->Begin();
        $data["notes"] .= "\nBezahlung:".$data['bezahlung']."\n";
        if ($data['bezahlung'] == "Kreditkarte")   $data["notes"] .= $data['kreditkarte']."\n"; 
        if ($shop) { 
           $data["intnotes"] = "Shop: $shop";
        } else {
           $data["intnotes"] = "";
        };
        $data["customer_id"] = $this->chkCustomer($data["customer"]);
        $parts = $data['parts'];
        unset($data['parts']);
        unset($data['customer']);
        if ($this->doordnr == 1) {
            $data["ordnumber"] = $this->getNewNr('so');
        } else {
            $data["ordnumber"] = $data['cusordnumber'];
        }
        $data["ordnumber"] = $this->preordnr.$data["ordnumber"];
        $tid = $this->newOrder($data);
        if ($tid) {
            $rc = $this->insParts($tid,$parts,$longtxt);  
            if (!$rc) {
                 $this->error->write('erplib','Artikel zu Auftrag');
                 return -1;
            }
        } else {
            $this->error->write('erplib','Auftrag anlegen');
            return -1;
        }
        $this->error->out($data["customer"]["firma"]." ");
        $rc = $this->db->Commit();
        return $data["customer_id"];
    }
    function chkPartsgroup($pg,$new=True) {
       /*gibt es die Warengruppe?
       Rückgabe nichts oder die partsgroup.id
       ggf neu anlegen*/
       $sql = "SELECT * FROM partsgroup WHERE partsgroup = '".$pg."'";
       $rs = $this->db->getOne($sql);
       if ($rs) {
           return $rs['id'];
       } else if ($this->mkPart and $new) {
           return $this->mkNewPartsgroup($pg);
       } else {
           return '';
       };
    }
    function mkNewPartsgroup($name) {
       $sql = "INSERT INTO partsgroup (partsgroup) VALUES ('".$name."')";
       $rc = $this->db->query($sql);
       if ($rc) {
           return $this->chkPartsgroup($name,False);
       } else {
           return '';
       }
    }
    function chkUnit($unit) {
       /*Prüfen ob es die Unit gibt.
         wenn nicht, die Standardunit zurückgeben*/
       if ($unit == '') {
           return $this->stdUnit();
       } else {
           $sql = "SELECT * FROM units WHERE name ilike '".$unit."'";
           $rs = $this->db->getOne($sql);
           if ($rs) {
              return $rs["name"];
           } else {
               return $this->stdUnit();
           }
       }
    }
    function stdUnit() {
       $sql = "SELECT * FROM units WHERE type = 'dimension' ORDER BY sortkey LIMIT 1";
       $rs = $this->db->getOne($sql);
       return $rs["name"];
    }
    function chkPartnumber($data,$new=True,$long=false) {
       $sql = "SELECT * FROM parts WHERE partnumber = '".$data["partnumber"]."'";
       $rs = $this->db->getOne($sql);
       if ($rs) {
           if ($long) {
               return $rs;
           } else {
               return $rs['id'];
           }
       } else if ($new and $this->mkPart) {
           $data['id'] = $this->mkNewPart($data);
           if ($long) {
               return $data;
           } else {
               return $data['id'];
           }
       } else {
           return '';
       };
    }
    function mkNewPart($data) {
       /*eine neue Ware anlegen, sollte nicht direkt aufgerufen werden.
       Auf vorhandene partnumber wird nicht geprüft.
       Folgendes Array muß übergeben werden:
       $data = array(partnumber,description,longdescription,weight,sellprice,taxrate,partsgroup,unit)
       Rückgabe parts.id
       */
       $link = '<a href="../ic.pl?action=edit&id=%d" target="_blank">';
       if ($data['partnumber'] == '') {
           $this->error->write('erplib','Artikelnummer fehlt');
           return false;
       }
       if ($data['description'] == '') {
           $this->error->write('erplib','Artikelbezeichnung fehlt');
           return false;
       }
       $data['notes'] = addslashes($data['longdescription']);
       if ($data['weight']*1 != $data['weight']) $data['weight']=0;
       if ($data['sellprice']*1 != $data['sellprice']) $data['sellprice']=0;
       if (!in_array($data["buchungsgruppen_id"],$this->TAX)) {
           foreach ($this->TAX as $key=>$tax) {
                if ($tax["rate"] == $data["taxrate"]/100) {
                    $data["buchungsgruppen_id"] = $key;
                    break;
                }
           }
           if (!$data["buchungsgruppen_id"]) {
               $this->error->write('erplib','Buchungsgruppe konnte nicht zugeordnet werden');
               return false;
           }
       };
       if ($data["partsgroup"]) {
           $data["partsgroup_id"] = $this->chkPartsgroup($data["partsgroup"]);
       } else {
           $data["partsgroup_id"] = '';
       };
       $data['unit'] = $this->chkUnit($data['unit']);
       if ($data['unit'] == '') {
           $this->error->write('erplib','Artikeleinheit fehlt oder falsch');
           return false;
       }
       $data['shop'] = 't';
       $sql  = "INSERT INTO parts (partnumber,description,sellprice,weight,notes,shop,unit,partsgroup_id,";
       $sql .= "image,buchungsgruppen_id,inventory_accno_id,income_accno_id,expense_accno_id) ";
       $sql .= "VALUES (:partnumber,:description,:sellprice,:weight,:notes,:shop,:unit,:partsgroup_id,";
       $sql .= ":image,:buchungsgruppen_id,1,1,1)";
       $rc = $this->db->insert($sql,$data);
       $data['parts_id'] = $this->chkPartnumber($data,false);
       if ( $this->pricegroup > 0 ) {
            $sql  = "INSERT INTO prices (parts_id,pricegroup_id,price) VALUES (:parts_id,:pricegroup,:shoppreis)";
            $data['pricegroup'] = $this->pricegroup;
            $rc = $this->db->insert($sql,$data);
       };
       if ( $data['onhand'] > 0 and $this->lager > 1) $this->insLager($data);
       $x =  $this->chkPartnumber($data,False);
       $this->error->write('erplib',$data['description'].' '.$data['partnumber']);
       $this->error->out(sprintf($link,$data['parts_id']).$data['description'].' '.$data['partnumber'].'</a>',true);
       return $x;
    }
    function insLager($data) {
        $rc = $this->db->Begin();
        $sql = "SELECT nextval(('id'::text)::regclass) as id from id";
        $rs = $this->db->getOne($sql);
        $sql  = "INSERT INTO inventory (warehouse_id,parts_id,shippingdate,employee_id,bin_id,qty,trans_id,trans_type_id,comment) ";
        $sql .= "VALUES (:wid,:parts_id,now(),:employee_id,:bid,:onhand,:next,:tt,'Shopübernahme')";
        $data['next'] = $rs['id'];
        $data['tt'] = $this->transtype;
        $data['bid'] = $this->lager;
        $data['wid'] = $this->warehouse_id;
        $data['employee_id'] = $this->employee_id;
        $rc = $this->db->insert($sql,$data);
        if ( $rc ) {
           $this->db->Commit();
        } else {
           $this->db->Rollback();
        }
    }
}
?>
