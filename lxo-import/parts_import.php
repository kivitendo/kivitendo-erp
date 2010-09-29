<?php
//Henry Margies <h.margies@maxina.de>
//Holger Lindemann <hli@lx-system.de>

/**
 * Returns ID of a partgroup (or adds a new partgroup entry)
 * \db is the database
 * \value is the partgroup name
 * \add if true and partgroup does not exist yet, we will add it automatically
 * \returns partgroup id or "" in case of an error
 */
function getPartsgroupId($db, $value, $add) {
    $sql="select id from partsgroup where partsgroup = '$value'";
    $rs=$db->getAll($sql);
    if (empty($rs[0]["id"]) && $add) {
        $sql="insert into partsgroup (partsgroup) values ('$value')";
        $rc=$db->query($sql);
        if (!$rc)
            return "";
        return getPartsgroupId($db, $value, 0);
    }
    return $rs[0]["id"];
}
function getPricegroup($db) {
    $sql="SELECT * from pricegroup";
    $rs=$db->getAll($sql);
    $data = false;
    if ($rs) foreach ($rs as $row) {
        $data["pg_".strtolower($row["pricegroup"])]=$row["id"];
    };
    return $data;	
}
function insertParts($db,$insert,$show,$data,$pricegroup) {
    if ($show) {
        show('<tr>',false);
        show($data["partnumber"]);        show($data["lastcost"]);          show($data["sellprice"]);	show($data["listprice"]);
        show($data["description"]);       show(substr($data["notes"],0,25));show($data["ean"]);
        show($data["weight"]);            show($data["image"]);             show($data["partsgroup_id"]);
        show($data["buchungsgruppen_id"]);show($data["income_accno"]);      show($data["expense_accno"]);
        show($data["inventory_accno"]);   show($data["microfiche"]);        show($data["drawing"]);
        show($data["rop"]);               show($data["assembly"]);          show($data["makemodel"]);
        show($data["shop"]);
    }
    /*foreach ($data as $key=>$val) {
        echo $key.":".gettype($val).":".gettype($data[$key]).":".$val."<br>";
    }*/
    if ($insert) {
        $sqlIa  = 'INSERT INTO parts (';
        $sqlIa .= 'partnumber,description,notes,ean,unit,';
        $sqlIa .= 'weight,image,sellprice,listprice,lastcost,partsgroup_id,';
        $sqlIa .= 'buchungsgruppen_id,income_accno_id,expense_accno_id,inventory_accno_id,';
        $sqlIa .= 'microfiche,drawing,rop,assembly,shop,makemodel,import) ';
        $sqlIa .= 'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)';
        $data["import"]=time();
        $rc=$db->execute($sqlIa,$data);
    } else {
        $rc = true;
    }
    if ($pricegroup) $ok = insPrices($db,$data["partnumber"],$pricegroup);
    if ($show) {
        if ($rc) 
            show('<b>ok</b>');
        else
            show('<font color="red">error</font>');
        show('</tr>'."\n",false);
    }
    return $rc;
}
function updPrice($db,$insert,$show,$partnumber,$lastcost,$sellprice,$listprice,$pricegroup,$shop) {
    if ($show) {
        show('<tr>',false);
        show($partnumber); show($lastcost); show($sellprice); show($listprice);
    }
    if ($insert) {
        $sqlPr  = 'UPDATE PARTS SET ';
        $sqlPr .= 'sellprice = ?, listprice = ?, lastcost = ?, shop = ? ';
        $sqlPr .= 'WHERE  partnumber = ?';
        $rc=$db->execute($sqlPr,array("sellprice"=>$sellprice,"listprice"=>$listprice,"lastcost"=>$lastcost,"shop"=>$shop,"partnumber"=>$partnumber));
    } else {
        $rc = true;
    }
    if ($pricegroup) $ok = insPrices($db,$partnumber,$pricegroup);
    if ($show) {
        if ($rc) 
            show('<b>ok</b>');
        else
            show('<font color="red">error</font>');
        show('</tr>'."\n",false);
    }
    return $rc;
}
function updParts($db,$insert,$show,$partnumber,$lastcost,$sellprice,$listprice,
                    $description,$notes,$ean,$weight,$image,
                    $partsgroup_id,$pricegroup, $shop) {
    if ($show) {
        show('<tr>',false);
        show($partnumber);      show($lastcost);          show($sellprice); 	show($listprice);
        show($description);     show(substr($notes,0,25));show($ean);
        show($weight);          show($image);             show($partsgroup_id);
    }
    if ($insert) {
        $sqlUa  = 'UPDATE PARTS SET ';
        $sqlUa .= 'description = ?, notes = ?, ean = ?, weight = ?, image = ?, ';
        $sqlUa .= 'sellprice = ?, listprice = ?, lastcost = ?, partsgroup_id = ?, shop = ? ';
        $sqlUa .= 'WHERE  partnumber = ?';
        $rc=$db->execute($sqlUa,array($description,$notes,$ean,$weight,$image,
                                $sellprice,$listprice,$lastcost,$partsgroup_id,$shop,$partnumber));
    } else {
        $rc = true;
    }
    if ($pricegroup) $ok = insPrices($db,$partnumber,$pricegroup);
    if ($show) {
        if ($rc) 
            show('<b>ok</b>');
        else
            show('<font color="red">error</font>');
        show('</tr>'."\n",false);
    }
    return $rc;
}

