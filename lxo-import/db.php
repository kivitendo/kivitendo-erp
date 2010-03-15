<?php
require_once "DB.php";
class myDB extends DB {

 var $db = false;
 var $rc = false;
 var $showErr = false; // Browserausgabe
 var $debug = false; // 1 = SQL-Ausgabe, 2 = zusätzlich Ergebnis
 var $log = true;  // Alle Abfragen mitloggen
 var $path = "/tmp/";
 var $lfh = false;
 
    function dbFehler($sql,$err) {
        $efh=fopen($this->path."lxcrm".date("w").".err","a");
        fputs($efh,date("Y-m-d H:i:s ->"));
        fputs($efh,$sql."\n");
        fputs($efh,$err."\n");
        fputs($efh,print_r($this->rc,true));
        fputs($efh,"\n");
        fclose($efh);
        if ($this->showErr)
            echo "</td></tr></table><font color='red'>$sql : $err</font><br>";
    }

    function showDebug($sql) {
        echo $sql."<br>";
        if ($this->debug==2) {
            echo "<pre>";
            print_r($this->rc);
            echo "</pre>";
        };
    }

    function writeLog($txt) {
        if ($this->lfh===false)
            $this->lfh=fopen($this->path."lxcrm".date("w").".log","a");
        fputs($this->lfh,date("Y-m-d H:i:s ->"));
        fputs($this->lfh,$txt."\n");
        fputs($this->lfh,print_r($this->rc,true));
        fputs($this->lfh,"\n");
    }

    function closeLogfile() {
        fclose($this->lfh);
    }
    
    function myDB($host,$user,$pwd,$db,$port,$showErr=false) {
        $dsn = array(
                    'phptype'  => 'pgsql',
                    'username' => $user,
                    'password' => $pwd,
                    'hostspec' => $host,
                    'database' => $db,
                    'port'     => $port
                );
        $this->showErr=$showErr;
        $this->db=DB::connect($dsn);
        if (!$this->db || DB::isError($this->db)) {
            if ($this->log) $this->writeLog("Connect $dns");
            $this->dbFehler("Connect ".print_r($dsn,true),$this->db->getMessage()); 
            die ($this->db->getMessage());
        }
        if ($this->log) $this->writeLog("Connect: ok ");
        return $this->db;
    }

    function query($sql) {
        $this->rc=@$this->db->query($sql);
        if ($this->debug) $this->showDebug($sql);
        if ($this->log) $this->writeLog($sql);
        if(DB::isError($this->rc)) {
            $this->dbFehler($sql,$this->rc->getMessage());
            $this->rollback();
            return false;
        } else {
            return $this->rc;
        }
    }

    function begin() {
        $this->query("BEGIN");
    }
    function commit() {
        $this->query("COMMIT");
    }
    function rollback() {
        $this->query("ROLLBACK");
    }

    function getAll($sql) {
        $this->rc=$this->db->getAll($sql,DB_FETCHMODE_ASSOC);
        if ($this->debug) $this->showDebug($sql);
        if ($this->log) $this->writeLog($sql);
        if(DB::isError($this->rc)) {
            $this->dbFehler($sql,$this->rc->getMessage());
            return false;
        } else {
            return $this->rc;
        }
    }

    function saveData($txt) {
        if (get_magic_quotes_gpc()) {     
            return $txt;
        } else {
            return DB::quoteSmart($string); 
        }
    }

    function execute($statement, $data){
        $sth = $this->db->prepare($statement);           //Prepare
        /*if (PEAR::isError($sth)) {
            $this->dbFehler($statement,$sth->getMessage());
            $this->rollback();
            return false;
        }*/
        $rc = $this->db->execute($sth,$data);
        if(PEAR::isError($rc)) {
            $this->dbFehler(print_r($data,true),$rc->getMessage()."\n".print_r($rc,true));
            $this->rollback();
            return false;
        }
        $this->db->commit();
        return true;
    }

    function chkcol($tbl) {
        // gibt es die Spalte import schon?
        $rc=$this->db->query("select import from $tbl limit 1");
        if(DB::isError($rc)) {
           $rc=$this->db->query("alter table $tbl add column import int4");
           if(DB::isError($rc)) { return false; }
           else { return true; }
        } else { return true; };
    }

    /**
     * Zeichekodirung der DB ermitteln
     * 
     * @return String
     */
    function getServerCode() {
        $sql="SHOW  server_encoding";
        $rs = $this->getAll($sql);
        return $rs[0]["server_encoding"];
    }
    function getClientCode() {
        $sql="SHOW  client_encoding";
        $rs = $this->getAll($sql);
        return $rs[0]["client_encoding"];
    }
    function setClientCode($encoding) {
        $sql="SET  client_encoding = '$encoding'";
        $rc = $this->query($sql);
        return $rc;
    }
           
}
?>
