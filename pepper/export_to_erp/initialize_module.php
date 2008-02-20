<?php
// Filename: initialize_module.php
//
// Modul: Externes PhPepperShopmodul: log_viewer
//
// Autoren: José Fontanil & Reto Glanzmann
//
// Zweck: Definition des Log-Viewer Moduls
//
// Sicherheitsstatus:                     *** ADMIN ***
//
// Version: 1.5
//
// CVS-Version / Datum: $Id: initialize_module.php,v 1.1 2004/06/29 08:47:16 hli Exp $ $Dl: 26.05.04 11:20:43$
//
// -----------------------------------------------------------------------
// PhPepperShop Shopsystem
// Copyright (C) 2001-2004  Jose Fontanil, Reto Glanzmann
// 
// Lizenz
// ======
// 
// Die verbindliche PhPepperShop Lizenz ist in folgender 
// Datei definiert: PhPepperShop_license.txt
// -----------------------------------------------------------------------
// API Version der hier verwendeten PhPepperShop Modulschnittstelle:
$pps_module_api = '1.0';

// Informationen zu externen PhPepperShop Modulen:
// ===============================================
// Module bestehen meistens aus zwei Verzeichnissen: {shopdir}/shop/module/modul_name
// und {shopdir}/shop/Admin/module/modul_name. Im Admin-Modulverzeichnis muss mindestens
// diese Datei (initialize_module.php) vorhanden sein. Es gibt auch reine Administrations-
// module, welche nur Dateien im Admin-Unterverzeichnis haben und keine Dateien im kunden-
// seitigen Verzeichnis benoetigen.
// - Ein Modul kann aber ohne weiteres auch eigene Unterverzeichnisse besitzen, sowie auch
//   Submodule haben.
// - Damit Module Daten persistent speichern koennen, duerfen sie waehrend der Installation
//   eigene Tabellen erstellen und bestehende um eigene Attribute erweitern. Bei einer De-
//   installation werden diese Datenbankerweiterungen wieder entfernt.
// - User-Security Scripte befinden sich in {shopdir}/shop/module/modul_name,
//   die Admin-Security-Scripts befinden sich im Admin-Pendant.
// - Module koenne (zumindest im Moment) noch keine eigenen Interfaces haben.
// - Module koennen weitere Module als Voraussetzung angeben.

// Definition der Variablen:
// =========================
// Die weiter unten definierten Variablen dienen der Beschreibung des Moduls. Diese muss
// sehr ausfuehrlich sein, damit das automatisierte Installations- und Deinstallationsscript
// durchlaufen kann. Nomenklatur:
// x.) Bezeichnung    : Leitet eine weitere Definition ein. x ist eine Laufnummer
// ! Beschreibung     : Beschreibung umschreibt Hinweise zum Thema der Bezeichnung
// --> Einschraenkung : Mit --> werden ZWINGEND ZU BEFOLGENDE Einschraenkungen der Bezeichnung genannt

// --------------------------------------------------------------------------------------
// ******************************* DEFINITION DES MODULS *******************************
// --------------------------------------------------------------------------------------

//  1.) Name des Moduls (entspricht dem Verzeichnisname des Moduls)
//      --> Der Name eines externen PhPepperShop Moduls darf hoechstens 40 Zeichen lang sein.
//      --> Der Name muss mindestens 3 Zeichen lang sein.
//      --> Er darf NUR aus alphanummerischen Zeichen und dem Underscore Zeichen (_) bestehen.
//      --> Dieser Name ist gleichzeitig auch der Name des Verzeichnisses des Moduls.
$moduldef['modulname'] = 'export_to_erp';

// 2.) Bezeichnung des Moduls
//      ! Dies ist die Bezeichnung des Moduls und unterliegt somit weniger Restriktionen als der Modulname
//      --> Der Name darf hoechstens 40 Zeichen lang sein
//      --> Der Name muss mindestens 3 Zeichen lang sein.
$moduldef['modulbezeichnung'] = 'ERP Export';

