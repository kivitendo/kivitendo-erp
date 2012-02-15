<?php


class picture {

    var $smallwidth = 150;
    var $bigwidth = 800;
    var $original = true;
    var $err = false;

    function picture($ERPhost,$ERPuser,$ERPpass,$ERPimgdir,$SHOPhost,$SHOPuser,$SHOPpass,$SHOPimgdir,$err) {
        $this->ERPftphost = $ERPhost;
        $this->ERPftpuser = $ERPuser;
        $this->ERPftppwd = $ERPpass;
        $this->ERPimgdir = $ERPimgdir;
        $this->SHOPftphost = $SHOPhost;
        $this->SHOPftpuser = $SHOPuser;
        $this->SHOPftppwd = $SHOPpass;
        $this->SHOPimgdir = $SHOPimgdir;
        $this->err = $err;
    }

    function copyImage($id,$image,$typ) {
        if ( !$this->fromERP($image) ) return false;
        if ( !$this->mkbilder() ) return false;
        return $this->toShop($id,$typ);
    }

    function mkbilder() {
        if ( !class_exists("Imagick") ) { $this->err->out("Imagick-Extention nicht installiert",true); return false; };
        $handle = new Imagick();
        if ( !$handle->readImage("./tmp/tmp.file_org") ) return false;
        $d = $handle->getImageGeometry();
        if ( $d["width"]<$d["height"] ) {
            $faktor = $d["height"]/$d["width"];
        } else {
            $faktor = $d["width"]/$d["height"];
        }
        $smallheight = floor($this->smallwidth*$faktor);
        $handle->thumbnailImage($this->smallwidth, $smallheight);
        $rc = $handle->writeImage( "./tmp/tmp.file_small");
        if ( !$this->original ) {
            $handle->readImage("./tmp/tmp.file_org");
            $bigheight = floor($this->bigwidth * $faktor);
            $handle->thumbnailImage( $this->bigwidth, $bigheight);
            return $handle->writeImage( "./tmp/tmp.file_org");
        }
        return $rc;
    }

    function fromERP($image) {
        if ( $this->ERPftphost == 'localhost' ) {
            exec("cp $this->ERPimgdir/$image ./tmp/tmp.file_org",$aus,$rc2);
            if ( $rc2>0 ) { $this->err->out("[Downloadfehler: $image]",true); return false; };
        } else {
            $conn_id = ftp_connect($this->ERPftphost);
            $rc = @ftp_login($conn_id,$this->ERPftpuser,$this->ERPftppwd);
            $src = $this->ERPimgdir."/".$image;
            $upload = @ftp_get($conn_id,"tmp/tmp.file_org","$src",FTP_BINARY);
            if ( !$upload ) { $this->err->out("[Ftp Downloadfehler! $image]",true); return false; };
            ftp_quit($conn_id);
        }
        $this->image = $image;
        return true;
    }

    function toShop($id,$typ) {
        $grpic = $id."_gr.".$typ;
        $klpic = $id."_kl.".$typ;
        if ( $this->SHOPftphost == 'localhost' ) {
            exec("cp ./tmp/tmp.file_org $this->SHOPimgdir/$grpic",$aus,$rc1);
            exec("cp ./tmp/tmp.file_small $this->SHOPimgdir/$klpic",$aus,$rc2);
            if ( $rc1>0 || $rc2>0 ) { $this->err->out("[Uploadfehler: $this->image / $grpic]",true); return false; };
        } else {
            $conn_id = ftp_connect($this->SHOPftphost);
            @ftp_login($conn_id,$this->SHOPftpuser,$this->SHOPftppwd);
            @ftp_chdir($conn_id,$this->SHOPimgdir);
            $upload = @ftp_put($conn_id,$this->SHOPimgdir."/$grpic","tmp/tmp.file_org",FTP_BINARY);
            if ( !$upload ) { $this->err->out("[Ftp Uploadfehler! $grpic]",true); return false; };
            $upload = @ftp_put($conn_id,$this->SHOPimgdir."/$klpic","tmp/tmp.file_small",FTP_BINARY);
            if ( !$upload ) { $this->err->out("[Ftp Uploadfehler! $klpic]",true); return false; };
            @ftp_quit($conn_id);
        }
        return true;
    }


}
?>
