<?php session_start(); ?>
<html>
<LINK REL="stylesheet" HREF="../css/lx-office-erp.css" TYPE="text/css" TITLE="Lx-Office stylesheet">
<body>
<?php
/*
Warenimport mit Browser nach Lx-Office ERP
Henry Margies <h.margies@maxina.de>
Holger Lindemann <hli@lx-system.de>
*/

$dir="../users/";
$gz_bin = "/bin/gzip -df ";
$zip_bin = "/usr/bin/unzip -o -d ".$dir;

function ende($txt) {
    echo "Abbruch: $txt<br>";
    exit(1);
}

if (!$_SESSION["db"]) {
    $conffile="../config/lx_office.conf";
    if (!is_file($conffile)) {
        ende("lx_office.conf nicht gefunden oder kein Leserecht.");
    }
}
require ("import_lib.php");

if ($_GET["login"]) {
    $db = anmelden($_GET["login"],$_GET["passwd"]);
} else {
    $db = anmelden();
}
//if (!$_SESSION["db"]) ende("Anmeldung fehlgeschlagen.");
if (!$db) ende("Anmeldung fehlgeschlagen.");

/* get DB instance */
$db=$_SESSION["db"]; //new myDB($login);
/* just display page or do real import? */
if ($_POST["ok"] || $_GET["cron"]=="1") {

    require ("parts_import.php");
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
    //DB und LxO müssen ja nicht auf der gleichen Maschine sein.
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

    /* display help */
    if ($_POST["ok"]=="Hilfe") {
        echo "Importfelder:<br>";
        echo "Feldname => Bedeutung<br>";
        foreach($parts as $key=>$val) {
            echo "$key => $val<br>";
        }
        $header=implode(";",array_keys($parts));
        echo $header;
        echo "<br><br>Die erste Zeile enth&auml;lt die Feldnamen der Daten in ihrer richtigen Reihenfolge<br>";
        echo "Geben Sie das Trennzeichen der Datenspalten ein. Steuerzeichen k&ouml;nnen mit ihrem Dezimalwert ";
        echo "gef&uuml;hrt von einem &quot;#&quot; eingegebn werden (#11).<br><br>";
        echo "Wird bei &quot;Art&quot; in der Maske &quot;gemischt&quot; gew&auml;hlt, muss die Spalte &quot;art&quot; vor der Einheit stehen.<br><br>";
        echo "Der &quot;sellprice&quot; kann um den eingegeben Wert  ge&auml;ndert werden.<br><br>";
        echo "Bei vorhandenen Artikelnummern (in der db), kann entweder ein Update auf den Preis (und Text) durchgef&uuml;hrt werden oder ";
        echo "der Artikel mit anderer Artikelnummer eingef&uuml;gt werden.<br><br>";
        echo "Jeder Artikel mu&szlig; einer Buchungsgruppe zugeordnet werden. ";
        echo "Dazu mu&szlig; entweder in der Maske eine Standardbuchungsgruppe gew&auml;hlt werden <br>";
        echo "oder es wird ein g&uuml;ltiges Konto in 'income_accno_id' und 'expense_accno_id' eingegeben. ";
        echo "Das Programm versucht dann eine passende Buchungsgruppe zu finden.<br>";
	    echo "Preisgruppen müssen zunächst angelegt werden. Die Spalten für die Preisgruppen beginnen mit 'pg_' gefolgt vom Preisgruppenname.<br>";
        echo "Wenn eine Datei <code>users/partshead.csv</code> existiert, wird die erste Zeile aus dieser benutzt um das Format zu bestimmen. Die erste Zeile aus der eigentlichen Importdatei wird dann ignoriert.<br>";
        exit(0);
    };

    clearstatcache ();

    $file    = "parts";

    if ($_GET["cron"]==1) {
        $Cron = True;
        if (file_exists($dir.$file.".zip")) {
             exec ($zip_bin.$dir.$file.".zip");
        } else if (file_exists($dir.$file.".gz")) {
            exec ($gz_bin.$dir.$file.".csv.gz");
        } else if (!file_exists($dir.$file.".csv")) {
            ende($dir.$file.".csv nicht gefunden");
        }
        $_POST["trenner"] = "#9";         // Tabulator
        $_POST["trennzeichen"] = ";";     // Anderes Trennzeichen
        $_POST["dimensionunit"] = "Stck"; // Artikeleinheit
        $_POST["serviceunit"] = "Std";    // Dienstleistungseinheit
        $_POST["bugru"] = "1600";         // Std-Bugru
        $_POST["bugrufix"] = "2";         // Nur wenn keine Passende angegeben
        $_POST["shop"] = "f";             // Shopartikel
        $_POST["show"] = "";              // Kontrollausgabe
        $_POST["test"] = "";              // Testlauf == 1
        $_POST["lager"] = "";             // Nicht  gebraucht
        $_POST["lagerplatz"] = "";
        $_POST["precision"] = "2";        // Runden auf nn Stellen
        $_POST["quotation"] = "";         // Preisaufschlag
        $_POST["quottype"] = "P";         // Prozent?
        $_POST["wgtrenner"] = "!";        // Trennzeichen der Warengruppen
        $_POST["TextUpd"] = "1";          // Textupdate durchführen
        $_POST["update"] = "U";           // Bei vorhandenen Nummer updaten
        $_POST["ware"] = "W";             // Ist ein Artikel
        $_POST["encoding"] = "";
    } else {

        /* no data? */
        if (empty($_FILES["Datei"]["name"]))
            ende ("Kein Datenfile angegeben");

        /* copy file */
        if (substr($_FILES["Datei"]["name"],-2)=="gz") {
            if (move_uploaded_file($_FILES["Datei"]["tmp_name"],$dir.$file.".csv.gz")) {
                echo $gz_bin.$dir.$file.".csv.gz";
                exec ($gz_bin.$dir.$file.".csv.gz");
            } else {
                ende ("Upload von Datei fehlerhaft.".$_FILES["Datei"]["error"]);
            };
        } else if (substr($_FILES["Datei"]["name"],-3)=="zip") {
            if (move_uploaded_file($_FILES["Datei"]["tmp_name"],$dir.$file.".zip")) {
                exec ($zip_bin.$dir.$file.".zip");
            } else {
                ende ("Upload von Datei fehlerhaft.".$_FILES["Datei"]["error"]);
            };
        } else if (!move_uploaded_file($_FILES["Datei"]["tmp_name"],$dir.$file.".csv")) {
            ende ("Upload von Datei fehlerhaft.".$_FILES["Datei"]["error"]);
        };
    }

    /* check if file is really there */
    if (!file_exists($dir.$file.'.csv') or filesize($dir.$file.'.csv')==0)
        ende("Datenfile ($file.csv) nicht im Ordner gefunden oder leer");

    /* Zu diesem Zeitpunkt wurde der Artikel Importiert */
    if (!$db->chkcol($file))
        ende("Importspalte konnte nicht angelegt werden");

    /* just print data or insert it, if test is false */
    import_parts($_SESSION["db"], $dir.$file, $parts, FALSE, $_POST);

} else {
    $bugrus=getAllBG($db);
    $serviceunit=getAllUnits($db,"service");
    $dimensionunit=getAllUnits($db,"dimension");
?>

<p class="listtop">Artikelimport f&uuml;r die ERP<p>
<br>
<form name="import" method="post" enctype="multipart/form-data" action="partsB.php">
<input type="hidden" name="MAX_FILE_SIZE" value="20000000">
<input type="hidden" name="login" value="<?php echo  $login ?>">
<table>
<tr><td><input type="submit" name="ok" value="Hilfe"></td><td></td></tr>
<tr><td>Trennzeichen</td><td>
        <input type="radio" name="trenner" value=";" checked>Semikolon
        <input type="radio" name="trenner" value=",">Komma
        <input type="radio" name="trenner" value="#9" checked>Tabulator
        <input type="radio" name="trenner" value=" ">Leerzeichen
        <input type="radio" name="trenner" value="other">
        <input type="text" size="2" name="trennzeichen" value="">
</td></tr>
<tr><td>VK-Preis<br>Nachkomma:</td><td><input type="Radio" name="precision" value="0">0
            <input type="Radio" name="precision" value="1">1
            <input type="Radio" name="precision" value="2" checked>2
            <input type="Radio" name="precision" value="3">3
            <input type="Radio" name="precision" value="4">4
            <input type="Radio" name="precision" value="5">5
    </td></tr>
<tr><td>VK-Preis<br>Aufschlag:</td><td><input type="text" name="quotation" size="5" value="0">
            <input type="radio" name="quottype" value="P" checked>%
            <input type="radio" name="quottype" value="A">Absolut</td></tr>
<tr><td>Vorhandene<br>Artikelnummer:</td><td><input type="radio" name="update" value="U" checked>Preis update durchf&uuml;hren<br>
                    <input type="radio" name="update" value="I">mit neuer Nummer einf&uuml;gen</td></tr>
<tr><td>Kontollausgabe</td><td><input type="checkbox" name="show" value="1" checked>ja</td></tr>
<tr><td>Test</td><td><input type="checkbox" name="test" value="1">ja</td></tr>
<tr><td>Textupdate</td><td><input type="checkbox" name="TextUpd" value="1">ja</td></tr>
<tr><td>Warengruppen<br>verbinder</td><td><input type="text" name="wgtrenner" value="!" size="3"></td></tr>
<tr><td>Shopartikel<br />falls nicht &uuml;bergeben</td><td><input type="radio" name="shop" value="t">ja <input type="radio" name="shop" value="f" checked>nein</td></tr>
<tr><td>Eintrag in<br />Makemodel ist</td><td><input type="radio" name="vendnr" value="t">Lieferantennummer <input type="radio" name="vendnr" value="f" checked>Lieferantenname</td></tr>
<tr><td>auch ohne<br />Model-Nr.</td><td><input type="radio" name="modnr" value="t">ja <input type="radio" name="modnr" value="f" checked>nein</td></tr>
<tr><td>Art</td><td><input type="Radio" name="ware" value="W" checked>Ware &nbsp; 
            <input type="Radio" name="ware" value="D">Dienstleistung
            <input type="Radio" name="ware" value="G">gemischt (Spalte 'art' vorhanden)</td></tr>
<tr><td>Default Einheiten<br></td><td><select name="dimensionunit">
<?php    if ($dimensionunit) foreach ($dimensionunit as $u) { ?>
            <option value="<?php echo  $u["name"] ?>"><?php echo  $u["name"]."\n" ?>
<?php    } ?>
    </select><select name="serviceunit">
<?php    if ($serviceunit) foreach ($serviceunit as $u) { ?>
            <option value="<?php echo  $u["name"] ?>"><?php echo  $u["name"]."\n" ?>
<?php    } ?>
</select>
</td></tr>
<tr><td>Default Bugru<br></td><td><select name="bugru">
<?php    if ($bugrus) foreach ($bugrus as $bg) { ?>
            <option value="<?php echo  $bg["id"] ?>"><?php echo  $bg["description"]."\n" ?>
<?php    } ?>
    </select>
    <input type="radio" name="bugrufix" value="1" >f&uuml;r alle Artikel verwenden
    <input type="radio" name="bugrufix" value="2" checked>f&uuml;r Artikel ohne passende Bugru
    </td></tr>
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
