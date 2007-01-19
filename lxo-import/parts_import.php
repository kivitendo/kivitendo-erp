<?
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

function getAccnoId($db, $accno) {
	$sql = "select id from chart where accno='$accno'";
	$rs=$db->getAll($sql);
	return $rs[0]["id"];
}

function chkPartNumber($db,$number,$check) {
	if ($number<>"") {
		$sql = "select * from parts where partnumber = '$number'";
		$rs=$db->getAll($sql);
	}
	//echo $sql; print_r($rs);
	if ($rs[0]["id"]>0 or $number=="") {
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
		$sql = "select * from parts where partnumber = '$number'";
		$rs=$db->getAll($sql);
		if ($rs[0]["id"]>0) return "";
	}
	return $number;
}

function getBuchungsgruppe($db, $income, $expense) {

	$income_id = getAccnoId($db, $income);
	$expense_id = getAccnoId($db, $expense);
	//$accno0_id = getAccnoId($db, $accno0);
	//$accno1_id = getAccnoId($db, $accno1);
	//$accno3_id = getAccnoId($db, $accno3);

	$sql  = "select id from buchungsgruppen where ";
	$sql .= "income_accno_id_0 = $income_id and ";
	$sql .= "expense_accno_id_0 = $expense_id ";
	//$sql .= "income_accno_id_0 = '$accno0_id' ";
	//$sql .= "and income_accno_id_1 = '$accno1_id' ";
	//$sql .= "and income_accno_id_3 = '$accno3_id'";
	$rs=$db->getAll($sql);
	return $rs[0]["id"];
}


function getFromBG($db, $bg_id, $name) {
	
	$sql  = "select $name from buchungsgruppen where id='$bg_id'";
	$rs=$db->getAll($sql);
	return $rs[0][$name];
}

function existUnit($db, $value) {
	$sql="select name from units where name = '$value'";
	$rs=$db->getAll($sql);
	if (empty($rs[0]["name"]))
		return FALSE;
	return TRUE;
}

function show($show, $things) {
	if ($show)
		echo $things;
}

