<?php

class error {

  var $log = false; 
  var $api = '';
  var $lf  = '<br />';

  function error($api) {
     $this->log = fopen("/tmp/shop.log","a");
     $this->api = $api;
     if ( $api == 'cli' ) { $this->lf = "\n"; }
     else { $this->lf = "<br />"; };
  }

  function write($func,$string) {
     $now = date('Y-m-d H:m:i ');
     fputs($this->log,$now.$func."\n");
     fputs($this->log,$string."\n");
  }

  function close() {
     fclose($this->log);
  }
  function out($txt,$lf=false) {
    if ( $this->api != 'cli' ) {
        echo str_repeat(" ", 256);
        echo $txt;
        if ( $lf ) echo $this->lf;
        flush(); ob_flush();
    } else {
        echo $txt;
        if ( $lf ) echo $this->lf;
    }
  }
}
?>