// 3.) Versionschecknummern
//      ! Diese Nummern definieren die zu verwendende PhPepperShop Versionen. Die Versionisierung
//        ist wie folgt: Die erste und zweite Nummer (durch Punkt getrennt) ergeben ein Release.
//        Jedes unterstuetzte Release muss explizit angegeben werden. Die dritte (durch einen
//        Punkt getrennte Nummer (eigentlich ein String), definiert Versionen des Releases. Alle
//        Versionen eines Releases sind kompatibel, es sei denn man definiert auch die Versions-
//        Nummer, dann sind alle aelteren Versionen des angegebenen Releases inkompatibel.
//        Bsp. 1.4;1.5     = Das Modul ist kompatibel zu den Releases 1.4 und 1.5. Dies schliesst auch
//                           alle Versionen der beiden Releases mit ein: 1.4.003, 1.4.004, 1.5.1, ...
//        Bsp. 1.4.005;1.5 = Hier sind alle Versionen von 1.4 mit und nach 1.4.005 kompatibel und
//                           alle Versionen von 1.5.
//      ! Achtung: Man sollte keine zukuenftigen Releases angeben!
//      --> Einzelne Versionen via Strichpunkt getrennt eingeben.
$moduldef['versionschecknummern'] = '1.4.008;1.5';

//  4.) Kurzbeschreibung
//      ! Formatierungen sollen via HTML-Tags eingegeben werden.
$moduldef['kurzbeschreibung'] = 'Eportiert Kundendaten und Bestellungen f&uuml;r Lx-Office ERP.
				 Neukunden werden in der ERP angelegt und die ERP-KdNr in Kundendaten eingepflegt,
				 bei Bestandskunden werden die Kundendaten abgeglichen.
				 Das Feld "Bestellung_bezahlt" ist der Merker f&uuml;r neue Bestellungen.
                                ';

//  5.) Weiterfuehrender Link
//      ! Wenn dieser (optionale) Link angegeben ist, so kann der Shopadmin hier weitere Infos zum Modul holen.
//      --> Das Schema muss vor der URL angegeben werden (Schema = http:// oder https://, ...)
$moduldef['weitere_infos_link'] = 'http://www.lx-office.org/';

//  6.) Version dieses Moduls
$moduldef['modulversion'] = '0.3';

//  7.) Releasedatum dieser Modulversion
//      --> Format: TT.MM.JJJJ
$moduldef['releasedatum'] = '17.12.2004';

//  8.) Informationen zu den Entwicklern
//      ! Beispiel: José Fontanil <fontajos@phpeppershop.com>. Strings in <> werden als E-Mail angezeigt.
$moduldef['entwickler_infos'] = 'Holger Lindemann, Lx-System';

//  9.) Ist Submodul von
//      ! Hier kann man den Modulnamen (nicht die Modulbezeichnung!) des Hauptmoduls angeben, falls dieses
//        Modul hier ein Submodul des Hauptmoduls ist.
//      --> Der Name eines externen PhPepperShop Moduls darf hoechstens 40 Zeichen lang sein.
//      --> Der Name muss mindestens 3 Zeichen lang sein.
//      --> Er darf nur aus alphanummerischen Zeichen und dem Underscore Zeichen (_) bestehen.
//      --> Dieser Name ist gleichzeitig auch der Name des Verzeichnisses des HAUPTmoduls.
$moduldef['submodule_of'] = '';

// 10.) Fingerprint
//      ! Im Moment noch nicht benutzt - Spaeter wird hier ein MD5 Digest hinterlegbar sein, welcher dem
//        Shopadministrator erlaubt die Integritaet eines Moduls zu ueberpruefen.
//      --> MD5 Digest (32 Chars Laenge, Hexadezimales Alphabet)
$moduldef['fingerprint'] = '32fedef6229faab095a47718bac5d666';

// 11.) Unterstuetzte Locales (Sprachen und optional Laender) - dient (vorerst) nur zur Anzeige fuer den Shopadmin
//      --> Format: ISO-639-1 fuer alleinstehende Sprachen (Bsp. de;en;fr;sp;...)
//      --> Format: ISO-639-2 fuer Sprachen inkl. Laender (Bsp. de_CH;de_DE;en_GB;en_US)
//      --> Wenn das Modul weder Sprach-, noch Laenderabhaengig ist kann all angegeben werden.
//      --> Die einzelnen Angaben koennen Strichpunkt separiert eingegeben werden. ISO-639-1 und -2 koennen gemixt werden.
$moduldef['locales'] = 'all';

