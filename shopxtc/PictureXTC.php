<?php


class picture {

    var $popupwidth = 800;
    var $infowidth = 150;
    var $thumbwidth = 80;
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

        $thumbheight = floor($this->thumbwidth*$faktor);
        $handle->thumbnailImage($this->thumbwidth, $thumbheight);
        $rc = $handle->writeImage( "./tmp/tmp.file_thumb");

        $handle->readImage("./tmp/tmp.file_org");
        $popupheight = floor($this->popupwidth * $faktor);
        $handle->thumbnailImage( $this->popupwidth, $popupheight);
        $rc = $handle->writeImage( "./tmp/tmp.file_popup");

        $handle->readImage("./tmp/tmp.file_org");
        $infoheight = floor($this->infowidth * $faktor);
        $handle->thumbnailImage( $this->infowidth, $infoheight);
        $rc = $handle->writeImage( "./tmp/tmp.file_info");
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
        $picname = $id."_0.".$typ;
        if ( $this->SHOPftphost == 'localhost' ) {
            exec("cp ./tmp/tmp.file_org   $this->SHOPimgdir/original_images/$picname",$aus,$rc1);
            exec("cp ./tmp/tmp.file_info  $this->SHOPimgdir/info_images/$picname",$aus,$rc2);
            exec("cp ./tmp/tmp.file_popup $this->SHOPimgdir/popup_images/$picname",$aus,$rc3);
            exec("cp ./tmp/tmp.file_thumb $this->SHOPimgdir/thumbnail_images/$picname",$aus,$rc4);
            if ( $rc1>0 || $rc2>0 || $rc3>0 || $rc4>0 ) { $this->err->out("[Uploadfehler: $this->image / $picname]",true); return false; };
        } else {
            $conn_id = ftp_connect($this->SHOPftphost);
            @ftp_login($conn_id,$this->SHOPftpuser,$this->SHOPftppwd);
            @ftp_chdir($conn_id,$this->SHOPimgdir);
            $upload = @ftp_put($conn_id,$this->SHOPimgdir."/original_images/$picname","tmp/tmp.file_org",FTP_BINARY);
            if ( !$upload ) { $this->err->out("[Ftp Uploadfehler! original_images/$picname]",true); return false; };
            $upload = @ftp_put($conn_id,$this->SHOPimgdir."/info_images/$picname","tmp/tmp.file_info",FTP_BINARY);
            if ( !$upload ) { $this->err->out("[Ftp Uploadfehler! info_images/$picname]",true); return false; };
            $upload = @ftp_put($conn_id,$this->SHOPimgdir."/popup_images/$picname","tmp/tmp.file_popup",FTP_BINARY);
            if ( !$upload ) { $this->err->out("[Ftp Uploadfehler! popup_images/$picname]",true); return false; };
            $upload = @ftp_put($conn_id,$this->SHOPimgdir."/thumbnail_images/$picname","tmp/tmp.file_thumb",FTP_BINARY);
            if ( !$upload ) { $this->err->out("[Ftp Uploadfehler! thumb_images/$picname]",true); return false; };
            @ftp_quit($conn_id);
        }
        return true;
    }


}
?>
