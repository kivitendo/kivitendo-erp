#!/bin/bash
VER="2.6.1"
#Jedes neue Paket der gleichen Version bekommt eine eigene Nummer
NR="0"

#hier wurde das Git-Paket entpakt:
SRC=/tmp/lx-office-erp
#hier wird das Debian-Paket gebaut:
DEST=/tmp/lx-office/lx-office-erp_$VER-$NR-all

mkdir -p $DEST
cd $DEST

#Struktur anlegen:
cp -a $SRC/DEBIAN/* .
rm ./mk*.sh

#Dateien kopieren:
#aber keine fertigen Konfigurationen, nur *.default
cp -a $SRC/SL usr/lib/lx-office-erp
cp -a $SRC/bin usr/lib/lx-office-erp
cp -a $SRC/js usr/lib/lx-office-erp
cp -a $SRC/locale usr/lib/lx-office-erp
cp -a $SRC/lxo-import usr/lib/lx-office-erp
cp -a $SRC/modules usr/lib/lx-office-erp
cp -a $SRC/scripts usr/lib/lx-office-erp
cp -a $SRC/sql usr/lib/lx-office-erp
cp -a $SRC/t usr/lib/lx-office-erp
cp -a $SRC/*.pl usr/lib/lx-office-erp
cp $SRC/VERSION usr/lib/lx-office-erp
cp $SRC/index.html usr/lib/lx-office-erp
cp $SRC/config/lx-erp.conf  etc/lx-office-erp/lx-erp.conf.default
cp $SRC/config/authentication.pl.default etc/lx-office-erp/
cp $SRC/menu.ini usr/lib/lx-office-erp/menu.default
cp -a $SRC/css var/lib/lx-office-erp
cp -a $SRC/templates var/lib/lx-office-erp
cp -a $SRC/users var/lib/lx-office-erp
cp -a $SRC/xslt var/lib/lx-office-erp

cp -a $SRC/doc/* usr/share/doc/lx-office-erp/
cp -a $SRC/image/* usr/share/lx-office-erp/

#Git- und dummy-files löschen
find . -name ".git*" -exec rm -rf {} \;
find . -name ".dummy" -exec rm -rf {} \;

#Rechte setzen
chown -R www-data: usr/lib/lx-office-erp
chown -R www-data: var/lib/lx-office-erp
chown -R www-data: etc/lx-office-erp

#MD5 Summe bilden:
find usr/ -name "*" -type f -exec md5sum {} \; > DEBIAN/md5sum
find var/ -name "*" -type f -exec md5sum {} \; >> DEBIAN/md5sum
find etc/ -name "*" -type f -exec md5sum {} \; >> DEBIAN/md5sum

#Größe feststellen:
SIZE=`du -scb . | grep insgesamt | cut -f1`

#Controlfile updaten:
cat DEBIAN/control | sed --expression "s/Installed-Size: 0/Installed-Size: $SIZE/g" > DEBIAN/1.tmp
mv DEBIAN/1.tmp DEBIAN/control
cat DEBIAN/control | sed --expression "s/Version: 0/Version: $VER-$NR/g" > DEBIAN/1.tmp
mv DEBIAN/1.tmp DEBIAN/control
#Revisionsnummer evtl. von Hand eintragen

#Paket bauen:
cd ..
dpkg-deb --build lx-office-erp_$VER-$NR-all

echo "Done"
