<?php
/*
Funktionsbibliothek für den Datenimport in Lx-Office ERP

Copyright (C) 2005
Author: Holger Lindemann
Email: hli@lx-system.de
Web: http://lx-system.de

*/

require_once "db.php";

$address = array(
    "name" => "Firmenname",
    "department_1" => "Abteilung",
    "department_2" => "Abteilung",
    "street" => "Strasse + Nr",
    "zipcode" => "Plz",
    "city" => "Ort",
    "country" => "Land",
    "contact" => "Ansprechpartner",
    "phone" => "Telefon",
    "fax" => "Fax",
    "homepage" => "Homepage",
    "email" => "eMail",
    "notes" => "Bemerkungen",
    "discount" => "Rabatt (nn.nn)",
    "taxincluded" => "incl. Steuer? (t/f)",
    "terms" => "Zahlungsziel (Tage)",
    "customernumber" => "Kundennummer",
    "vendornumber" => "Lieferantennummer",
    "taxnumber" => "Steuernummer",
    "ustid" => "Umsatzsteuer-ID",
    "account_number" => "Kontonummer",
    "bank_code" => "Bankleitzahl",
    "bank" => "Bankname",
    "branche" => "Branche",
    //"language" => "Sprache (de,en,fr)",
    "sw" => "Stichwort",
    "creditlimit" => "Kreditlimit (nnnnnn.nn)"); /*,
    "hierarchie" => "Hierarchie",
    "potenzial" => "Potenzial",
    "ar" => "Debitorenkonto",
    "ap" => "Kreditorenkonto",
    "matchcode" => "Matchcode",
    "customernumber2" => "Kundennummer 2"); 
    Kundenspezifisch */
        
$shiptos = array(
    "firma" => "Firmenname",
    "shiptoname" => "Liefername",
    "shiptodepartment_1" => "Abteilung",
    "shiptodepartment_2" => "Abteilung",
    "shiptostreet" => "Strasse + Nr",
    "shiptozipcode" => "Plz",
    "shiptocity" => "Ort",
    "shiptocountry" => "Land",
    "shiptocontact" => "Ansprechpartner",
    "shiptophone" => "Telefon",
    "shiptofax" => "Fax",
    "shiptoemail" => "eMail",
    "customernumber" => "Kundennummer",
    "vendornumber" => "Lieferantennummer");

$parts = array( 
    "partnumber" => "Artikelnummer",
    "ean" => "Barcode",
    "description" => "Artikeltext",
    "unit" => "Einheit",
    "weight" => "Gewicht in Benutzerdefinition",
    "notes" => "Beschreibung",
    "notes1" => "Beschreibung",
    "formel" => "Formel",
    "makemodel" => "Hersteller",
    "model" => "Modellbezeichnung",
    "image" => "Pfad/Dateiname",
    "drawing" => "Pfad/Dateiname",
    "microfiche" => "Pfad/Dateiname",
    "listprice" => "Listenpreis",
    "sellprice" => "Verkaufspreis",
    "lastcost" => "letzter EK",
    "art" => "Ware/Dienstleistung (*/d), mu&szlig; vor den Konten kommen",
    "inventory_accno" => "Bestandskonto",
    "income_accno" => "Erl&ouml;skonto",
    "expense_accno" => "Konto Umsatzkosten",
    "obsolete" => "Gesperrt (Y/N)",
    "lastcost" => "letzer EK-Preis",
    "rop" => "Mindestbestand",
    "shop" => "Shopartikel (Y/N)",
    "assembly" => "St&uuml;ckliste (Y/N); wird noch nicht unterst&uuml;tzt",
    "partsgroup" => "Warengruppenbezeichnung",
    "partsgroup1" => "2.Warengruppenbezeichnung",
    "partsgroup2" => "3.Warengruppenbezeichnung",
    "partsgroup3" => "4.Warengruppenbezeichnung",
    "partsgroup4" => "5.Warengruppenbezeichnung",
    "shop"  => "Shopexport vorghesehen",
    );
    