function getMakemodel($db,$check,$hersteller,$model,$partsid,$add=true) {
    $sql="select * from makemodel where make = $hersteller and model = '$model' and parts_id = $partsid";
    $rs=$db->getAll($sql);
    if (empty($rs[0]["id"]) && $add) {
        $sql="insert into makemodel (parts_id,make,model) values ($partsid,'$hersteller','$model')";    
        $rc=$db->query($sql);
    }
}

function getAccnoId($db, $accno) {
    $sql = "select id from chart where accno='$accno'";
    $rs=$db->getAll($sql);
    return $rs[0]["id"];
}

function getPartsid($db,$number) {
    $sql = "select id from parts where partnumber = '$number'";
    $rs=$db->getAll($sql);
    if ($rs[0]["id"]>0) {
        return $rs[0]["id"];
    } else { 
        return false;
    }
}

function newPartNumber($db,$check) {
    if ($check) return "check";
    $rc=$db->query("BEGIN");
    $sql = "select  articlenumber from defaults";
    $rs=$db->getAll($sql);
    if ($rs[0]["articlenumber"]) {
        preg_match("/([^0-9]+)?([0-9]+)([^0-9]+)?/", $rs[0]["articlenumber"] , $regs);
        $number=$regs[1].($regs[2]+1).$regs[3];
    }
    $sql = "update defaults set articlenumber = '$number'";
    $rc=$db->query($sql);
    $rc=$db->query("COMMIT");
    //Prüfen ob die Nummer nicht doch schon vergeben ist.
    $sql = "select * from parts where partnumber = '$number'";
    $rs=$db->getAll($sql);
    if ($rs[0]["id"]>0) return "";
    return $number;
}

function getBuchungsgruppe($db, $income, $expense) {
    $income_id = getAccnoId($db, $income);
    $expense_id = getAccnoId($db, $expense);
    $sql  = "select id from buchungsgruppen where ";
    $sql .= "income_accno_id_0 = $income and ";
    $sql .= "expense_accno_id_0 = $expense ";
    $sql .= "order by sortkey";
    $rs=$db->getAll($sql);
    return $rs[0]["id"];
}

function getFromBG($db, $bg_id, $name) {
    $sql  = "select $name from buchungsgruppen where id='$bg_id'";
    $rs=$db->getAll($sql);
    return 1*$rs[0][$name];
}

function existUnit($db, $value) {
    $sql="select name from units where name = '$value'";
    $rs=$db->getAll($sql);
    if (empty($rs[0]["name"]))
        return FALSE;
    return TRUE;
}

function show($things,$td=true) {
        if ($td) 
            echo '<td>'.$things.'</td>';
        else
            echo $things;
}

function getStdUnit($db,$type) {
    $sql="select * from units where type='$type' order by sortkey limit 1";
    $rs=$db->getAll($sql);
    return $rs[0]["name"];
}

