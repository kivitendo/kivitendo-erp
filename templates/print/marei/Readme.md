# Bemerkungen zum Vorlagensatz
### © 2020–2021 by Marei Peischl (peiTeX TeXnical Solutions)

Über die in diesem Dokument hinausgehende Konfigurationsoptionen des Paketes *kiviletter.sty* sind dokumentiert unter
https://peitex.de/materialien/2023-08-04_kivitendo/kiviletter-doc.pdf

## Quickstart (wo kann was angepasst werden?):

  * insettings.tex : Pfad zu Angaben über Mandanten (default: firma)
                     Logo/Briefpapier
                     Layout der Kopf/Fußzeile
                     innerhalb dieser Datei werden auch die folgenden Dateien geladen:
                     firma/ident.tex        : Angaben über Mandanten
                     firma/<währungskürzel>_account.tex

* Es muß mindestens eine Sprache angelegt werden!
  -  deutsch.tex    : Textschnipsel für Deutsch
                      Dafür eine Sprache mit Vorlagenkürzel DE anlegen
  -  english.tex    : Textschnipsel für Englisch
                      Dafür eine Sprache mit Vorlagenkürzel EN anlegen



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
   - Lädt die Datei *ident.tex*, sowie die Abbildung Briefkopf.

#### Mandanten / Firma:

