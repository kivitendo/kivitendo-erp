#!/bin/bash
# e = exit on error
set -e
# x = xtrace
#set -x

FEHLER="Achtung!! Es hat ein Problem gegeben"
ERRCNT=0
source /usr/share/debconf/confmodule

#Als root anmelden
if [ `id -u` -gt 0 ]; then echo "Bitte als root anmelden"; exit 1; fi
POSTGRESQL=`dpkg -l | grep -E "postgresql-[0-9]" | cut -d" " -f3 | sort -r | head -1 -`

#Datei plpgsql.so suchen
#Mit Paketmanager  suchen
if [ "$POSTGRESQL#" == "#" ]; then
    echo $FEHLER
    echo Keine PostgreSQL mit Paketmanager installiert
    echo Datenbank bitte manuell einrichten.
    exit 0
else
   PLPGSQL=`dpkg -L $POSTGRESQL | grep plpgsql.so `
fi

if [ "$PLPGSQL#" == "#" ]; then
    #Probleme mit Paketmanager, dann zunaechst mit locate, geht schneller
    updatedb
    tmp=`locate plpgsql.so 2>/dev/null`
    PLPGSQL=`echo $tmp | cut -d " " -f 1`
fi
if [ "$PLPGSQL#" == "#" ]; then
    #noch nicht gefunden, also mit find suchen
    tmp=`find /usr/lib -name  plpgsql.so -type f`
    PLPGSQL=`echo $tmp | cut -d " " -f 1`
fi	
if [ "$PLPGSQL#" == "#" ]; then
    echo $FEHLER
    echo  'plpgsql.so' nicht gefunden.
    echo Datenbank manuell einrichten.
    exit 0
fi

#Kann der User postgres die db erreichen
cnt=`ps aux | grep postgres | wc -l`
if [ $cnt -eq 0 ]; then
    echo $FEHLER
    echo Die postgreSQL-Datebbank ist nicht gestartet!
    echo Datenbank manuell einrichten.
    exit 0
fi

v8=`su postgres -c "echo 'select version()' | psql template1 2>/dev/null | grep -E "[Ss][Qq][Ll][[:space:]]+8\.[2-9]\.[0-9]" | wc -l"`
if [ $v8 -eq 0 ]; then 
    echo $FEHLER
    echo Datenbank Version 8x konnte erreicht werden.
    exit 0
fi

echo "CREATE FUNCTION plpgsql_call_handler() RETURNS language_handler" > lxdbinst.sql
echo "AS '$PLPGSQL', 'plpgsql_call_handler'" >> lxdbinst.sql
echo "LANGUAGE c;" >> lxdbinst.sql
echo "CREATE PROCEDURAL LANGUAGE plpgsql HANDLER plpgsql_call_handler;" >> lxdbinst.sql

#writeln 2 1 Datenbankbenutzer einrichten
LXOUSER="lxoffice"
db_get lx-office-erp/lx-office-erp-user-postgresql-password
USRPWD="$RET"

echo "CREATE USER $LXOUSER with CREATEDB ;" >> lxdbinst.sql
echo "ALTER USER $LXOUSER PASSWORD '$USRPWD';" >> lxdbinst.sql
echo "UPDATE pg_language SET lanpltrusted = true WHERE lanname = 'plpgsql';" >> lxdbinst.sql

su postgres -c "psql template1 < lxdbinst.sql"

echo "Fehlermeldungen die 'already exists' enthalten koennen ignoriert werden"

#writeln 12 1 Datenbankberechtigung einrichten
PGHBA=`find /etc/postgresql -name pg_hba.conf -type f | sort -r | head -1 -`
if [ "$PGHBA#" == "#" ] ; then
   PGHBA=`find /var/lib -name  pg_hba.conf -type f | sort -r | head -1 -`
fi

if [ "$PGHBA#" == "#" ]; then
    echo $FEHLER
    echo 'pg_hba.conf' nicht gefunden.
    echo "Berechtigungen bitte selber einrichten"
    ERRCNT=1
fi

cnt=`grep $LXOUSER $PGHBA | wc -l `

if [ $cnt -eq 0 ]; then 
    mv $PGHBA  $PGHBA.org
    echo "local   all         $LXOUSER                                           password" > $PGHBA
    echo "host    all         $LXOUSER      127.0.0.1         255.255.255.255    password" >> $PGHBA
    cat $PGHBA.org >> $PGHBA
fi 

CONFDIR=`dirname $PGHBA`

#postgresql.conf anpassen, liegt vermutlich im gleichen Verzeichnis wie pg_hba.conf
if ! [ -f $CONFDIR/postgresql.conf ]; then
    echo $FEHLER
    echo 'postgresql.conf' nicht gefunden.
    echo PostgreSQL selber konfigurieren
    ERRCNT=1
fi

mv $CONFDIR/postgresql.conf $CONFDIR/postgresql.conf.org
#Bei der V8.x OID einschalten.
sed 's/^.*default_with_oids.*/default_with_oids = true/i' $CONFDIR/postgresql.conf.org > $CONFDIR/postgresql.conf
cnt=`grep default_with_oids $CONFDIR/postgresql.conf | wc -l`
if [ $cnt -eq 0 ]; then
	cp $CONFDIR/postgresql.conf.org $CONFDIR/postgresql.conf
	echo "default_with_oids = true" >> $CONFDIR/postgresql.conf
fi

 
PGSQL=`ls -r1 /etc/init.d/postgres*  | head -1 -`

#writeln 18 1 Datenbank neu starten
$PGSQL reload

if [ $ERRCNT -gt 0 ]; then
    echo $FEHLER
    echo Das betrifft aber nicht die Lx-Office Installation
    echo sondern die Konfiguration der Datenbank.
    echo $POSTGRESQL , $PGHBA , $CONFDIR/postgresql.conf ??
    sleep 10
fi