function insPrices($db,$pid,$prices) {
    $rc = $db->query("BEGIN");
    $sql="delete from prices where parts_id = ".$pid;
    $rc = $db->query($sql);
    $sql = "insert into prices (parts_id,pricegroup_id,price) values ((select id from parts where partnumber = '%s'),%d,%0.5f)";
    foreach ($prices as $key => $val) {
	$rc = $db->query(sprintf($sql,$pid,$key,$val));
	if (!$rc) {
	    $db->query("ROLLBACK");
	    return false;
	}
    }
    $db->query("COMMIT");
    return true;
}

function import_parts($db, $file, $trenner, $trennzeichen, $fields, $check, $insert, $show ,$maske) {
    $precision=$maske["precision"];
    $quotation=$maske["quotation"];
    $quottype=$maske["quottype"];
    $shop=$maske["shop"];
    $wgtrenner=$maske["wgtrenner"];
    $Update=($maske["update"]=="U")?true:false;
    $UpdText=($maske["TextUpd"]=="1")?true:false;

    $stdunitW=getStdUnit($db,"dimension");
    $stdunitD=getStdUnit($db,"service");
    if ($quottype=="P") $quotation=($quotation+100)/100;

    if ($show && !$insert) show("<b>Testimport</b>",false);
    if ($show) show("<table border='1'>\n",false);

    /* field description */
    $prices = getPricegroup($db);
    if ($prices) {
        $priceskey = array_keys($prices);
        $parts_fld = array_merge(array_keys($fields),$priceskey);
    } else {
        $parts_fld = array_keys($fields);
    }

    /* open csv file */
    $f=fopen($file.'.csv',"r");
    
    /*
     * read first line with table descriptions
     */
    if ($show) {
        show('<tr>',false);
        show("partnumber"); show("lastcost");   show("sellprice");	show("listprice");
        show("description");show("notes");      show("ean");
        show("weight");     show("image");      show("partsgroup_id");
        show("bg");         show("income_accno"); show("expense_accno");
        show("inventory_accno"); show("microfiche");show("drawing");show("rop");
        show("assembly");show("makemodel");  show("shop"); show("");
        show("</tr>\n",false);
    }

    if ($trenner=="other") $trenner=trim($trennzeichen);
    if (substr($trenner,0,1)=="#") if (strlen($trenner)>1) $trenner=chr(substr($trenner,1));
   
    // Erst einmal die erste Zeile mit den Feldbezeichnungen einlesen. 
    $infld=fgetcsv($f,1200,$trenner);
    $p=0;
    foreach ($infld as $fld) {
        $fld = strtolower(trim(strtr($fld,array("\""=>"","'"=>""))));
        if (in_array($fld,$parts_fld)) {
            $fldpos[$fld]=$p;
        }
        $p++;
    }
    $i=0;
    $u=0;
    $m=0;        /* line */
    $errors=0;    /* number of errors detected */
    $income_accno = "";
    $expense_accno = "";
    $assembly = 'f';

    while ( ($zeile=fgetcsv($f,120000,$trenner)) != FALSE) {
        $m++;    /* increase line */
        $unit=false;
        unset($pgroup); 
        unset($partsgroup_id); 
        unset($notes); 
        unset($rop);
        unset($weight);
        unset($inventory_accno);
        unset($income_accno);
        unset($expense_accno);
        unset($model);
        unset($makemodel);
        unset($hersteller);

        /* VK-Preis bilden */
        $sellprice = str_replace(",", ".", $zeile[$fldpos["sellprice"]]);
        $listprice = str_replace(",", ".", $zeile[$fldpos["listprice"]]);
        $lastcost = str_replace(",", ".", $zeile[$fldpos["lastcost"]]);
        if ($prices) {
	    foreach ($prices as $pkey=>$val) {
		$pricegroup[$val] = str_replace(",", ".", $zeile[$fldpos[$pkey]]);
	    }
	}
        if ($quotation<>0) {
            if ($quottype=="A") { $sellprice += $quotation; }
            else { $sellprice = $sellprice * $quotation; }
        };
        if ($lastcost=="") unset($lastcost);
        if ($sellprice=="") unset($sellprice);
        if ($listprice=="") unset($listprice);

        /* Langtext zusammenbauen */
        if ($zeile[$fldpos["notes"]]) {
            //Kundenspezifisch:
            //$notes = preg_replace('/""[^ ]/','"',$zeile[$fldpos["notes"]]);
            $notes = addslashes($zeile[$fldpos["notes"]]);
            if (Translate) translate($notes);
        }
        if ($zeile[$fldpos["notes1"]]) {
            //Kundenspezifisch:
            //$notes1 = preg_replace('/""[^ ]/','"',$zeile[$fldpos["notes1"]]);
            $notes1 = addslashes($zeile[$fldpos["notes1"]]);
            if (Translate) translate($notes1);
            if ($notes) {
                $notes .= "\n".$notes1;
            } else {
                $notes = $notes1;
            }
        }

        /* Warengruppe bilden */
        if ($fldpos["partsgroup"]>0  and $zeile[$fldpos["partsgroup"]])  $pgroup[]=$zeile[$fldpos["partsgroup"]];
        if ($fldpos["partsgroup1"]>0 and $zeile[$fldpos["partsgroup1"]]) $pgroup[]=$zeile[$fldpos["partsgroup1"]];
        if ($fldpos["partsgroup2"]>0 and $zeile[$fldpos["partsgroup2"]]) $pgroup[]=$zeile[$fldpos["partsgroup2"]];
        if ($fldpos["partsgroup3"]>0 and $zeile[$fldpos["partsgroup3"]]) $pgroup[]=$zeile[$fldpos["partsgroup3"]];
        if ($fldpos["partsgroup4"]>0 and $zeile[$fldpos["partsgroup4"]]) $pgroup[]=$zeile[$fldpos["partsgroup4"]];
        if (count($pgroup)>0) {
                $pgname = implode($wgtrenner,$pgroup);
                if (Translate) translate($pgname);
                $partsgroup_id = getPartsgroupId($db, $pgname, $insert);
        }

        /* sind Hersteller und Modelnummer hinterlegt 
            wenn ja, erfolgt er insert später */
        if (!empty($zeile[$fldpos["makemodel"]]) and !$artikel) { 
            $mm = $zeile[$fldpos["makemodel"]];
            if (Translate) translate($mm);
            $hersteller=suchFirma("vendor",$mm);
            $hersteller=$hersteller["cp_cv_id"];
            if (!empty($zeile[$fldpos["model"]])) {
                $mo = $zeile[$fldpos["model"]];
                if (Translate) translate($mo);
                $model = $mo;
                $makemodel = 't';
            } else { 
                unset($hersteller);
                $makemodel = 'f';
            }
        }

        /* Ware oder Dienstleistung */
        if (($maske["ware"]=="G" and strtoupper($zeile[$fldpos["art"]])=="D") or $maske["ware"]=="D") { 
            $artikel = false; 
        } else if (($maske["ware"]=="G" and strtoupper($zeile[$fldpos["art"]])=="W") or $maske["ware"]=="W") { 
            $artikel = true;
        }

        /* Einheit ermitteln */
        if ($zeile[$fldpos["unit"]]=="") {
            //Keine Einheit mitgegeben
            if ($maske["ware"]=="G") { 
                if ($artikel) {
                    $unit = $stdunitD;
                } else {
                    $unit = $stdunitW; 
                }
            } else if ($maske["ware"]=="D") { $unit = $stdunitD; }
            else { $unit = $stdunitW; };
        } else {
            if (existUnit($db,$zeile[$fldpos["unit"]])) {
                $unit = $zeile[$fldpos["unit"]];
            } else {
                $unit = ($artikel)?$stdunitD:$stdunitW;
            }
        }

        /* Buchungsgruppe ermitteln */
        if ($maske["bugrufix"]==1) {
            $bg = $maske["bugru"];
        } else {
            if ($zeile[$fldpos["income_accno"]]<>"" and $zeile[$fldpos["expense_accno"]]<>"") {
                /* search for buchungsgruppe */
                $bg = getBuchungsgruppe($db, $zeile[$fldpos["income_accno"]],$zeile[$fldpos["expense_accno"]]);
                if ($bg == "" and $maske["bugrufix"]==2 and $maske["bugru"]<>"") {
                    $bg = $maske["bugru"];
                }
            } else if ($maske["bugru"]<>"" and $maske["bugrufix"]==2) {
                $bg = $maske["bugru"];
            } else {
                /* nothing found? user must create one */
                echo "Error in line $m: ";
                echo "Keine Buchungsgruppe gefunden f&uuml;r <br>";
                echo "Erl&ouml;se Inland: ".$zeile[$fldpos["income_accno"]]."<br>";
                echo "Aufwand Inland: ".$zeile[$fldpos["expense_accno"]]."<br>";
                echo "Bitte legen Sie eine an oder geben Sie eine vor.<br>";
                echo "<br>";
                $errors++;
            }
        }
        if ($bg > 0) {
            /* found one, add income_accno_id etc from buchungsgr. */
            /* XXX nur bei artikel!!! */
            if ($artikel) {
                $inventory_accno = getFromBG($db, $bg, "inventory_accno_id");
            };
            $income_accno = getFromBG($db, $bg, "income_accno_id_0");
            $expense_accno = getFromBG($db, $bg, "expense_accno_id_0");
            $bg = $bg * 1;
        } else {
            echo "Error in line $m: ";
            echo "Keine Buchungsgruppe angegeben/gefunden<br>";
            $errors++;
            continue;
        }

        $description = preg_replace('/""[^ ]/','"',$zeile[$fldpos["description"]]);
        $description = addslashes($description);
        if (Translate) translate($description);

        // rop und weight müssen null oder Zahl sein
        if ($zeile[$fldpos["rop"]]) $rop = 1 * str_replace(",", ".",$zeile[$fldpos["rop"]]);
        if ($zeile[$fldpos["weight"]]) $weight = 1 * str_replace(",", ".", $zeile[$fldpos["weight"]]);

        // Shop-Artikel
        if ($zeile[$fldpos["shop"]]) {
                $shop = (strtolower($zeile[$fldpos["shop"]]=='t'))?'t':'f';
        } else {
                $shop = $maske["shop"];
        }
        // Artikel updaten

        if (getPartsid($db,trim($zeile[$fldpos["partnumber"]]))) {
            /* es gibt die Artikelnummer */
            if ($Update) {
                /* Updates durchführen */
                if ($UpdText=='1') {
                    $u += updParts($db,$insert,$show,$zeile[$fldpos["partnumber"]],$lastcost,$sellprice,$listprice,
                    $description,$notes,$zeile[$fldpos["ean"]],$weight,
                    $zeile[$fldpos["image"]],$partsgroup_id,$pricegroup, $shop);
                } else {
                    $u += updPrice($db,$insert,$show,$zeile[$fldpos["partnumber"]],$lastcost,$sellprice,$listprice,$pricegroup,$shop);
                }
                continue;
                // nächste Zeile
            } 
        }

        // Neuen Artikel einfügen

        if ($zeile[$fldpos["partnumber"]] == "") {
            $zeile[$fldpos["partnumber"]] = newPartNumber($db,$check);
            //Keine Artikelnummer bekommen
            if ($zeile[$fldpos["partnumber"]] == "") {
                continue;
            }
        }
        $i += insertParts($db,$insert,$show,array(
                    "partnumber"=>$zeile[$fldpos["partnumber"]],
                    "description"=>$description,"notes"=>$notes,
                    "ean"=>$zeile[$fldpos["ean"]],"unit"=>$unit,
                    "weight"=>$weight,"image"=>$zeile[$fldpos["image"]],
                    "sellprice"=>$sellprice,"lastcost"=>$lastcost,"listprice"=>$listprice,
                    "partsgroup_id"=>$partsgroup_id,
                    "buchungsgruppen_id"=>$bg,"income_accno"=>$income_accno,
                    "expense_accno"=>$expense_accno,"inventory_accno"=>$inventory_accno,
                    "microfiche"=>$zeile[$fldpos["microfiche"]],"drawing"=>$zeile[$fldpos["drawing"]],
                    "rop"=>$rop,"assembly"=>$assembly,
                    "shop"=>$shop,"makemodel"=>$makemodel),$pricegroup
                );
        if ($hersteller>0 && $model) {
            $partsid=getPartsid($db,$zeile[$fldpos["partnumber"]]);
            if ($partsid) {
                getMakemodel($db,$check,$hersteller,$model,$partsid,true);
            }
        }
        unset($zeile);
    }

    if ($show) show("</table>",false);
    fclose($f);
    echo "$m Zeilen bearbeitet. Importiert: $i Update: $u (".($m-$u-$i+$errors)." : Fehler) ";
}
?>