// 12.) Interfaces, bei welchen sich das Modul registrieren soll
//      ! Dies ist ein etwas komplexerer Eingabetyp - es ist ein mehrdimensionaler Array - mehr nicht.
//      ! Pro Interface, bei welchem sich das Modul registrieren will, sind vier Angaben noetig:
//        (1) Interface_ID, (2) Datei, worin sich die auszufuehrende Funktion befindet,
//        (3) Name der auszufuehrenden Funktion, (4) Filtertyp
//      --> Format: array('i_id'=>'w','file'=>'x','func'=>'y','filter'=>'z')
//          --> w = Interface_ID, Format: positive Integerzahl (max. Digits == 11)
//          --> x = Dateiname, Format: Dateiname.Extension (kein Pfad)
//          --> y = Funktionsname, Format: Name der Funktion ohne Klammern mit Argumenten
//          --> z = Filtertyp, Format: one_way oder filter
// Registrierung beim ersten Interface:
$moduldef['interfaces'] = array();

// 13.) Eigene Tabellen, welche angelegt werden sollen
//      ! Hier werden die eigens fuer dieses Modul zu erstellenden Tabellen angegeben
//      ! Wenn keine Tabellen erstellt werden muessen, einfach leerer Array definieren
//      --> Achtung: Eine Tabelle muss mindestens EIN Attribut besitzen, sonst wird sie nicht angelegt.
//      --> Format: array('table_name'=>'x','table_beschreibung'=>'y','attribute'=>z)
//          --> x = Name der Tabelle: MySQL Restriktionen (max. 64 Zeichen, keine Sonderzeichen, ...)
//          --> y = Beschreibung der Tabelle: Alphanummerische Zeichen, Kurzbeschrieb des Zwecks
//          --> z = Die Attribute der Tabelle, Format:
//                  array('name'=>a,'typ'=>b,'laenge'=>c,'zusatz'=>d,'null'=>e,'default'=>f,'extra'=>g,
//                        'primary'=>h,'index'=>i,'unique'=>j,'volltext'=>k,'beschreibung'=>l)
//                  --> a = Name des Attributs: (Alphanummerische Zeichen, siehe reservierte Woerter von MySQL)
//                  --> b = Typ: Datentyp dieses Tabellenattributs (z.B. int, varchar, text, ...)
//                  --> c = Laenge: Positive Integerzahl oder leer lassen (manchmal auch als maxlength interpretiert)
//                  --> d = Zusatz: '' | 'BINARY' | 'UNSIGNED' | 'UNSIGNED ZEROFILL'
//                  --> e = Null Setting: 'NULL | 'NOT NULL'
//                  --> f = Default: Defaultwert bei Neuerstellung in einer Zeile (max. Zeichenlaenge = 255)
//                  --> g = Extra: '' | 'auto_increment'
//                  --> h = Primary: '0' = ist NICHT Primary Key | '1' = IST Primary Key
//                  --> i = Index: '0' = Nein | '1' = Ja
//                  --> j = Unique: '0' = Nein | '1' = Ja
//                  --> k = Volltext Index: '0' = Nein | '1' = Ja (nicht bei allen Typen moeglich)
//                  --> l = Beschreibung: Wird nur hier und im Modulprozess verwendet (max. Chars = 255)
// Beschreibung der ersten eigenen Tabelle:
$moduldef['eigene_tabellen'] = array();

// 14.) Zu erweiternde, schon bestehende Tabellen
//      ! Hier werden die Tabellen beschrieben, welche schon existieren und durch weitere Attribute
//        erweitert werden sollen.
//      ! Wenn keine Tabellen erweitert werden sollen, einfach leerer Array definieren
//      --> Format: Dasselbe Format wie bei $moduldef['eigene_tabellen']. Die Beschreibung
//                  einer schon bestehenden Tabelle wird ignoriert, der Name muss aber stimmen.
$moduldef['erweiterte_tabellen'] = array();

// 15.) Submodule
//      ! Wenn dieses Modul aus mehreren weiteren Modulen besteht, so koennen diese hier angegeben werden.
//      ! Wenn keine Submodule existieren, einfach einen leeren String angeben.  (Strichpunkt getrennte Liste)
//      --> Format: 'submodul_name_1;submodul_name2;...;submodul_namex'
$moduldef['submodule'] = '';

