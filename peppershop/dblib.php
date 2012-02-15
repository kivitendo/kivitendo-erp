<?php

include_once("MDB2.php");

class mydb {

   var $db = false;
   var $error = false;
   var $debug = true;
   var $dbf = false;

   function mydb($host,$db,$user,$pass,$port,$proto,$error) {
       $this->error = $error;
       $dsn = array('phptype'  => $proto,
               'username' => $user,
               'password' => $pass,
               'hostspec' => $host,
               'database' => $db,
               'port'     => $port);
       if ( $this->debug ) {
            $this->dbf = fopen ("tmp/shop.log","w");
            if ( !$this->dbf ) $this->debug = false;
       }
       $this->connect($dsn);
    }

    function log($txt) {
       $now = date('Y-m-d H:i:s');
       fputs($this->dbf,$now." : ".$txt."\n");
    }
    function connect($dsn) {
       $options = array('result_buffering' => false,);
       $this->db = MDB2::connect($dsn,$options);
       if ( $this->debug ) $this->log('Connect:');
       if (PEAR::isError($this->db)) {
           if ( $this->debug ) $this->log($this->db->getMessage());
           $this->error->write('dblib->connect',$this->db->getMessage());
           $this->error->write('dblib->connect',print_r($dsn,true));
           $this->db = false;
           return false;
       }
       $this->db->setFetchMode(MDB2_FETCHMODE_ASSOC);
    }
    function Begin() {
        return $this->db->beginTransaction();
    }
    function Commit() {
        return $this->db->commit();
    }
    function Rollback() {
        return $this->db->rollback();
    }

    function getAll($sql) {
        $rs = $this->db->queryAll($sql);
        if ( $this->debug ) $this->log($sql);
        if (PEAR::isError($rs)) {
            if ( $this->debug ) $this->log($rs->getUserinfo());
            $this->error->write('dblib->getAll',$rs->getUserinfo());
            return false;
        }
        return $rs;
    } 
 
    function getOne($sql) {
        $rs = $this->db->queryRow($sql);
        if ( $this->debug ) $this->log($sql);
        if (PEAR::isError($rs)) {
            if ( $this->debug ) $this->log($rs->getUserinfo());
            $this->error->write('dblib->getOne',$rs->getUserinfo());
            return false;
        }
        return $rs;
    }
    function query($sql) {
        $rc = $this->db->query($sql);
        if ( $this->debug ) $this->log($sql);
        if (PEAR::isError($rc)) {
            if ( $this->debug ) $this->log($rc->getUserinfo());
            $this->error->write('dblib->query',$rc->getUserinfo());
            return false;
        }
        return $rc;
    } 
    function insert($statement,$data) {
        if ( $this->debug ) $this->log("INSERT ".$statement);
        $sth = $this->db->prepare($statement);                      //Prepare
        if (PEAR::isError($sth)) {
            $this->error->write('dblib->insert 1',$sth->getMessage());
            $this->error->write('dblib->insert 2',$sth->getUserinfo());
            $this->rollback();
            return false;
        }
        if ( $this->debug ) $this->log(print_r($data,true));
        $rc =& $sth->execute($data);
        if (PEAR::isError($rc)) {
            if ( $this->debug ) $this->log($rc->getUserinfo());
            $this->error->write('dblib->insert 3',$rc->getUserinfo());
            return false;
        }//else{
        //    $rc = $this->commit();
        //}
        return $rc;
    }
    function update($statement,$data) {  
        if ( $this->debug ) $this->log("UPDATE ".$statement);
        $sth = $this->db->prepare($statement);                      //Prepare
        if (PEAR::isError($sth)) {
            if ( $this->debug ) $this->log("ERRPOR ".$rc->getUserinfo());
            $this->error->write('dblib->update 1',$sth->getMessage());
            $this->error->write('dblib->update 2',$sth->getUserinfo());
            $this->rollback();
            return false;
        }
        if ( $this->debug ) $this->log(print_r($data,true));
        $rc =& $sth->execute($data);
        if (PEAR::isError($rc)) {
            if ( $this->debug ) $this->log("ERRPOR ".$rc->getUserinfo());
            $this->error->write('dblib->update 3',$rc->getUserinfo());
            return false;
        }//else{
        //    $rc = $this->commit();
        //}
        return $rc;
    }
    function insertMultipe($statement,$data) {
        $this->db->loadModule('Extended');
        if (!$this->db->supports('transactions')){
            return false;
        }
        $sth = $this->db->prepare($statement);                      //Prepare
        if (PEAR::isError($sth)) {
            $this->error->write('dblib->insertMultiple',$sth->getMessage());
            $this->rollback();
            return false;
        }
        $rc =& $this->db->beginTransaction();
        $rc =& $this->db->extended->executeMultiple($sth, $data);
        if (PEAR::isError($rc)) {
            $this->error->write('dblib->insertMultiple',$rc->getUserinfo());
            $this->rollback();
            return false;
        }else{
                $rc = $this->commit();
        }
        return $rc;
    }
}

?>