$contactscrm = array(
    "customernumber" => "Kundennummer",
    "vendornumber" => "Lieferantennummer",
    "cp_cv_id" => "FirmenID in der db",
    "firma" => "Firmenname",
    "cp_abteilung" => "Abteilung",
    "cp_position" => "Position/Hierarchie",
    "cp_gender" => "Geschlecht (m/f)",
    "cp_title" => "Titel",
    "cp_givenname" => "Vorname",
    "cp_name" => "Nachname",
    "cp_email" => "eMail",
    "cp_phone1" => "Telefon 1",
    "cp_phone2" => "Telefon 2",
    "cp_mobile1" => "Mobiltelefon 1",
    "cp_mobile2" => "Mobiltelefon 2",
    "cp_homepage" => "Homepage",
    "cp_street" => "Strasse",
    "cp_country" => "Land",
    "cp_zipcode" => "PLZ",
    "cp_city" => "Ort",
    "cp_privatphone" => "Privattelefon",
    "cp_privatemail" => "private eMail",
    "cp_notes" => "Bemerkungen",
    "cp_stichwort1" => "Stichwort(e)",
    "cp_id" => "Kontakt ID"
    );

$contacts = array(
    "customernumber" => "Kundennummer",
    "vendornumber" => "Lieferantennummer",
    "cp_cv_id" => "FirmenID in der db",
    "firma" => "Firmenname",
    "cp_greeting" => "Anrede",
    "cp_title" => "Titel",
    "cp_givenname" => "Vorname",
    "cp_greeting" => "Anrede",
    "cp_name" => "Nachname",
    "cp_email" => "eMail",
    "cp_phone1" => "Telefon 1",
    "cp_phone2" => "Telefon 2",
    "cp_mobile1" => "Mobiltelefon 1",
    "cp_mobile2" => "Mobiltelefon 2",
    "cp_privatphone" => "Privattelefon",
    "cp_privatemail" => "private eMail",
    "cp_homepage" => "Homepage",
    "cp_id" => "Kontakt ID"
    );

function checkCRM() {
    global $db;
    $sql="select * from crm";
    $rs=$db->getAll($sql);
    if ($rs) {
        return true;
    } else {
        return false;
    }
}

function chkUsr($usr) {
// ist es ein gültiger ERP-Benutzer? Er muß mindestens 1 x angemeldet gewesen sein.
    global $db;
    $sql="select * from employee where login = '$usr'";
    $rs=$db->getAll($sql);
    if ($rs[0]["id"]) { return $rs[0]["id"]; } 
    else { return false; };
}

function getKdId() {
// die nächste freie Kunden-/Lieferantennummer holen
    global $db,$file,$test;
    if ($test) { return "#####"; }
    $sql1="select * from defaults";
    $sql2="update defaults set ".$file."number = '%s'";
    $db->begin();
    $rs=$db->getAll($sql1);
    $nr=$rs[0][$file."number"];
    preg_match("/^([^0-9]*)([0-9]+)/",$nr,$hits);
    if ($hits[2]) { $nr=$hits[2]+1; $nnr=$hits[1].$nr; }
    else { $nr=$hits[1]+1; $nnr=$nr; };
    $rc=$db->query(sprintf($sql2,$nnr));
    if ($rc) { 
        $db->commit(); 
        return $nnr;
    } else { 
        $db->rollback(); 
        return false;
    };
}

function chkKdId($data) {
// gibt es die Nummer schon?
    global $db,$file,$test;
    $sql="select * from $file where ".$file."number = '$data'";
    $rs=$db->getAll($sql);
    if ($rs[0][$file."number"]==$data) {
        // ja, eine neue holen
        return getKdId();
    } else {
        return $data;
    }
}

function chkContact($id) {
    global $db;
    $sql="select * from contact where cp_id = $id";
    $rs=$db->getAll($sql);
    if ($rs[0]["cp_id"]==$id) {
        return true;
    } else {
        return false;
    }
}

