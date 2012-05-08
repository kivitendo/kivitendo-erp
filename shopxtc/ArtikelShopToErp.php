<?php

$debug = true;

$api = php_sapi_name();
if ( $api != "cli" ) {
    echo "<html>\n<head>\n<meta http-equiv='Content-Type' content='text/html; charset=UTF-8'>\n</head>\n<body>\n";
    @apache_setenv('no-gzip', 1);
    @ini_set('zlib.output_compression', 0);
    @ini_set('implicit_flush', 1);
    $shopnr = $_GET["Shop"];
    $nofiles = ( $_GET["nofiles"] == '1' )?true:false;
} else {
    if ( $argc > 1 ) {
        $tmp = explode("=",trim($argv[1]));
        if ( count($tmp) != 2 ) {
             echo "Falscher Aufruf: php <scriptname.php> shop=1\n";
             exit (-1);
         } else {
              $shopnr = $tmp[1];
         }
    }
}

include_once("conf$shopnr.php");
include_once("error.php");
//Fehlerinstanz
$err = new error($api);

include_once("dblib.php");
include_once("xtc.php");
include_once("erplib.php");



//ERP-Instanz
$erpdb = new mydb($ERPhost,$ERPdbname,$ERPuser,$ERPpass,$ERPport,'pgsql',$err,$debug);
if ($erpdb->db->connected_database_name == $ERPdbname) {
    $erp = new erp($erpdb,$err,$divStd,$divVerm,$auftrnr,$kdnum,$preA,$preK,$invbrne,$mwstLX,$OEinsPart,$lager,$pricegroup,$ERPusrID);
} else {
    $err->out('Keine Verbindung zur ERP',true);
    exit();
}

//Shop-Instanz
$shopdb = new mydb($SHOPhost,$SHOPdbname,$SHOPuser,$SHOPpass,$SHOPport,'mysql',$err,$debug);
if ($shopdb->db->connected_database_name == $SHOPdbname) {
     $shop = new xtc($shopdb,$err,$SHOPdbname,$divStd,$divVerm,$minder,$nachn,$versandS,$versandV,$paypal,$treuhand,$mwstLX,$mwstS,$variantnr,$unit);
} else {
    $err->out('Keine Verbindung zum Shop',true);
    exit();
}

$artikel = $shop->getAllArtikel();
echo "<pre>"; print_r($artikel); echo "</pre>";
$cnt = 0;
$errors = 0;
//Artikel die mehreren Warengruppen zugeordnet sind, werden nur einmal importiert.
//Es wird dann auch nur die erste Warengruppe angelegt.
if ( $api != 'cli' ) ob_start();

$err->out("Artikelimport von Shop $shopnr",true);

if ($artikel) foreach ($artikel as $row) {
     $rc = $erp->chkPartnumber($row,true);
     if ($rc) { 
	$cnt++;
     } else { 
        $err->out('Fehler: '.$row['partnumber'],true);
	$errors++;
     }
}
$err->out('',true);
$err->out("$cnt Artikel geprüft bzw. übertragen, $errors Artikel nicht",true);
if ( $api != "cli" ) {
    echo "</body>\n</html>\n";
}
?>