// 16.) Vorausgesetzte Module
//      ! Hier werden Module angegeben, welche korrekt installiert vorhanden sein muessen, damit dieses
//        Modul ueberhaupt erst installiert wird. (Strichpunkt getrennte Liste)
//      ! Wenn keine solchen Module gibt, einfach einen leeren String uebergeben
//      --> Format: 'required_modul_name_1;required_modul_name2;...;required_modul_namex'
$moduldef['required_modules'] = '';

// 17.) Security ID
//      ! Mit der Security_ID kann man dem Modul den Zugang zu verschiedenen Interfaces sperren.
//        Auf diese Weise kann ein kompromittiertes Modul nur begrenzt Schaden anrichten.
//      ! Die niedrigste Stufe der Security_ID ist = 1, die höchste Stufe = 32768. Je hoeher die
//        angegebene Security_ID ist, desto höher ist auch die Zahl der erlaubten Interfaces
//      ! Welches Interface, welche minimale Security_ID erfordert um benutzt werden zu koennen,
//        ist in der Tabelle module_interfaces mit den Interfaceeintraegen ersichtlich.
//      --> Format: 'required_modul_name_1;required_modul_name2;...;required_modul_namex'
$moduldef['security_id'] = '1';

// 18.) Valid Hosts
//      ! Erweiterte Security wird es in der naechsten API-Version noch mit der valid_hosts Angabe geben.
//        Die Datenbank ist dafuer schon vorbereitet. (all = Alle Hosts, im Moment die Standardeinstellung)
//        Ausgewertet wird die Angabe aber noch nicht.
//      --> Format: all = Alle hosts | localhost = nur dieser Rechner | mehrere Rechner via ; getrennt angeben
$moduldef['valid_hosts'] = 'all';

// 19.) Name des Administrationsmenus
//      ! Im Administrationstool hat das Verwaltungsmenu dieses Moduls einen Namen, hier kann man
//        einen Namen definieren, wenn man keinen angibt, wird einfach die Modulbezeichnung verwendet
//      --> Format: Maximale Laenge 40 Zeichen, moeglichst keine Sonderzeichen verwenden
$moduldef['admin_menu_name'] = 'ERP Export';

// 20.) URL zur Datei, wo das Admin-Verwaltungsmenu liegt
//      ! Diese URL ist entweder absolut oder (besser) relativ zum {shopdir}/shop/Admin/module/modul_name Verzeichnis
//        Die hier angegebene Datei wird 'verlinkt' und mit dem in 'admin_menu_name' Namen versehen.
//        Info: Achtung: Jeder Link in dieser Datei muss folgende GET-Parameter mitgeben:
//        - darstellen=".$HTTP_GET_VARS['darstellen']
//        - installed_selection=".$HTTP_GET_VARS['installed_selection']
//        - backlink=".$HTTP_GET_VARS['backlink']
//      --> Format: URL
//$moduldef['admin_menu_link'] = 'show_log_viewer.php';
$moduldef['admin_menu_link'] = 'export_to_erp.php';

// 21.) URL zum Icon des Adminmenus
//      ! Diese URL ist relativ zum {shopdir}/shop/Admin/ Verzeichnis (sonst gibt es einen include-Fehler
//        Die hier angegebene Datei wird 'verlinkt' und mit dem in 'admin_menu_name' Namen versehen.
//      --> Format: URL
//      --> Format Icon: 48px x 48px, GIF oder PNG oder JPG.
$moduldef['admin_menu_img'] = 'modul_admin_img.gif';

// --------------------------------------------------------------------------------------
// ***************************** ENDE DEFINITION DES MODULS *****************************
// --------------------------------------------------------------------------------------


// Bitte unterhalb dieser Zeile keine Aenderungen mehr vornehmen.


// -----------------------------------------------------------------------
// Damit jedes andere Modul ueberpruefen kann ob dieses hier schon "included" ist
// wird folgende Vairable auf true gesetzt (Name = Ext. Modulname + Dateiname ohne .php)
$module_name_inkl_prefix = $module_modulname.'_initialize_module';
$$module_name_inkl_prefix = true;

// 'Mitsenden' der hier verwendeten API-Version
$moduldef['pps_module_api'] = $pps_module_api;

// Moduldefinitionsarray loeschen und somit den Speicher wieder freigeben

// End of file -----------------------------------------------------------
?>
