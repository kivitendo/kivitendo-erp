<?
// $Id: confedit.php 2009/02/10 14:41:30 hli Exp $
if (!isset($_SERVER['PHP_AUTH_USER'])) {
       Header("WWW-Authenticate: Basic realm='Configurations-Editor'");
       Header("HTTP/1.0 401 Unauthorized");
       echo "Sie m&uuml;ssen sich autentifizieren\n";
       exit;
} else {
        if (!$_POST) {
            //Je Shop ein Conf-File == Multishop
        $Shop=$_GET["Shop"];
        if ($Shop != "" and file_exists ("conf$Shop.php")) {
            require "conf$Shop.php";
            $out = "Konfiguration für Shop $Shop gelesen";
        } else {
             //Singleshop oder noch kein Shop definiert
            require "conf.php";
             $out = "Standard-Konfiguration gelesen";
        }
        if ($_SERVER['PHP_AUTH_USER']<>$ERPftpuser || $_SERVER['PHP_AUTH_PW']<>$ERPftppwd) {
            Header("WWW-Authenticate: Basic realm='My Realm'");
            Header("HTTP/1.0 401 Unauthorized");
            echo "Sie m&uuml;ssen sich autentifizieren\n";
            exit;
        }
        echo $out;
    }
}

include_once("error.php");
include_once("dblib.php");
$api = php_sapi_name();
if ( $api == 'cli' ) {
    echo "Nur im Browser benutzen\n";
    exit(-1);
};
$err = new error($api);

$zeichen = array("","UTF-8","ISO-8859-1","ISO-8859-15","Windows-1252","ASCII");
function lager($sel,$db) {
        if (!$db) return '';
        $sql  = "select w.description as lager,b.description as platz,b.id from ";
        $sql .= "bin b left join warehouse w on w.id=b.warehouse_id ";
        $sql .= "order by b.warehouse_id,b.id";
        $bin=$db->getall($sql);
        echo "\t<option value=-1 ".(($sel==-1)?'selected':'').">kein Lagerbestand\n";
        echo "\t<option value=1 ".(($sel==1)?'selected':'').">Gesamtbestand\n";
        if ($bin) foreach ($bin as $row) {
        echo "\t<option value=".$row['id'];
        if ($sel==$row['id']) echo " selected";
        echo ">".$row['lager']." ".$row['platz']."\n";
        }
}
function unit($sel,$db) {
        if (!$db) return '';
    $sql="select name from units order by sortkey";
    $pgs=$db->getall($sql);
    if ($sel=='') $sel=$pgs[0]['name'];
    if ($pgs) foreach ($pgs as $row) {
        echo "\t<option value=".$row['name'];
        if ($sel==$row['name']) echo " selected";
        echo ">".$row['name']."\n";
    }
}
function pg($sel,$db) {
    if (!$db) return '';
    $sql="select id,pricegroup from pricegroup";
    $pgs=$db->getall($sql);
    echo "\t<option value=0";
    if ($sel==0) echo " selected";
    echo ">Standard VK\n";
    if ($pgs) foreach ($pgs as $row) {
        echo "\t<option value=".$row['id'];
        if ($sel==$row['id']) echo " selected";
        echo ">".$row['pricegroup']."\n";
    }
}
function getTax($db) {
    $sql  = "SELECT  BG.id AS bugru,T.rate,TK.startdate,C.taxkey_id, ";
    $sql .= "(SELECT id FROM chart WHERE accno = T.taxnumber) AS tax_id, ";
    $sql .= "BG.income_accno_id_0,BG.expense_accno_id_0 ";
    $sql .= "FROM buchungsgruppen BG LEFT JOIN chart C ON BG.income_accno_id_0=C.id ";
    $sql .= "LEFT JOIN taxkeys TK ON TK.chart_id=C.id ";
    $sql .= "LEFT JOIN tax T ON T.id=TK.tax_id WHERE TK.startdate <= now()";
    $rs = $db->getAll($sql);
    if ($rs) foreach ($rs as $row) {
        $nr = $row['bugru'];
        if (!$TAX[$nr]) {
            $data = array();
            $data['startdate'] =    $row['startdate'];
            $data['rate'] =         $row['rate']*100.0;
            $TAX[$nr] = $data;
        } else if ($TAX[$nr]['startdate'] < $row['startdate']) {
            $TAX[$nr]["startdate"] =     $row['startdate'];
            $TAX[$nr]["rate"] =     $row['rate']*100.0;
        }
    }
    return $TAX;
}
function fputsA($f,$key,$var,$bg=false) {
    $lf="\n";
    fputs($f,'$'.$key.'["ID"]=\''. $var['ID'].'\';'.$lf);
    fputs($f,'$'.$key.'["NR"]=\''. $var['NR'].'\';'.$lf);
    fputs($f,'$'.$key.'["Unit"]=\''. $var['Unit'].'\';'.$lf);
    fputs($f,'$'.$key.'["TXT"]=\''. $var['TXT'].'\';'.$lf);
    if ($bg) fputs($f,'$'.$key.'["BUGRU"]=\''. $var['BUGRU'].'\';'.$lf);
    if ($bg) fputs($f,'$'.$key.'["TAX"]=\''. $var['TAX'].'\';'.$lf);
}