Um gleiche Vorlagen für verschiedene Firmen verwenden zu können, wird je
nach dem Wert der Kivitendo-Variablen `<%kivicompany%>` ein
Firmenverzeichnis ausgewählt (siehe *insettings.tex'), in dem Briefkopf,
Identitäten und Währungs-/Kontoeinstellungen hinterlegt sind.
`<%kivicompany%>` enthält den Namen des verwendeten Mandantendaten.
Ist kein Firmenname eingetragen, so wird das
generische Unterverzeichnis *firma* verwendet.

#### Identitäten:

In jedem Firmen-Unterverzeichnis soll eine Datei *ident.tex*
vorhanden sein, die mit `\newcommand` Werte für \telefon, `\fax`,
`\firma`, `\strasse`, `\ort`, `\ustid`, `\email` und `\homepage` definiert.

#### Währungen / Konten:
Für jede Währung (siehe *insettings.tex*) soll eine Datei vorhanden
sein, die das Währungssymbol (`\currency`) und folgende Angaben für
ein Konto in dieser Währung enthält `\kontonummer`, `\bank`,
`\bankleitzahl`, `\bic` und `\iban`.
So kann in den Dokumenten je nach Währung ein anderes Konto
angegeben werden.
Nach demselben Schema können auch weitere, alternative Bankverbindungen
angelegt werden, die dann in *insettings.tex* als Variable in der Fußzeile eingefügt werden.
Als Fallback (falls kivitendo keine Währung an das Druckvorlagen-System übergibt)
ist Euro eingestellt. Dies lässt sich in der *insettings.tex* über das optionale Argument
von `\setupCurrencyConfig` anpassen, z.B.

```
\setupCurrencyConfig[chf]{\identpath}{\lxcurrency}
```
für Schweizer Franken als Standardwährung.

#### Briefbogen/Logos:
Eine Hintergrundgrafik oder ein Logo kann in Abhängigkeit vom
Medium (z.B. nur beim Verschicken mit E-Mail) eingebunden
werden.

Desweiteren sind (auskommentierte) Beispiele enthalten für eine
Grafik als Briefkopf, nur ein Logo, oder ein komplettes DinA4-PDF
als Briefpapier.

Absolute Positionierung innerhalb des Brief-Layouts ist über die entsprechende Dokumentation des scrlayer-Paketes möglich.
Da die Voreinstellungen bereits einige Sonderfälle automatisch berücksichtigen ist mit den Anpassungen Vorsicht geboten.
Sämtliche Einstellungen sollten jedoch außerhalb der *.sty-Dateien vorgenommen werden.
Anpassungen der insettings.tex betreffen hierbei alle Mandanten. Mandantenspezifische Einstellung sind über die zugehörige Konfigurationsdatei möglich.
In diesem Fall kann zum Ende der insettings eine weitere Konfigurationsdatei über die Verwendung von \identpath geladen werden. Ein Beispiel ist in der insettings.tex enthalten.

#### Fußzeile:
Die Tabelle im Fuß verwendet die Angaben aus *firma/ident.tex* und
*firma/*_account.tex*. Ihre Struktur wird in der *insettings.tex* definiert.

#### Seitenstil/Basislayout:
Das Seitenlayout wird über scrlayer-scrpage bestimmt. Es existieren in der Datei *insettings.tex* einige Hinweise zu den Anpassungen. Die Basiskonfiguration ist ebenfalls dort eingetragen.

Die Kopfzeile unterscheidet sich von Dokumententyp zu Dokumententyp leicht, da diese über Datenbankvariablen befüllt wird. Hierfür wird das Makro `\ourhead` definiert. Diese Definition kann ebenfalls über die *insettings.tex* geändert werden.

### Tabellen:

Die Tabellenstruktur wurde komplett überarbeitet. Der Vorlagensatz verfügt über Tabellen, die automatisch die Breite der Textbreite anpassen und zusätzlich Seitenumbrüche erlauben.

#### SimpleTabular

Der einfache Tabellentyp ist die Umgebung `SimpleTabular`. die ist eine Tabelle basieren auf dem xltabular-Paket, die die sich der Textbreite anpasst. Sie wird in den Dateien *zahlungserinnerung_invoice.tex*, *zahlungserinnerung.tex* und *statement.tex* verwendet.

Sie verfügt über ein optionales Argument um die Spaltenkonfiguration und die Kopfzeile anzupassen. Die Voreinstellung (also ohne optionales Argument) entspricht der, der folgenden Angabe:

```
\begin{SimpleTabular}[colspec=rrX,headline={\bfseries\position & \bfseries\menge & \bfseries\bezeichnung}]

```

##### Tabellenkopfzeile
Die Kopfzeile wird über den Optionsschlüssel headline angepasst. Entsprechend dem LaTeX-Standard werden Tabellen Spalten mit `&` getrennt. `\bfseries` setzt den Tabellenkopf zusätzlich in Fettschrift.

##### Spaltenkonfiguration (fortgeschrittene Nutzer)
Die voreingestellte Spaltenkonfiguration entspricht `rrX`, also zwei rechtsbündigen Spalten und einer Blocksatzspalte, die die restliche Breite einnimmt. Soll von dieser Spaltenkonfiguration abgewichen werden, steht der Optionsschlüssel `colspec` zur Verfügung. Das folgende Beispiel tauscht die beiden rechtsbündigen Spalten in linksbündige:

```
\begin{SimpleTabular}[colspec=llX]

```
Als Spaltentypen sind Konfigurationen aus den folgenden Einträgen am sinnvollsten:
* `l`, `r`, `c`: Linksbündig, rechtsbündig, zentriert. Spaltenbreite passt sich dem Inhalt an.
* `X`: Blocksatz, Spaltenbreite füllt den übrigen Platz auf. Bei mehreren `X`-Spalten wird gleichmäßig aufgeteilt

Zusätzlich ist es möglich die Währung automatisch in der Spalte zu ergänzen.
Der Mechanismus ist so kontruiert, dass diese nicht in der Kopfzeile sondern lediglich in den Inhaltszeilen eingefügt wird.
In diesem Fall wird die Spaltenspezifikation durch `<{\tabcurrency}` ergänzt.
Eine rechtsbündige Spalte mit Währungsangabe wird somit durch `r<{\tabcurrency}` erzeugt.


#### PricingTabular

`PricingTabular` wurde entwickelt um Tabellen für Rechnungen vereinfacht erstellen zu können.
Die Voreinstellung verfügt über die Spalten `pos`, `id`, `desc`, `amount`, `price`, `pricetotal'.
Alle Spalten, außer der Spalte `desc` haben eine Feste Breite.

Die Einstellungen können Entweder als Optionales Argument zu `\begin{PricingTabular}[<Optionen>]` vorgenommen werden oder über das Makro `\SetupPricingTabular{<Optionen>}` für alle folgenden Umgebungen gesetzt werden.


###### Spaltenbreiten

Die Spaltenbreiten werden angepasst indem der Spaltenname verwendet wird.
Um die Positionsspalte zu ändern ist somit die Option `pos=<Breite>` notwendig.
Hier können alle Längenangaben verwendet werden, die LaTeX versteht. (cm, mm, em, ex, …)

Die Spaltenbreite der Spalte `desc` für die Artikelbeschreibung nimmt dabei jeweils den übrigen Platz ein.

##### Kopfzeileneinträge

Die Kopfzeileneinträge werden über die Option `<Spaltenname>/header=<Neue Beschriftung>` angepasst.
Vorbelegt ist die Konfiguration:

```
\SetupPricingTabular{
  pos/header=\position,
  id/header=\artikelnummer,
  desc/header=\bezeichnung,
  amount/header=\menge,
  price/header=\einzelpreis,
  pricetotal/header=\gesamtpreis
}
```

##### Farbige Tabellen
Versionen ab Juli 2021 enthalten die Möglichkeit farbige Tabellen zu nutzen.
Die Optionen für die `PricingTabular` Umgebung können wie folgt konfiguriert werden:
```
  color-rows=<true/false>,% false
  rowcolor-odd=<Farbname>,% black!10
  rowcolor-even=<Farbname>,% leer, also keine Farbbox wird erzeugt
  rowcolor-header=<Farbname>,% black!35
  rowcolor-total=<Farbname>,% black!35
```
Die Angabe hinter dem Kommentarzeichen entspricht der Voreinstellung.

Ab Dezember 2023 gibt es zudem die Option `color-only-structure=<true/false>`. Somit wird sichergestellt. dass wenn lediglich die Kopf-/oder Fußzeile eingefärbt werden sollen, alle Inhalte ohne zusäzlichen Aufwand umbrechbar bleiben. In diesem fall ist diese Option anstat `color-rows` zu aktivieren.

#### Trennlinien zwischen den Einträgen
Die Umgebung `PricingTabular` hat die möglichkeit horizontale Linien zwischen den Einträgen der `\FakeTable` einzuziehen.
Die einfachste Möglichkeit hierfür ist die Option hrule, sie setzt automatisch eine Linie der Dicke `\lightrulewidth`.
Da diese Linie formal nicht innerhalb der Tabelle platziert wird, können Linienmakros für Tabellen heir nicht verwendet werden.
Falls dennoch eine manuelle Anpassung der Maße notwendig ist, kann direkt der Code zur Erzeugung der Linie übergeben werden.
Die Option `hrule` entspricht der Angabe
```
  rowsep={
    \vskip\aboverulesep
    \hrule\@height\lightrulewidth
    \vskip\belowrulesep
  }
```
Es wird somit auch der Abstand davor und danach mit eingefügt. In Kombination mit Farbigen Tabellen ist hier vorsicht geboten, da der Abstand nicht mit zur farbigen Box gerechnet wird.


##### Reihenfolge/Anzahl der Spalten ändern

Die Reihenfolge wurde über die Option `columns` festgelegt.
Soll daher eine Tabelle mit nur drei Spalten und lediglich bestehend aus Produktnummer, Beschreibung und Menge genutzt werden, ist dies mit der Option `columns={id,desc,amount}` möglich.

Einzelne Spalten können auch über `<Spaltenname>=false` abgeschaltet werden. Dies ist z.B. dann hilfreich, wenn die Angabe einer Produktnummer aus platzgründen nicht sinnvoll ist (`id=false`).