function import_parts($db, $file, $trenner, $fields, $check, $insert, $show,$maske) {

	/* field description */
	$parts_fld = array_keys($fields);

	/* open csv file */
	$f=fopen("$file.csv","r");
	
	/*
	 * read first line with table descriptions
	 */
	show( $show, "<table border='1'><tr><td>#</td>\n");
	$infld=fgetcsv($f,1200,$trenner);
	foreach ($infld as $fld) {
		$fld = strtolower(trim(strtr($fld,array("\""=>"","'"=>""))));
		$in_fld[]=$fld;
		if (in_array(trim($fld),$parts_fld)) {
			show( $show, "<td>$fld</td>\n");
		}
	}

	$m=0;		/* line */
	$errors=0;	/* number of errors detected */
	$income_accno = "";
	$expense_accno = "";
	while ( ($zeile=fgetcsv($f,1200,$trenner)) != FALSE) {
		$i=0;	/* column */
	        $m++;	/* increase line */

		$sql="insert into $file ";
		$keys="(";
		$vals=" values (";

		show( $show, "<tr><td>$m</td>\n");

		/* for each column */
		$dienstleistung=false;
		$artikel=-1;
		$partNr=false;
		foreach($zeile as $data) {
			/* check if column will be imported */
			if (!in_array(trim($in_fld[$i]),$parts_fld)) {
				$i++;
				continue;
			};
			$data=trim($data);
			//$data=addslashes($data);
			$key=$in_fld[$i];
			/* add key and data */
			if ($data==false or empty($data) or !$data) {
				show( $show, "<td>NULL</td>\n");
				$i++;
				continue;
			}

			/* special case partsgroup */
			if ($key == "partsgroup") {

				/* get ID of partsgroup or add new 
				 * partsgroup_id */
				$data = getPartsgroupId($db, $data, $insert);
				$key  = "partsgroup_id";

				/* TODO error handling */

			} else if ($key == "lastcost" || 
				   $key == "sellprice") {
				
				/* convert 0,0 numeric into 0.0 */
				$data = str_replace(",", ".", $data);

			} else if ($key == "partnumber") {
				$partNr=true;
				$partnumber=chkPartNumber($db,$data,$check);
				if ($partnumber=="") {
					show( $show, "<td>NULL</td>\n");
					$i++;
					continue;
				} else {
					//$keys.="partnumber, ";
					$data=$partnumber;
					//show( $show, "<td>$partnumber</td>\n");
				}
			} else if ($key == "description") {
				$data=mb_convert_encoding($data,"ISO-8859-15","auto");
				$data=addslashes($data);
			} else if ($key == "notes") {
				$data=mb_convert_encoding($data,"ISO-8859-15","auto");
				$data=addslashes($data);
			} else if ($key == "unit") {
				/* convert stück and Stunde */
				if (preg_match("/^st..?ck$/i", $data))
					$data = "Stck";
				else if ($data == "Stunde")
					$data = "Std";
				/* check if unit exists */
				if (!existUnit($db, $data)) {
					echo "Error in line $m: ";
					echo "Einheit <b>$data</b> existiert nicht ";
					echo "Bitte legen Sie diese Einheit an<br>";
					$errors++;
				}
			} else if ($key == "art") {
				if ($maske["ware"]=="G" and strtoupper($data)=="D") { $artikel=false; }
				else if ($maske["ware"]=="G") { $artikel=true; };
				$i++;
				continue;
			} else if ($key == "income_accno") {
				$income_accno = $data;
				$i++;
				show( $show, "<td>$data</td>\n");
				continue;
			} else if ($key == "expense_accno") {
				$expense_accno = $data;
				$i++;
				show( $show, "<td>$data</td>\n");
				continue;
			}
			/* convert JA to Yes */
			if ($data == "J" )
				$data = "Y";

			$vals.="'".$data."',";
			show( $show, "<td>$data</td>\n");
			$keys.=$key.",";
	
			$i++;
		}
		if ($artikel==-1) {
			if ($maske["ware"]=="D") {  $artikel=false; }
			else { $artikel=true; };			
		}		
		if ($maske["bugrufix"]==1) {
			$bg = $maske["bugru"];
		} else {
			if ($income_accno<>"" and $expense_accno<>"") {
				/* search for buchungsgruppe */
				$bg = getBuchungsgruppe($db, $income_accno, $expense_accno);
				if ($bg == "" and $maske["bugrufix"]==2 and $maske["bugru"]<>"") {
					$bg = $maske["bugru"];
				}
			} else if ($maske["bugru"]<>"" and $maske["bugrufix"]==2) {
				$bg = $maske["bugru"];
			} else {
				/* nothing found? user must create one */
				echo "Error in line $m: ";
				echo "Keine Buchungsgruppe gefunden für <br>";
				echo "Erlöse Inland: $income_accno<br>";
				echo "Bitte legen Sie eine an oder geben Sie eine vor.<br>";
				echo "<br>";
				$errors++;
			}
		}
		if ($bg > 0) {
			/* found one, add income_accno_id etc from buchungsgr.
			 */
			$keys.="buchungsgruppen_id, ";
			$vals.="'$bg', ";
			/* XXX nur bei artikel!!! */
			if ($artikel) {
				$keys.="inventory_accno_id, ";
				$vals.=getFromBG($db, $bg, "inventory_accno_id")." ,";
			};
			$keys.="income_accno_id, ";
			$vals.=getFromBG($db, $bg, "income_accno_id_0")." ,";
			$keys.="expense_accno_id,";
			$vals.=getFromBG($db, $bg, "expense_accno_id_0")." ,";
		}
		if ($partNr==false) {
			$partnumber=chkPartNumber($db,"",$check);
			if ($partnumber=="") {
				show( $show, "<td>NULL</td>\n");
				$errors++;
			} else {
				$keys.="partnumber, ";
				$vals.="'$partnumber',";
				show( $show, "<td>$partnumber</td>\n");
			}
		} 
		$sql.=$keys."import)";
		$sql.=$vals.time().")";		
		//show( $show, "<td> $sql </td>\n");

		if ($insert) {
			show( $show, "<td>");
			$db->showErr = TRUE;
			$rc=$db->query($sql);
			if (!$rc) {
				echo "Fehler";
				$fehler++;
			}
			show( $show, "</td>\n");
		}

		show( $show, "</tr>\n");
	}

	show( $show, "</table>\n");
	fclose($f);
	echo "$m Zeilen bearbeitet. ($fehler : Fehler) ";
	return $errors;
}

?>

