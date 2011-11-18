#!/bin/bash

# Ein Script, das demonstriert, wie sich CSV-Dateien über die
# Kommandozeile importieren lassen. Dabei gibt es zwei Orte, an denen
# das Script angepasst werden muss. Diese sind entsprechend mit
# Kommentaren versehen.
#
# Der Aufruf erfolgt mit einem Parameter: dem Dateinamen der
# CSV-Datei. Als Ausgabe erscheint bei Erfolg gar nichts (und
# Exit-Code 0). Im Fehlerfall werden eine Meldung und der Name einer
# temporären Datei ausgegeben, in der der HTML-Code der Fehlermeldung
# sichtbar ist. Exit-Code ist dann 2.

# ---- Logindaten und URL anpassen: ----
login=MyLxOfficeUserName
password=MySecretPassword
url='https://localhost/lx-office-erp/controller.pl'

function fail {
  echo "$@"
  exit 1
}

test -z $1 && fail "Kein CSV-Dateiname angegeben."
test -f $1 || fail "Datei '$1' nicht gefunden."
file="$1"

function do_curl {
  local action="$1"

  # ---- Hier ebenfalls die Parameter anpassen, falls notwendig. ----
  # Die anpassbaren Parameter und ihre Werte sind:

  # Allgemeine Parameter für alle importierbaren Sachen:

  #   "profile.type": zu importierende Objekte: "parts": Artikel;
  #   "customers_vendors": Kunden/Lieferanten; "contacts":
  #   Ansprechpersonen; "addresses": Lieferanschriften

  #   "escape_char": "quote", "singlequote" oder das Escape-Zeichen
  #   selber

  #   "quote_char": die gleichen Optionen wie "escape_char"

  #   "sep_char": "comma", "semicolon", "space", "tab" oder das
  #   Trennzeichen selber

  #   "settings.numberformat": "1.000,00", "1000,00", "1,000.00",
  #   "1000.00"

  #   "settings.charset": Name eines Zeichensatzes. Meist "CP850" oder
  #   "UTF-8".

  #   "settings.duplicates": Doublettencheck; "no_check", "check_csv",
  #   "check_db"

  # Parameter für Artikel:

  #   "settings.default_buchungsgruppe": Standard-Buchungsgruppe;
  #   Datenbank-ID einer Buchungsgruppe

  #   "settings.apply_buchungsgruppe": Buchungsgruppe wo anwenden:
  #   "never", "all", "missing"

  #   "settings.parts_type": Artikeltyp: "part", "service", "mixed"

  #   "settings.article_number_policy": Artikel mit existierender
  #   Artikelnummer: "update_prices", "insert_new"

  #   "settings.sellprice_places": Anzahl Nachkommastellen
  #   Verkaufspreise

  #   "settings.sellprice_adjustment": Wert für Verkaufspreisanpassung

  #   "settings.sellprice_adjustment_type": Art der
  #   Verkaufspreisanpassung; "percent", "absolute"

  #   "settings.shoparticle_if_missing": Shopartikel setzen falls
  #   fehlt: "1", "0"

  # Parameter für Kunden/Lieferanten:

  #   "settings.table": Zieltabelle: "customer", "vendor"

  # Parameter für Ansprechpartner:
  #   Nur die Standard-Parameter von oben

  # Parameter für Lieferanschriten:
  #   Nur die Standard-Parameter von oben

  curl \
    --silent --insecure \
    -F 'action=CsvImport/dispatch' \
    -F "${action}=1" \
    -F 'escape_char=quote' \
    -F 'profile.type=parts' \
    -F 'quote_char=quote' \
    -F 'sep_char=semicolon' \
    -F 'settings.apply_buchungsgruppe=all' \
    -F 'settings.article_number_policy=update_prices' \
    -F 'settings.charset=CP850' \
    -F 'settings.default_buchungsgruppe=395' \
    -F 'settings.duplicates=no_check' \
    -F 'settings.numberformat=1.000,00' \
    -F 'settings.parts_type=part' \
    -F 'settings.sellprice_adjustment=0' \
    -F 'settings.sellprice_adjustment_type=percent' \
    -F 'settings.sellprice_places=2' \
    -F 'settings.shoparticle_if_missing=0' \
    -F "login=${login}" \
    -F "password=${password}" \
    -F "file=@${file}" \
    ${url}
}

tmpf=$(mktemp)
do_curl 'action_test'  > $tmpf

if grep -q -i 'es wurden.*objekte gefunden, von denen.*' $tmpf; then
  rm $tmpf
  do_curl 'action_import' > $tmpf
  if grep -i 'von.*objekten wurden importiert' $tmpf ; then
    rm $tmpf
  else
    echo "Import schlug fehl. Ausgabe befindet sich in ${tmpf}"
    exit 2
  fi
else
  echo "Test-Import nicht OK. Ausgabe befindet sich in ${tmpf}"
  exit 2
fi
