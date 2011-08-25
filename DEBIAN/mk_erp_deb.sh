#!/bin/bash

#Jedes neue Paket der gleichen Version bekommt eine eigene Nummer
NR="0"

#hier wurde das Git-Paket entpakt:
SRC=/tmp/lx-office-erp

#hier wird das Debian-Paket gebaut:
DST=/tmp/package


################################################
# ab hier keine Konfiguration mehr
################################################

VER=`cat VERSION`
DEST=$DST/lx-office-erp_$VER-$NR$1_all


mkdir -p $DEST
cd $DEST

#Struktur anlegen:
cp -a $SRC/DEBIAN/DEBIAN .
tar xzf $SRC/DEBIAN/struktur.tgz

#Für Hardy + co Sonderbehandlung
if [ "$1#" == "-older#" ]; then
    mv DEBIAN/control.older DEBIAN/control
else
    rm DEBIAN/control.older
fi

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
cp -a $SRC/dispatcher.f* usr/lib/lx-office-erp
cp $SRC/VERSION usr/lib/lx-office-erp
cp $SRC/index.html usr/lib/lx-office-erp
cp $SRC/config/lx_office.conf.default etc/lx-office-erp/lx_office.conf.default
cp $SRC/menu.ini usr/lib/lx-office-erp/menu.default
cp -a $SRC/css var/lib/lx-office-erp
cp -a $SRC/templates var/lib/lx-office-erp
cp -a $SRC/users var/lib/lx-office-erp
cp -a $SRC/xslt var/lib/lx-office-erp

cp -a $SRC/doc/* usr/share/doc/lx-office-erp/
cp -a $SRC/image/* usr/share/lx-office-erp/

#Ist nicht im Repository. Liegt bei sf
if [ "$1#" == "-older#" ]; then
    tar xzf $SRC/DEBIAN/lx-erp-perl-libs-compat-v2.tar.gz
fi

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
SIZE=`du -scb . | tail -n 1 | cut -f1`

#Controlfile updaten:
sed --in-place --expression "s/Installed-Size: 0/Installed-Size: $SIZE/g" DEBIAN/control
sed --in-place --expression "s/Version: 0/Version: $VER-$NR/g" DEBIAN/control
#Revisionsnummer evtl. von Hand eintragen

#Paket bauen:
cd ..
dpkg-deb --build lx-office-erp_$VER-$NR$1_all

echo "Done"