if ($_POST["ok"]=="sichern") {
    foreach ($_POST as $key=>$val) {
        ${$key} = $val;
    }
};
    if ( empty($ERPport) ) $ERPport = '5432';
    if ( empty($SHOPport) ) $SHOPport = '3306';

    $ok=true;
    $dbP = new mydb($ERPhost,$ERPdbname,$ERPuser,$ERPpass,$ERPport,'pgsql',$err,$debug);
    if (!$dbP->db) {
        $ok=false;
        echo "Keine Verbindung zur ERP<br>";
        $dbP=false;
        unset($divStd['ID']);
        unset($divVerm['ID']);
        unset($minder['ID']);
        unset($versand['ID']);
        unset($nachn['ID']);
        unset($paypal['ID']);
        unset($treuhand['ID']);
        unset($ERPusr['ID']);
    } else {
        $tax = getTax($dbP);
        $sql="SELECT id,description,unit,buchungsgruppen_id FROM parts where partnumber = '%s'";
        $rs=$dbP->getOne(sprintf($sql,$divStd['NR']));
        $divStd['ID']=$rs['id'];
        $divStd['Unit']=$rs['unit'];
        $divStd['BUGRU']=$rs['buchungsgruppen_id'];
        $divStd['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        $divStd['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne(sprintf($sql,$divVerm['NR']));
        $divVerm['ID']=$rs['id'];
        $divVerm['Unit']=$rs['unit'];
        $divVerm['BUGRU']=$rs['buchungsgruppen_id'];
        $divVerm['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        $divVerm['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne(sprintf($sql,$versandS['NR']));
        $versandS['ID']=$rs['id'];
        $versandS['Unit']=$rs['unit'];
        $versandS['BUGRU']=$rs['buchungsgruppen_id'];
        $versandS['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        if ($versandS['TXT'] == '') $versandS['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne(sprintf($sql,$versandV['NR']));
        $versandV['ID']=$rs['id'];
        $versandV['Unit']=$rs['unit'];
        $versandV['BUGRU']=$rs['buchungsgruppen_id'];
        $versandV['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        if ($versandV['TXT'] == '') $versandV['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne(sprintf($sql,$nachn['NR']));
        $nachn['ID']=$rs['id'];
        $nachn['Unit']=$rs['unit'];
        $nachn['BUGRU']=$rs['buchungsgruppen_id'];
        $nachn['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        if ($nachn['TXT'] == '') $nachn['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne(sprintf($sql,$minder['NR']));
        $minder['ID']=$rs['id'];
        $minder['Unit']=$rs['unit'];
        $minder['BUGRU']=$rs['buchungsgruppen_id'];
        $minder['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        if ($minder['TXT'] == '') $minder['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne(sprintf($sql,$paypal['NR']));
        $paypal['ID']=$rs['id'];
        $paypal['Unit']=$rs['unit'];
        $paypal['BUGRU']=$rs['buchungsgruppen_id'];
        $paypal['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        if ($paypal['TXT'] == '') $paypal['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne(sprintf($sql,$treuhand['NR']));
        $treuhand['ID']=$rs['id'];
        $treuhand['Unit']=$rs['unit'];
        $treuhand['BUGRU']=$rs['buchungsgruppen_id'];
        $treuhand['TAX']=$tax[$rs['buchungsgruppen_id']]['rate'];
        if ($treuhand['TXT'] == '') $treuhand['TXT']=addslashes($rs['description']);
        $rs=$dbP->getOne("select id from employee where login = '".$ERPusrName."'");
        $ERPusrID=$rs['id'];
    }
    $dbM = new mydb($SHOPhost,$SHOPdbname,$SHOPuser,$SHOPpass,$SHOPport,'mysql',$err,$debug);
    if (!$dbM->db) {
        $ok=false;
        echo "Keine Verbindung zum Shop<br>";
        $dbM=false;
    };
if ($_POST["ok"]=="sichern") {
   $lf = "\n";
   $f = @fopen("conf$Shop.php","w");
   if ($f) {
        $v="1.5";
        $d=date("Y/m/d H:i:s");
        fputs($f,"<?php$lf// Verbindung zur ERP-db$lf");
        fputs($f,'$debug=\''.$debug.'\';'.$lf);
        fputs($f,'$ERPuser=\''.$ERPuser.'\';'.$lf);
        fputs($f,'$ERPpass=\''.$ERPpass.'\';'.$lf);
        fputs($f,'$ERPhost=\''.$ERPhost.'\';'.$lf);
        fputs($f,'$ERPport=\''.$ERPport.'\';'.$lf);
        fputs($f,'$ERPdbname=\''.$ERPdbname.'\';'.$lf);
        fputs($f,'$codeLX=\''.$codeLX.'\';'.$lf);
        fputs($f,'$mwstLX=\''.$mwstLX.'\';'.$lf);
        fputs($f,'$ERPusrName=\''.$ERPusrName.'\';'.$lf);
        fputs($f,'$ERPusrID=\''.$ERPusrID.'\';'.$lf);
        fputs($f,'$ERPimgdir=\''.$ERPimgdir.'\';'.$lf);
        fputs($f,'$maxSize=\''.$maxSize.'\';'.$lf);
        fputs($f,'$ERPftphost=\''.$ERPftphost.'\';'.$lf);
        fputs($f,'$ERPftpuser=\''.$ERPftpuser.'\';'.$lf);
        fputs($f,'$ERPftppwd=\''.$ERPftppwd.'\';'.$lf);
        fputs($f,'//Verbindung zur osCommerce-db'.$lf);
        fputs($f,'$SHOPuser=\''.$SHOPuser.'\';'.$lf);
        fputs($f,'$SHOPpass=\''.$SHOPpass.'\';'.$lf);
        fputs($f,'$SHOPhost=\''.$SHOPhost.'\';'.$lf);
        fputs($f,'$SHOPport=\''.$SHOPport.'\';'.$lf);
        fputs($f,'$SHOPdbname=\''.$SHOPdbname.'\';'.$lf);
        fputs($f,'$codeS=\''.$codeS.'\';'.$lf);
        fputs($f,'$mwstS=\''.$mwstS.'\';'.$lf);
        fputs($f,'$SHOPimgdir=\''.$SHOPimgdir.'\';'.$lf);
        fputs($f,'$SHOPftphost=\''.$SHOPftphost.'\';'.$lf);
        fputs($f,'$SHOPftpuser=\''.$SHOPftpuser.'\';'.$lf);
        fputs($f,'$SHOPftppwd=\''.$SHOPftppwd.'\';'.$lf);
        fputs($f,'$nopic=\''.$nopic.'\';'.$lf);
        fputs($f,'$nopicerr=\''.$nopicerr.'\';'.$lf);
        fputsA($f,'divStd',$divStd,true);
        fputsA($f,'divVerm',$divVerm,true);
        fputsA($f,'versandS',$versandS,true);
        fputsA($f,'versandV',$versandV,true);
        fputsA($f,'minder',$minder,true);
        fputsA($f,'nachn',$nachn,true);
        fputsA($f,'treuhand',$treuhand,true);
        fputsA($f,'paypal',$paypal,true);
        fputs($f,'$bgcol[1]=\'#ddddff\';'.$lf);
        fputs($f,'$bgcol[2]=\'#ddffdd\';'.$lf);
        fputs($f,'$preA=\''.$preA.'\';'.$lf);
        fputs($f,'$preK=\''.$preK.'\';'.$lf);
        fputs($f,'$auftrnr=\''.$auftrnr.'\';'.$lf);
        //fputs($f,'$utftrans=\''.$utftrans.'\';'.$lf);
        fputs($f,'$kdnum=\''.$kdnum.'\';'.$lf);
        fputs($f,'$pricegroup=\''.$pricegroup.'\';'.$lf);
        fputs($f,'$unit=\''.$unit.'\';'.$lf);
        fputs($f,'$longtxt=\''.$longtxt.'\';'.$lf);
        fputs($f,'$invbrne=\''.$invbrne.'\';'.$lf);
        fputs($f,'$variantnr=\''.$variantnr.'\';'.$lf);
        fputs($f,'$OEinsPart=\''.$OEinsPart.'\';'.$lf);
        fputs($f,'$lager=\''.$lager.'\';'.$lf);
        //fputs($f,'$showErr=true;'.$lf);
        fputs($f,"?>");
        fclose($f);
        echo "Konfiguration conf$Shop.php gesichert.";
    } else {
        echo "Konfigurationsdatei (conf$Shop.php) konnte nicht geschrieben werden";
    }
} 
?>
<html>
<body>
<center>
<table style="background-color:#cccccc" border="0">
<form name="ConfEdit" method="post" action="confedit.php">
<input type="hidden" name="Shop" value="<?= $Shop ?>">
<input type="hidden" name="divStd[ID]" value="<?= $divStd['ID'] ?>">
<input type="hidden" name="divVerm[ID]" value="<?= $divVerm['ID'] ?>">
<input type="hidden" name="minder[ID]" value="<?= $minder['ID'] ?>">
<input type="hidden" name="versandS[ID]" value="<?= $versandS['ID'] ?>">
<input type="hidden" name="versandV[ID]" value="<?= $versandV['ID'] ?>">
<input type="hidden" name="nachn[ID]" value="<?= $nachn['ID'] ?>">
<input type="hidden" name="paypal[ID]" value="<?= $paypal['ID'] ?>">
<input type="hidden" name="treuhand[ID]" value="<?= $treuhand['ID'] ?>">
<input type="hidden" name="ERPusr[ID]" value="<?= $ERPusr['ID'] ?>">

<tr><th>Daten</th><th>Lx-ERP</th><th><?php echo $Shop ?></th><th>Shop</th></tr>
<tr>
    <td>db-Host</td>
    <td colspan="2"><input type="text" name="ERPhost" size="25" value="<?= $ERPhost ?>"></td>
    <td><input type="text" name="SHOPhost" size="25" value="<?= $SHOPhost ?>"></td>
</tr>
<tr>
    <td>db-Port</td>
    <td colspan="2"><input type="text" name="ERPport" size="25" value="<?= $ERPport ?>"></td>
    <td><input type="text" name="SHOPport" size="25" value="<?= $SHOPport ?>"></td>
</tr>
<tr>
    <td>Database</td>
    <td colspan="2"><input type="text" name="ERPdbname" size="20" value="<?= $ERPdbname ?>"></td>
    <td><input type="text" name="SHOPdbname" size="20" value="<?= $SHOPdbname ?>"></td>
</tr>
<tr>
    <td>db-User Name</td>
    <td colspan="2"><input type="text" name="ERPuser" size="15" value="<?= $ERPuser ?>"></td>
    <td><input type="text" name="SHOPuser" size="15" value="<?= $SHOPuser ?>"></td>
</tr>
<tr>
    <td>db-User PWD</td>
    <td colspan="2"><input type="text" name="ERPpass" size="15" value="<?= $ERPpass ?>"></td>
    <td><input type="text" name="SHOPpass" size="15" value="<?= $SHOPpass ?>"></td>
</tr>
</tr>
    <td>Zeichensatz</td>
    <td colspan="2"><select name="codeLX">
<?php   foreach($zeichen as $code) {
             echo "<option value='".$code."'";
             if ($code == $codeLX) echo " selected";
             echo ">".$code."\n"; };
?>
    </select></td>
    <td ><select name="codeS">
<?php   foreach($zeichen as $code) {
             echo "<option value='".$code."'";
             if ($code == $codeS) echo " selected";
             echo ">".$code."\n"; };
?>
    </select></td>
</tr>
<tr>
    <td>Preise </td>
        <td colspan="2"> <input type="radio" name="mwstLX" value="1" <?= ($mwstLX==1)?"checked":'' ?>> incl.
        <input type="radio" name="mwstLX" value="0" <?= ($mwstLX<>1)?"checked":'' ?>> excl. MwSt</td>
    <td><input type="radio" name="mwstS" value="1" <?= ($mwstS==1)?"checked":'' ?>> incl.
        <input type="radio" name="mwstS" value="0" <?= ($mwstS<>1)?"checked":'' ?>> excl. MwSt</td>
</tr>
<tr>
    <td>User-ID</td>
    <td colspan="2"><input type="text" name="ERPusrName" size="10" value="<?= $ERPusrName ?>">
        <input type="checkbox" name="a1" <?= (empty($ERPusrID)?'':"checked") ?>></td>
    <td></td>
</tr>
<tr>
    <td>Image-Dir</td>
    <td colspan="2"><input type="text" name="ERPimgdir" size="30" value="<?= $ERPimgdir ?>"></td>
    <td><input type="text" name="SHOPimgdir" size="30" value="<?= $SHOPimgdir ?>"></td>
</tr>
<tr>
    <td>Platzhalterbild</td>
    <td colspan="2"><input type="text" name="nopic" size="20" value="<?php echo $nopic; ?>">ohne Endung</td>
    <td colspan="2"><input type="checkbox" value="1" name="nopicerr" <?= (empty($nopicerr)?'':"checked") ?>>nur bei fehlerhaftem Upload verwenden</td>
</tr>
<tr>
    <td>FTP-Host</td>
    <td colspan="2"><input type="text" name="ERPftphost" size="20" value="<?= $ERPftphost ?>"></td>
    <td><input type="text" name="SHOPftphost" size="20" value="<?= $SHOPftphost ?>"></td>
</tr>
<tr>
    <td>FTP-User</td>
    <td colspan="2"><input type="text" name="ERPftpuser" size="15" value="<?= $ERPftpuser ?>"></td>
    <td><input type="text" name="SHOPftpuser" size="15" value="<?= $SHOPftpuser ?>"></td>
</tr>
<tr>
    <td>FTP-User PWD</td>
    <td colspan="2"><input type="text" name="ERPftppwd" size="15" value="<?= $ERPftppwd ?>"></td>
    <td><input type="text" name="SHOPftppwd" size="15" value="<?= $SHOPftppwd ?>"></td>
</tr>
<tr>
    <td>Nr Diverse Std-MwSt</td>
    <td><input type="text" name="divStd[NR]" size="10" value="<?= $divStd['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($divStd['ID'])?'':"checked") ?>></td>
    <td>Nr Diverse Verm-MwSt</td>
    <td><input type="text" name="divVerm[NR]" size="10" value="<?= $divVerm['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($divVerm['ID'])?'':"checked") ?>></td>
</tr>
<tr>
    <td>Nr Versand Std-MwSt</td>
    <td><input type="text" name="versandS[NR]" size="10" value="<?= $versandS['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($versandS['ID'])?'':"checked") ?>></td>
    <td>Text:</td>
    <td><input type="text" name="versandS[TXT]" size="20" value="<?= $versandS['TXT'] ?>"><?= $versandS['TAX'] ?></td>
<tr>
    <td>Nr Versand Verm-MwSt</td>
    <td><input type="text" name="versandV[NR]" size="10" value="<?= $versandV['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($versandV['ID'])?'':"checked") ?>></td>
    <td>Text:</td>
    <td><input type="text" name="versandV[TXT]" size="20" value="<?= $versandV['TXT'] ?>"><?= $versandV['TAX'] ?></td>
</tr>
<tr>
    <td>Nr Paypal</td>
    <td><input type="text" name="paypal[NR]" size="10" value="<?= $paypal['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($paypal['ID'])?'':"checked") ?>></td>
    <td>Text:</td>
    <td><input type="text" name="paypal[TXT]" size="20" value="<?= $paypal['TXT'] ?>"></td>
</tr>
<tr>
    <td>Nr Treuhand</td>
    <td><input type="text" name="treuhand[NR]" size="10" value="<?= $treuhand['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($treuhand['ID'])?'':"checked") ?>></td>
    <td>Text:</td>
    <td><input type="text" name="treuhand[TXT]" size="20" value="<?= $treuhand['TXT'] ?>"></td>
</tr>
<tr>
    <td>Nr Mindermenge</td>
    <td><input type="text" name="minder[NR]" size="10" value="<?= $minder['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($minder['ID'])?'':"checked") ?>></td>
    <td>Text:</td>
    <td><input type="text" name="minder[TXT]" size="20" value="<?= $minder['TXT'] ?>"></td>
</tr>
<tr>
    <td>Nr Nachname</td>
    <td><input type="text" name="nachn[NR]" size="10" value="<?= $nachn['NR'] ?>">
        <input type="checkbox" name="a1" <?= (empty($nachn['ID'])?'':"checked") ?>></td>
    <td>Text:</td>
    <td><input type="text" name="nachn[TXT]" size="20" value="<?= $nachn['TXT'] ?>"></td>
</tr>
<tr>
    <td>Std-Einheit</td>
    <td><select name="unit">
<? unit($unit,$dbP); ?>
        </select></td>
    <td>Preisgruppe</td>
    <td><select name="pricegroup">
<? pg($pricegroup,$dbP); ?>
        </select></td>
<tr>
    <td colspan="2">Auftragsnummern durch</td>
    <td><input type="radio" name="auftrnr" value="1" <?= ($auftrnr==1)?"checked":'' ?>> LxO</td>
    <td><input type="radio" name="auftrnr" value="0" <?= ($auftrnr<>1)?"checked":'' ?>> Shop</td>
</tr>
<tr>
    <td colspan="2">Kundennummern durch</td>
    <td><input type="radio" name="kdnum" value="1" <?= ($kdnum==1)?"checked":'' ?>> LxO</td>
    <td><input type="radio" name="kdnum" value="0" <?= ($kdnum<>1)?"checked":'' ?>> Shop</td>
</tr>
<tr>
    <td colspan="2">Nummernerweiterung</td>
    <td>Auftrag<input type="text" name="preA" size="5" value="<?= $preA ?>"></td>
    <td>Kunde<input type="text" name="preK" size="5" value="<?= $preK ?>"></td>
</tr>
<tr>
    <td>Lagerbestand aus</td>
    <td><select name="lager">
<? lager($lager,$dbP); ?>
        </select></td>
    <td></td>
    <td></td>
<tr>
<tr>
    <td colspan="3">Langbeschreibung aus Shop &uuml;bernehmen</td>
    <td><input type="radio" name="longtxt"  value="1" <?= ($longtxt<>2)?"checked":'' ?>>Ja
    <input type="radio" name="longtxt"  value="2" <?= ($longtxt==2)?"checked":'' ?>>Nein</td>

</tr>
<tr>
    <td colspan="3">LxO-Rechnungen sind Netto</td>
    <td><input type="radio" name="invbrne"  value="1" <?= ($invbrne<>2)?"checked":'' ?>>Ja
    <input type="radio" name="invbrne"  value="2" <?= ($invbrne==2)?"checked":'' ?>>Nein</td>
</tr>
<tr>
    <td colspan="3">Varianten sind eigene Nummern in Lx (-n)</td>
    <td><input type="radio" name="variantnr"  value="1" <?= ($variantnr<>2)?"checked":'' ?>>Ja
    <input type="radio" name="variantnr"  value="2" <?= ($variantnr==2)?"checked":'' ?>>Nein</td>
</tr>
<tr>
    <td colspan="3">Unbekannte Artikel beim Bestellimport anlegen</td>
    <td><input type="radio" name="OEinsPart"  value="1" <?= ($OEinsPart<>2)?"checked":'' ?>>Ja
    <input type="radio" name="OEinsPart"  value="2" <?= ($OEinsPart==2)?"checked":'' ?>>Nein</td>
</tr>
<tr>
    <td>Logging</td>
    <td>ein<input type="radio" name="debug" value="true" <?= ($debug=="true")?"checked":"" ?>>
    aus<input type="radio" name="debug" value="false" <?= ($debug!="true")?"checked":"" ?>></td>
    <td></td><td></td>
</tr>

<!--tr>
    <td>Bildergr&ouml;sse (byte)</td>
    <td><input type="text" name="maxSize" size="10" value="<?= $maxSize ?>"></td>
    <td></td>
</tr-->


<tr><td colspan="4" align="center"><input type="submit" name="ok" value="sichern"></td></tr>
</form>
</table>
</center>
</body>
</html>
