
# Bemerkungen zum Vorlagensatz von
### © 2020 by Marei Peischl (peiTeX TeXnical Solutions)

## Aufbau:
Die Grundstruktur besteht je Dokumententyp aus einer Basisdatei und verschiedenen Setup-Dateien.

Die Basis wurde so überarbeitet, dass Dokumente nun generell auf der Dokumentenklasse *scrartcl.cls* basieren und das Paket *kiviletter.sty* benutzen.

Mandantenspezifische Konfiguration findet sich in der Datei *insettings.tex* und dem Ordner eines spezifischen Mandanten (default=*firma/*). 


### Struktur der Basisdatei (je Dokumententyp eine)
	1. Dokumentenklasse
	2. *kiviletter.sty*
	3. Einstellungen, die über Variablen gesetzt werden: Mandant, Währung, Sprache
	4. `\input{insettings.tex}` Anteil der spezifischen Anpassungen, die von den Variablen unter 2. abhängig sind. Geladen werden darin die Dateien:
		- Sprache: lädt die entsprechende Sprachdatei, falls DE -> *deutsch.tex*, falls EN *englisch.tex* und setzt die babel Optionen. Die Datei enthält Übersetzungen von Einzelbegriffen und Textbausteinen.
		- Lädt die Konfigurationsdatei, ohne spezielle Mandanten ist der Suchpfad zur Konfiguration der Unterordner *firma/*
			* Lädt die Datei *ident.tex*, sowie die Abbildung Briefkopf.
		
Mandanten / Firma:
    Um gleiche Vorlagen für verschiedene Firmen verwenden zu können, wird je
    nach dem Wert der Kivitendo-Variablen <%kivicompany%> ein
    Firmenverzeichnis ausgewählt (siehe 'insettings.tex'), in dem Briefkopf,
    Identitäten und Währungs-/Kontoeinstellungen hinterlegt sind.
    <%kivicompany%> enthält den Namen des verwendeten Mandantendaten.
    Ist kein Firmenname eingetragen, so wird das
    generische Unterverzeichnis 'firma' verwendet.

Identitäten:
    In jedem Firmen-Unterverzeichnis soll eine Datei 'ident.tex'
    vorhanden sein, die mit \newcommand Werte für \telefon, \fax,
    \firma, \strasse, \ort, \ustid, \email und \homepage definiert.

Währungen / Konten:
    Für jede Währung (siehe 'insettings.tex') soll eine Datei vorhanden
    sein, die das Währungssymbol (\currency) und folgende Angaben für
    ein Konto in dieser Währung enthält \kontonummer, \bank,
    \bankleitzahl, \bic und \iban.
    So kann in den Dokumenten je nach Währung ein anderes Konto
    angegeben werden.
    Nach demselben Schema können auch weitere, alternative Bankverbindungen
    angelegt werden, die dann in insettings.tex als Variable im
    unteren Abschnitt der Datei 'insettings.tex', Kommentar Fußzeile
    (cfoot) eingefügt werden.
   Briefbogen/Logos:
    Eine Hintergrundgrafik oder ein Logo kann in Abhängigkeit vom
    Medium (z.B. nur beim Verschicken mit E-Mail) eingebunden
    werden. Dies ist im Moment auskommentiert.
    
    Desweiteren sind (auskommentierte) Beispiele enthalten für eine
    Grafik als Briefkopf, nur ein Logo, oder ein komplettes DinA4-PDF
    als Briefpapier.
    
    Fusszeile:
    Die Tabelle im Fuß verwendet die Angaben aus firma/ident.tex und
    firma/*_account.tex.
        
## Tabellen:


 Quickstart (wo kann was angepasst werden?):
    insettings.tex : Pfad zu Angaben über Mandanten (default: firma)
                     Logo/Briefpapier
                     Layout der Kopf/Fußzeile
    firma/*        : Angaben über Mandanten
 Es muß mindestens eine Sprache angelegt werden!
    deutsch.tex    : Textschnipsel für Deutsch
                     Dafür eine Sprache mit Vorlagenkürzel DE anlegen
    english.tex    : Textschnipsel für Englisch
                     Dafür eine Sprache mit Vorlagenkürzel EN anlegen

