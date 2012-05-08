<?php

include_once("MDB2.php");

class mydb {

   var $db = false;
   var $error = false;
   var $debug = true;
   var $dbf = false;
   var $database = false;

   function mydb($host,$db,$user,$pass,$port,$proto,$error,$debug) {
       $this->error = $error;
       $dsn = array('phptype'  => $proto,
               'username' => $user,
               'password' => $pass,
               'hostspec' => $host,
               'database' => $db,
               'port'     => $port);
       $this->debug = $debug;
       $this->database = "-< $db >-";
       $this->connect($dsn);
    }

    function connect($dsn) {
       $options = array('result_buffering' => false,);
       $this->db = MDB2::connect($dsn,$options);
       if ( $this->debug ) $this->error->write('dblib->connect '.$this->database,'Connect:');
       if (PEAR::isError($this->db)) {
           $this->error->write('dblib->connect '.$this->database,$this->db->getMessage());
           $this->error->write('dblib->connect '.$this->database,print_r($dsn,true));
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
        if ( $this->debug ) $this->error->write('dblib->getAll '.$this->database,$sql);
        if (PEAR::isError($rs)) {
            $this->error->write('dblib->getAll '.$this->database,$rs->getUserinfo());
            return false;
        }
        return $rs;
    } 
 
    function getOne($sql) {
        $rs = $this->db->queryRow($sql);
        if ( $this->debug ) $this->error->write('dblib->getOne '.$this->database,$sql);
        if (PEAR::isError($rs)) {
            $this->error->write('dblib->getOne '.$this->database,$rs->getUserinfo());
            return false;
        }
        return $rs;
    }
    function query($sql) {
        $rc = $this->db->query($sql);
        if ( $this->debug ) $this->error->write('dblib->query '.$this->database,$sql);
        if (PEAR::isError($rc)) {
            $this->error->write('dblib->query '.$this->database,$rc->getUserinfo());
            return false;
        }
        return $rc;
    } 
    function insert($statement,$data) {
        if ( $this->debug ) $this->error->write("dblib->insert ".$this->database,$statement);
        $sth = $this->db->prepare($statement);                      //Prepare
        if (PEAR::isError($sth)) {
            $this->error->write('dblib->insert 1 '.$this->database,$sth->getMessage());
            $this->error->write('dblib->insert 2',$sth->getUserinfo());
            $this->rollback();
            return false;
        }
        if ( $this->debug ) $this->error->write('dblib->insert',print_r($data,true));
        $rc =& $sth->execute($data);
        if (PEAR::isError($rc)) {
            $this->error->write('dblib->insert 3 '.$this->database,$rc->getUserinfo());
            $this->error->write('SQL ',$statement);
            $this->error->write('Data ',print_r($data,true));
            return false;
        }//else{
        //    $rc = $this->commit();
        //}
        return $rc;
    }
    function update($statement,$data) {  
        if ( $this->debug ) $this->error->write("dblib->update ".$this->database,$statement);
        $sth = $this->db->prepare($statement);                      //Prepare
        if (PEAR::isError($sth)) {
            $this->error->write('dblib->update 1 '.$this->database,$sth->getMessage());
            $this->error->write('dblib->update 2',$sth->getUserinfo());
            $this->rollback();
            return false;
        }
        if ( $this->debug ) $this->error->write('dblib->insert',print_r($data,true));
        $rc =& $sth->execute($data);
        if (PEAR::isError($rc)) {
            $this->error->write('dblib->update 3 '.$this->database,$rc->getUserinfo());
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
            $this->error->write('dblib->insertMultiple '.$this->database,$sth->getMessage());
            $this->rollback();
            return false;
        }
        $rc =& $this->db->beginTransaction();
        $rc =& $this->db->extended->executeMultiple($sth, $data);
        if (PEAR::isError($rc)) {
            $this->error->write('dblib->insertMultiple '.$this->database,$rc->getUserinfo());
            $this->rollback();
            return false;
        }else{
                $rc = $this->commit();
        }
        return $rc;
    }
}

?>
