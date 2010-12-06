<html>
<LINK REL="stylesheet" HREF="../css/lx-office-erp.css" TYPE="text/css" TITLE="Lx-Office stylesheet">
<body>
<?php
/*
Kunden- bzw. Lieferantenimport mit Browser nach Lx-Office ERP

Copyright (C) 2005
Author: Holger Lindemann
Email: hli@lx-system.de
Web: http://lx-system.de

*/

require ("import_lib.php");

if (!$_SESSION["db"]) {
    $conffile="../config/authentication.pl";
    if (!is_file($conffile)) {
        ende("authentication.pl nicht gefunden oder unlesbar");
    }
}

if (!anmelden()) ende("Anmeldung fehlgeschlagen");

if ($_POST["ok"]=="Hilfe") {
    echo "Importfelder:<br>";
    echo "Feldname => Bedeutung<br>";
    foreach($address as $key=>$val) {
        echo "$key => $val<br>";
    }
    $header=implode(";",array_keys($address));
    echo $header;
    exit(0);
};

if ($_POST["ok"]) {

$nun=time();


/* get DB instance */
$db=$_SESSION["db"]; //new myDB($login);

$crm=checkCRM();

function ende($txt) {
    echo "Abbruch: $txt<br>";
    exit(1);
}
$dir = "../users/";
clearstatcache ();
//print_r($_FILES);
$test=$_POST["test"];
if (!empty($_FILES["Datei"]["name"])) {
    $file=$_POST["ziel"];
    if (!move_uploaded_file($_FILES["Datei"]["tmp_name"],$dir.$file.".csv")) {
        $file=false;
        echo "Upload von ".$_FILES["Datei"]["name"]." fehlerhaft. (".$_FILES["Datei"]["error"].")<br>";
    }
} else if (is_file($dir.$_POST["ziel"].".csv")) {
    $file=$_POST["ziel"];
} else {
    $file=false;
}

if (!$file) ende ("Kein Datenfile");

$trenner=($_POST["trenner"])?$_POST["trenner"]:",";
if ($trenner=="other") {
    $trenner=trim($trennzeichen);
} 
if (substr($trenner,0,1)=="#") if (strlen($trenner)>1) $trenner=chr(substr($trenner,1));

if (!file_exists($dir.$file.".csv")) ende("$file.csv nicht im Ordner oder leer");

if (!$db->chkcol($file)) ende("Importspalte kann nicht angelegt werden");

$employee=chkUsr($_SESSION["employee"]);
if (!$employee) ende("Ung&uuml;ltiger User");

$kunde_fld = array_keys($address);

    //Zeichencodierung des Servers
    $tmpcode = $db->getServerCode();
    //Leider sind die Benennungen vom Server anders als von mb_detect_encoding
    if ($tmpcode == "UTF8") {
         define("ServerCode","UTF-8");
    } else if ($tmpcode == "LATIN9") {
         define("ServerCode","ISO-8859-15");
    } else if ($tmpcode == "LATIN1") {
         define("ServerCode","ISO-8859-1");
    } else {
         define("ServerCode",$tmpcode);
    }
    //Zeichensatz sollte gleich sein, sonst ist die Datenkonvertierung nutzlos
    //DB und LxO müssen ja nicht auf der gleichen Maschiene sein.
    if($tmpcode<>$db->getClientCode()) {
        $rc = $db->setClientCode($tmpcode);
    }

    // Zeichenkodierung File
    if ($_POST["encoding"] == "auto") {
         define("Auto",true);
         define("Translate",true);
    } else {
         define("Auto",false);
         if ($_POST["encoding"] == ServerCode) {
            define("Translate",false);
         } else {
            define("Translate",true);
            define("FileCode",$_POST["encoding"]);
         }
    }

function chkBusiness($data,$id=true) {
global $db;
    if ($id) {
        $rs = $db->getAll("select id from business where id =$data");
    } else {
        $rs = $db->getAll("select id from business where decription ilike '$data'");
    }
    if ($rs[0]["id"]) {
        return $rs[0]["id"];
    } else {
        return "null";
    }
}

function chkSalesman($data,$id=true) {
global $db;
    if ($id) {
        $rs = $db->getAll("select id from employee where id =$data");
    } else {
        $rs = $db->getAll("select id from employee where login ilike '$data'");
    }
    if ($rs[0]["id"]) {
        return $rs[0]["id"];
    } else {
        return "null";
    }
}

$f=fopen($dir.$file.".csv","r");
$zeile=fgets($f,1200);
$infld=explode($trenner,strtolower($zeile));
$first=true;
$ok=true;
$p=0;
foreach ($infld as $fld) {
    $fld = strtolower(trim(strtr($fld,array("\""=>"","'"=>""))));
    if (in_array($fld,$kunde_fld)) {
        if ($fld=="branche" && !$crm) {  continue; };
        if ($fld=="sw" && !$crm) {  continue; };
        $in_fld[$fld]=$p;
        //$fldpos[$fld]=$p;
        //$in_fld[]=$fld;
    }
    $p++;
}
$infld = array_keys($in_fld);
$infld[] = "import";
$infld = implode(",",$infld);
$j=0;
$m=0;
$zeile=fgetcsv($f,1200,$trenner);
if ($ok) while (!feof($f)){
    $i=0;
    $m++;
    $anrede="";
    $Matchcode="";
    $sql="insert into $file ";
    $keys=array();
    $vals=array();
    $number=false;
    //foreach($zeile as $data) {
    
    foreach($in_fld as $fld => $pos) {
        switch ($fld) {
            case "name"         :
            case "department_1" :
            case "department_2" :
            case "matchcode"    : 
            case "street"       :
            case "city"         :
            case "notes"        :
            case "sw"           :
            case "branche"      :
            case "country"      :
            case "contact"      :
            case "homepage"     :
            case "email"        :
            case "bank"         : $data = addslashes(trim($zeile[$pos]));
                                  if (Translate) translate($data);
            case "ustid"        : $data = strtr(trim($zeile[$pos])," ","");
            case "bank_code"    : $data = trim($zeile[$pos]);
            case "account_number":
            case "greeting"     :
            case "taxnumber"    :
            case "zipcode"      : 
            case "phone"        :
            case "fax"          : $data = trim($zeile[$pos]);
                                  $data = "'$data'";
                                  if ($data=="''") {
                                        $vals[] = "null";
                                  } else {
                                        $vals[] = $data;
                                  }
                                  break;
            case "business_id"  : $vals[] = chkBusiness(trim($zeile[$pos]));
                                  break;
            case "salesman_id"  : $vals[] = chkSalesman(trim($zeile[$pos]));
                                  break;
            case "taxincluded"  : $data = strtolower(substr($zeile[$pos],0,1));
                                  if ($data!="f" && $data!="t") { $vals[] = "'f'"; }
                                  else { $vals[] = "'".$data."'";}
                                  break;
            case "taxzone_id"   : $data = trim($zeile[$pos])*1;
                                  if ($data>3 && $data<0) $data = 0;
                                  $vals[] = $data;
                                  break;
            case "creditlimit"  : 
            case "discount"     :
            case "terms"        : $vals[] = trim($zeile[$pos])*1;
                                  break;
            case "customernumber":
            case "vendornumber" : $data = trim($zeile[$pos]);
                                  if (empty($data) or !$data) {
                                      $vals[] = getKdId();
                                      $number = true;
                                  } else {
                                      $vals[] = chkKdId($data);
                                      $number = true;
                                  }
                                  break;
        }
    };
    if (!in_array("taxzone_id",$in_fld)) {
        $in_fld[] = "taxzone_id";
        $vals[] = 0;
    }
        // seit 2.6 ist die DB-Kodierung UTF-8 @holger Ansonsten einmal vorher die DB-Encoding auslesen
        // Falls die Daten ISO-kodiert kommen entsprechend wandeln
        // done!
        // UTF-8 MUSS als erstes stehen, da ansonsten die Prüfung bei ISO-8859-1 aufhört ...
        // die blöde mb_detect... tut leider nicht immer, daher die Möglichkeit der Auswahl
        // TODO Umlaute am Anfang wurden bei meinem Test nicht übernommen (Österreich). S.a.:
        // http://forum.de.selfhtml.org/archiv/2007/1/t143904/
    if ($test) {
            if ($first) {
                echo "<table border='1'>\n<tr><td>";
                echo implode('</th><th>',array_keys($in_fld));
                echo "</td></tr>\n";
                $first=false;
            };
            echo "<tr><td>";
            echo implode('</td><td>',$vals);
            echo "</td></tr>\n";
            //echo "Import $j<br>\n";
            flush();
    } else {
            $vals[] = $nun;
            $sql = "INSERT INTO $file (".$infld.") values (".implode(",",$vals).")";
            $rc=$db->query($sql);
            if ($j % 10 == 0) { echo "."; flush(); };
            if (!$rc) {  echo "<br />Fehler: ".$sql."<br />"; flush(); };
    }
    $j++;
    $zeile=fgetcsv($f,1200,$trenner);
}
fclose($f);
if ($test) echo "</table>\n ##### = Neue Kunden-/Lieferantennummer\n<br>";
echo $j." $file importiert.\n";
} else {
?>

<p class="listtop">Adressimport f&uuml;r die ERP<p>
<br>
<form name="import" method="post" enctype="multipart/form-data" action="addressB.php">
<!--form name="import" method="post"  action="addressB.php"-->
<input type="hidden" name="MAX_FILE_SIZE" value="2000000">
<input type="hidden" name="login" value="<?php echo  $login ?>">
<table>
<tr><td></td><td><input type="submit" name="ok" value="Hilfe"></td></tr>
<tr><td>Zieltabelle</td><td><input type="radio" name="ziel" value="customer" checked>customer <input type="radio" name="ziel" value="vendor">vendor</td></tr>
<tr><td>Trennzeichen</td><td>
        <input type="radio" name="trenner" value=";" checked>Semikolon
        <input type="radio" name="trenner" value=",">Komma
        <input type="radio" name="trenner" value="#9" checked>Tabulator
        <input type="radio" name="trenner" value=" ">Leerzeichen
        <input type="radio" name="trenner" value="other">
        <input type="text" size="2" name="trennzeichen" value="">
</td></tr>
<tr><td>Test</td><td><input type="checkbox" name="test" value="1">ja</td></tr>
<tr><td>Daten</td><td><input type="file" name="Datei"></td></tr>
<tr><td>Verwendete<br />Zeichecodierung</td><td>
        <select name="encoding">
        <option value="auto">Automatisch (versuchen)</option>
        <option value="UTF-8">UTF-8</option>
        <option value="ISO-8859-1">ISO-8859-1</option>
        <option value="ISO-8859-15">ISO-8859-15</option>
        <option value="Windows-1252">Windows-1252</option>
        <option value="ASCII">ASCII</option>
        </select>
</td></tr>
<tr><td></td><td><input type="submit" name="ok" value="Import"></td></tr>
</table>
</form>
<?php }; ?>