function getKdRefId($data) {
// gibt es die Nummer schon?
    global $db,$file,$test;
    if (empty($data) or !$data) {   
        return false; 
    } 
    $sql="select * from $file where ".$file."number = '$data'";
    $rs=$db->getAll($sql);
    return $rs[0]["id"];
}

function suchFirma($tab,$data) {
// gibt die Firma ?
    global $db;
    if (empty($data) or !$data) {   
        return false; 
    }
    $data=strtoupper($data);
    $sql="select * from $tab where upper(name) like '%$data%'";
    $rs=$db->getAll($sql);
    if (!$rs) {
        $org=$data;
        while(strpos($data,"  ")>0) {
            $data=ereg_replace("  "," ",$data);
        }
         $data=preg_replace("/[^A-Z0-9]/ ",".*",trim($data));
        $sql="select * from $tab where upper(name) ~ '$data'"; 
        $rs=$db->getAll($sql);
        if (count($rs)==1) {
            return array("cp_cv_id"=>$rs[0]["id"],"Firma"=>$rs[0]["name"]);
        }
        return false;
    } else {
        return array("cp_cv_id"=>$rs[0]["id"],"Firma"=>$rs[0]["name"]);
    }
}


//Suche Nach Kunden-/Lieferantenummer
function getFirma($nummer,$tabelle) {
    global $db;
    $nummer=strtoupper($nummer);
    $sql="select id from $tabelle where upper(".$tabelle."number) = '$nummer'";
    $rs=$db->getAll($sql);
    if (!$rs) {
        $nr=ereg_replace(" ","%",$nummer);
        $sql="select id,".$tabelle."number from $tabelle where upper(".$tabelle."number) like '$nr'";
        $rs=$db->getAll($sql);
        if ($rs) {
            $nr=ereg_replace(" ","",$nummer);
            foreach ($rs as $row) {
                $tmp=ereg_replace(" ","",$row[$tabelle."number"]);
                if ($tmp==$nr) return $row["id"];
            }
        } else { 
            return false;
        }
    } else {
        return $rs[0]["id"];
    }
}

function getAllBG($db) {
    $sql  = "select * from buchungsgruppen order by description";
    $rs=$db->getAll($sql);
    return $rs;
}
function getAllUnits($db,$type) {
    $sql  = "select * from units where type = '$type' order by sortkey";
    $rs=$db->getAll($sql);
    return $rs;
}

function anmelden() {
    ini_set("gc_maxlifetime","3600");
    $tmp = @file_get_contents("../config/authentication.pl");
    preg_match("/'db'[ ]*=> '(.+)'/",$tmp,$hits);
    $dbname=$hits[1];
    preg_match("/'password'[ ]*=> '(.+)'/",$tmp,$hits);
    $dbpasswd=$hits[1];
    preg_match("/'user'[ ]*=> '(.+)'/",$tmp,$hits);
    $dbuser=$hits[1];
    preg_match("/'host'[ ]*=> '(.+)'/",$tmp,$hits);
    $dbhost=($hits[1])?$hits[1]:"localhost";
    preg_match("/'port'[ ]*=> '?(.+)'?/",$tmp,$hits);
    $dbport=($hits[1])?$hits[1]:"5432";
    preg_match("/[ ]*\\\$self->\{cookie_name\}[ ]*=[ ]*'(.+)'/",$tmp,$hits);
    $cookiename=$hits[1];
    if (!$cookiename) $cookiename='lx_office_erp_session_id';
    $cookie=$_COOKIE[$cookiename];
    if (!$cookie) header("location: ups.html");
    $auth=authuser($dbhost,$dbport,$dbuser,$dbpasswd,$dbname,$cookie);
    if (!$auth) { return false; };
    $_SESSION["sessid"]=$cookie;
    $_SESSION["cookie"]=$cookiename;
    $_SESSION["employee"]=$auth["login"];
    $_SESSION["mansel"]=$auth["dbname"];
    $_SESSION["dbname"]=$auth["dbname"];
    $_SESSION["dbhost"]=(!$auth["dbhost"])?"localhost":$auth["dbhost"];
    $_SESSION["dbport"]=(!$auth["dbport"])?"5432":$auth["dbport"];
    $_SESSION["dbuser"]=$auth["dbuser"];
    $_SESSION["dbpasswd"]=$auth["dbpasswd"];
    $_SESSION["db"]=new myDB($_SESSION["dbhost"],$_SESSION["dbuser"],$_SESSION["dbpasswd"],$_SESSION["dbname"],$_SESSION["dbport"],$showErr);
    $_SESSION["authcookie"]=$authcookie;
    $sql="select * from employee where login='".$auth["login"]."'";
    $rs=$_SESSION["db"]->getAll($sql);
    if(!$rs) {
            return false;
    } else {
        if ($rs) {
            $tmp=$rs[0];
            $_SESSION["termbegin"]=(($tmp["termbegin"]>=0)?$tmp["termbegin"]:8);
            $_SESSION["termend"]=($tmp["termend"])?$tmp["termend"]:19;
            $_SESSION["Pre"]=$tmp["pre"];
            $_SESSION["interv"]=($tmp["interv"]>0)?$tmp["interv"]:60;
            $_SESSION["loginCRM"]=$tmp["id"];
            $_SESSION["lang"]=$tmp["countrycode"]; //"de";
            $_SESSION["kdview"]=$tmp["kdview"];
            $sql="select * from defaults";
            $rs=$_SESSION["db"]->getAll($sql);
            $_SESSION["ERPver"]=$rs[0]["version"];
            return true;
        } else {
            return false;
        }
    }
}

