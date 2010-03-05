<html>
<LINK REL="stylesheet" HREF="../css/lx-office-erp.css" TYPE="text/css" TITLE="Lx-Office stylesheet">
<body>
<?
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
    if (substr($trenner,0,1)=="#") if (strlen($trenner)>1) $trenner=chr(substr($trenner,1));
} 

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

$f=fopen($dir.$file.".csv","r");
$zeile=fgets($f,1200);
$infld=split($trenner,strtolower($zeile));
$first=true;
$ok=true;
foreach ($infld as $fld) {
    $fld = strtolower(trim(strtr($fld,array("\""=>"","'"=>""))));
    if ($fld=="branche" && !$crm) { $in_fld[]=""; continue; };
    if ($fld=="sw" && !$crm) { $in_fld[]=""; continue; };
    $in_fld[]=$fld;
}

$j=0;
$m=0;
$zeile=fgetcsv($f,1200,$trenner);
if ($ok) while (!feof($f)){
    $i=0;
    $m++;
    $anrede="";
    $Matchcode="";
    $sql="insert into $file ";
    $keys="(";
    $vals=" values (";
    $number=false;
    foreach($zeile as $data) {
        if (!in_array(trim($in_fld[$i]),$kunde_fld)) {
            if ($in_fld[$i]=="anrede") {  $anrede=addslashes(trim($data)); }
            $i++;
            continue;
        };
        $data=trim($data);
        // seit 2.6 ist die DB-Kodierung UTF-8 @holger Ansonsten einmal vorher die DB-Encoding auslesen
        // Falls die Daten ISO-kodiert kommen entsprechend wandeln
        // done!
        // UTF-8 MUSS als erstes stehen, da ansonsten die Prüfung bei ISO-8859-1 aufhört ...
        // die blöde mb_detect... tut leider nicht immer, daher die Möglichkeit der Auswahl
        // TODO Umlaute am Anfang wurden bei meinem Test nicht übernommen (Österreich). S.a.:
        // http://forum.de.selfhtml.org/archiv/2007/1/t143904/

        if (Translate) translate($data);

        //$data=htmlentities($data);
        $data=addslashes($data);
        if ($in_fld[$i]==$file."number") {  // customernumber || vendornumber
            if (empty($data) or !$data) {
                $data=getKdId();
                $number=true;
            } else {
                $data=chkKdId($data);
                $number=true;
            }
        } else if ($in_fld[$i]=="taxincluded"){
            $data=strtolower(substr($data,0,1));
            if ($data!="f" && $data!="t") $data="f";
        } else if ($in_fld[$i]=="ustid"){
            $data=strtr($data," ","");
        } /*else if ($in_fld[$i]=="matchcode") {
                  $matchcode=$data;
                  $i++;
                  continue;
                if ($data==false or empty($data) or !$data) {
            if (in_array($in_fld[$i],array("name"))) {
                $data=$matchcode;
            }
        }
            }*/

        $keys.=$in_fld[$i].",";
        if ($data==false or empty($data) or !$data) {
            $vals.="null,";
        } else {
            if ($in_fld[$i]=="contact"){
                if ($anrede) {
                    $vals.="'$anrede $data',";
                } else {
                    $vals.="'$data',";
                }
            } else {
                $vals.="'".$data."',";
            }
        }
        $i++;
    }
    if (!$number) {
        $keys.=$file."number,";
        $vals.="'".getKdId()."',";
    }
    if ($keys<>"(") {
        if ($test) {
            if ($first) {
                echo "<table border='1'>\n";
                echo "<tr><th>".str_replace(",","</th><th>",substr($keys,1,-1))."</th></tr>\n";
                $first=false;
            };
            $vals=str_replace("',","'</td><td>",substr($vals,9,-1));
            echo "<tr><td>".str_replace("null,","null</td><td>",$vals)."</td></tr>\n";
            //echo "Import $j<br>\n";
            flush();
        } else {
            $sql.=$keys."taxzone_id,import)";
            $sql.=$vals."0,$nun)";
            $rc=$db->query($sql);
            if (!$rc) echo "Fehler: ".$sql."<br>";
        }
        $j++;
    } else {
          $vals=str_replace("',","'</td><td>",substr($vals,9,-1));
          echo "<tr><td style=\"color:red\">".str_replace("null,","null</td><td style=\"color:red\">",$vals)."</td></tr>\n";
          flush();
        }
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
<input type="hidden" name="login" value="<?= $login ?>">
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
<? }; ?>
