#!/bin/bash
versionDB=""
PS3="Bitte eine Datenbank auswählen: ";
db="";
function do_update {
	echo "Erstelle db-Backup von $db"
	pg_dump -U postgres $db > $db.sql
	echo "Start update"
	rc=`psql --quiet -t -A -U postgres $db  < $1`
	rc=`psql --quiet -t -A -U postgres $db  < liste.sql`
	echo $rc
}
database=`psql -t -A -U postgres -l`
echo "Folgende Datenbanken wurden gefunden:"
for i in $database; do
	dbx=`echo $i | cut -d "|" -f 1 `
	dbA=$dbx" "$dbA
done
select db in ${dbA[*]}; do
	if [ "!$db!" = "!!" ]; then echo "Falsche Eingabe"; 
	else break;
	fi
done
echo $db wird nun getestet
versionDB=`psql -t -A -U postgres $db  -c "select version from defaults" 2>/dev/null`;
if [ "$versionDB" = "2.1.11" ]; then
	echo $db ist die Version Lx-ERP 1.0.0
	do_update  update100-200.sql
	echo Update beendet.
	exit
elif [ "$versionDB" = "2.3.9" ]; then
	echo $db ist die Version SQL-Ledger 2.3.9
	do_update updateLedger-200.sql
	echo Update beendet.
	exit
elif [ "$versionDB" = "1.0.0" ]; then
	echo $db ist die Version Lx-ERP 1.0.2/1.0.3
	do_update update10x-200.sql
	echo Update beendet.
	exit
else
	echo Diese Version wird nicht unterstützt!
fi