function authuser($dbhost,$dbport,$dbuser,$dbpasswd,$dbname,$cookie) {
    $db=new myDB($dbhost,$dbuser,$dbpasswd,$dbname,$dbport,true);
    $sql="select sc.session_id,u.id from auth.session_content sc left join auth.user u on ";
    $sql.="u.login=sc.sess_value left join auth.session s on s.id=sc.session_id ";
    $sql.="where session_id = '$cookie' and sc.sess_key='login'";// order by s.mtime desc";
    $rs=$db->getAll($sql,"authuser_1");
    if (!$rs) return false;
    $stmp="";
    if (count($rs)>1) {
        header("location:../login.pl?action=logout");
        /*foreach($rs as $row) {
                $stmp.=$row["session_id"].",";
        }
        $sql1="delete from session where id in (".substr($stmp,-1).")";
        $sql2="delete from session_content where session_id in (".substr($stmp,-1).")";
        $db->query($sql1,"authuser_A");
        $db->query($sql2,"authuser_B");
        $sql3="insert into session ";*/
    }
    $sql="select * from auth.user where id=".$rs[0]["id"];
    $rs1=$db->getAll($sql,"authuser_1");
    if (!$rs1) return false;
    $auth=array();
    $auth["login"]=$rs1[0]["login"];
    $sql="select * from auth.user_config where user_id=".$rs[0]["id"];
    $rs1=$db->getAll($sql,"authuser_2");
    $keys=array("dbname","dbpasswd","dbhost","dbport","dbuser");
    foreach ($rs1 as $row) {
        if (in_array($row["cfg_key"],$keys)) {
                $auth[$row["cfg_key"]]=$row["cfg_value"];
        }
    }
    $sql="update auth.session set mtime = '".date("Y-M-d H:i:s.100001")."' where id = '".$rs[0]["session_id"]."'";
    $db->query($sql,"authuser_3");
    return $auth;
}
/**
 * Zeichencode übersetzen
 *
 * @param String $txt
 */
function translate(&$txt) {
    if (Auto) {
        $encoding = mb_detect_encoding($data,"UTF-8,ISO-8859-1,ISO-8859-15,Windows-1252,ASCII");
        $txt = iconv("$encoding",ServerCode."//TRANSLIT",$txt);
        //$txt = mb_convert_encoding($txt, ServerCode,"$encoding");
    } else {
        $txt = iconv(FileCode,ServerCode."//TRANSLIT",$txt);
        //$txt = mb_convert_encoding($txt, ServerCode,FileCode);
    }
}

?>
