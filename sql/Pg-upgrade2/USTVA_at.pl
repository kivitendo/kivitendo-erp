# @tag: USTVA_at
# @description: USTVA Report Daten fuer Oesterreich. Vielen Dank an Gerhard Winkler..
# @depends: USTVA_abstraction
package SL::DBUpgrade2::USTVA_at;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  if (!$self->check_coa('Austria')) {
    print qq|Nichts zu tun in diesem Kontenrahmen.|;
    return 1;
  }

  if (!$self->is_coa_empty)  {
    print qq|Eine österreichische Datenbank in der bereits Buchungssätze enthalten sind, kann nicht aktualisiert werden.<br />
             Bitte eine neue Datenbank mit Kontenrahmen 'Austria' anlegen.|;
    return 1;
  }

  print qq|Eine leere Datenbank mit Kontenrahmen Österreich vorgefunden. <br />
           Die Aktualisierungen werden eingespielt...<br />
           <b>Achtung: Dieses Update ist ungetestet und bedarf weiterer Konfiguration</b>|;

  return
       $self->clear_tables('tax.report_variables', 'tax.report_headings',
                           'tax.report_categorys', 'taxkeys',
                           'tax',                  'chart',
                           'buchungsgruppen')
    && $self->do_copy_tax_report_structure()
    && $self->do_insert_chart()
    && $self->do_insert_tax()
    && $self->do_insert_taxkeys()
    && $self->do_insert_buchungsgruppen()
    ? 1 : 0;
}

sub clear_tables {
  my ($self, @clear) = @_;

  my @queries = (
      q{ DELETE FROM tax.report_categorys; },
      q{ DELETE FROM tax.report_headings;  },
      q{ DELETE FROM tax.report_variables; },
  );

  $self->db_query("DELETE FROM $_") for @clear;

  return 1;

}

sub do_copy_tax_report_structure {
  my ($self) = @_;

  my @queries = (
        "INSERT INTO tax.report_categorys (id, description, subdescription) VALUES (0, NULL, NULL)",
        "INSERT INTO tax.report_headings (id, category_id, type, description, subdescription) VALUES (0, 0, NULL, NULL, NULL)",
  );

  map({ $self->db_query($_); } @queries);


  my @copy_statements = (
      "INSERT INTO tax.report_variables (id, position, heading_id, description, dec_places, valid_from) VALUES (?, ?, ?, ?, ?, ?)",
  );


  my @copy_data = (
    [
      "1;000;0;a) Gesamtbetrag der Bemessungsgrundlage für Lieferungen und sonstige Leistungen (ohne den nachstehend angeführten Eigenverbrauch) einschließlich Anzahlungen (jeweils ohne Umsatzsteuer);2;1970-01-01",
      "2;001;0;zuzüglich Eigenverbrauch (§1 Abs. 1 Z 2, § 3 Abs. 2 und § 3a Abs. 1a);2;1970-01-01",
      "3;021;0;abzüglich Umsätze für die die Steuerschuld gemäß § 19 Abs. 1 zweiter Satz sowie gemäß § 19 Abs. 1a, Abs. 1b, Abs. 1c auf den Leistungsempfänger übergegangen ist.;2;1970-01-01",
      "4;011;0;a) §6 Abs. 1 Z 1 iVm § 7 (Ausfuhrlieferungen);2;1970-01-01",
      "5;012;0;b) §6 Abs. 1 Z 1 iVm § 8 (Lohnveredelungen);2;1970-01-01",
      "6;015;0;c) §6 Abs. 1 Z 2 bis 6 sowie § 23 Abs. 5 (Seeschifffahrt, Luftfahrt, grenzüberschreitende Personenbeförderung, Diplomaten, Reisevorleistungen im Drittlandsgebiet usw.);2;1970-01-01",
      "7;017;0;d) Art. 6 Abs. 1 (innergemeinschaftliche Lieferungen ohne die nachstehend gesondert anzuführenden Fahrzeuglieferungen);2;1970-01-01",
      "8;018;0;e) Art. 6 Abs. 1, sofern Lieferungen neuer Fahrzeuge an Abnehmer ohne UID-Nummer bzw. durch Fahrzeuglieferer gemäß Art. 2 erfolgen.;2;1970-01-01",
      "9;019;0;a) § 6 Abs. 1 Z 9 lit. a (Grundstücksumsätze);2;1970-01-01",
      "10;016;0;b) §6 Abs. 1 Z 27 (Kleinunternehmer);2;1970-01-01",
      "11;020;0;c) § 6 Abs. 1 Z ___ (übrige steuerfreie Umsätze ohne Vorsteuerabzug);2;1970-01-01",
      "12;022_links;0;20% Nominalsteuersatz;2;1970-01-01",
      "13;022_rechts;0;20% Nominalsteuersatz;2;1970-01-01",
      "14;029_links;0;10% ermäßigter Steuersatz;2;1970-01-01",
      "15;029_rechts;0;10% ermäßigter Steuersatz;2;1970-01-01",
      "16;025_links;0;12% für Weinumsätze durch landwirtschaftliche Betriebe;2;1970-01-01",
      "17;025_rechts;0;12% für Weinumsätze durch landwirtschaftliche Betriebe;2;1970-01-01",
      "18;035_links;0;16% für Jungholz und Mittelberg;2;1970-01-01",
      "19;035_rechts;0;16% für Jungholz und Mittelberg;2;1970-01-01",
      "20;052_links;0;10% Zusatzsteuer für pauschalierte land- und forstwirtschaftliche Betriebe;2;1970-01-01",
      "21;052_rechts;0;10% Zusatzsteuer für pauschalierte land- und forstwirtschaftliche Betriebe;2;1970-01-01",
      "22;038_links;0;8% Zusatzsteuer für pauschalierte land- und forstwirtschaftliche Betriebe;2;1970-01-01",
      "23;038_rechts;0;8% Zusatzsteuer für pauschalierte land- und forstwirtschaftliche Betriebe;2;1970-01-01",
      "24;056;0;Steuerschuld gemäß § 11 Abs. 12 und 14, § 16 Abs. 2 sowie gemäß Art. 7 Abs. 4;2;1970-01-01",
      "25;057;0;Steuerschuld gemäß § 19 Abs. 1 zweiter Satz, § 19 Abs. 1c sowie gemäß Art. 25 Abs. 5;2;1970-01-01",
      "26;048;0;Steuerschuld gemäß § 19 Abs. 1a (Bauleistungen);2;1970-01-01",
      "27;044;0;Steuerschuld gemäß § 19 Abs. 1b (Sicherungseigentum, Vorbehaltseigentum und Grundstücke im Zwangsversteigerungsverfahren);2;1970-01-01",
      "28;070;0;Gesamtbetrag der Bemessungsgrundlagen für innergemeinschaftliche Erwerbe;2;1970-01-01",
      "29;071;0;Davon Steuerfrei gemäß Art. 6 Abs 2;2;1970-01-01",
      "30;072_links;0;20% Nominalsteuersatz;2;1970-01-01",
      "31;072_rechts;0;20% Nominalsteuersatz;2;1970-01-01",
      "32;073_links;0;10% ermäßigter Steuersatz;2;1970-01-01",
      "33;073_rechts;0;10% ermäßigter Steuersatz;2;1970-01-01",
      "34;075_links;0;16% für Jungholz und Mittelberg;2;1970-01-01",
      "35;075_rechts;0;16% für Jungholz und Mittelberg;2;1970-01-01",
      "36;076;0;Erwerbe gemäß Art. 3 Abs. 8 zweiter Satz, die im Mitgliedstaat des Bestimmungslandes besteuert worden sind;2;1970-01-01",
      "37;077;0;Erwerbe gemäß Art. 3 Abs. 8 zweiter Satz, die gemäß Art. 25 Abs. 2 im Inland als besteuert gelten;2;1970-01-01",
      "38;060;0;Gesamtbetrag der Vorsteuern (ohne die nachstehend gesondert anzuführenden Beträge);2;1970-01-01",
      "39;061;0;Vorsteuern betreffend die entrichtete Einfuhrumsatzsteuer (§12 Abs. 1 Z 2 lit.a);2;1970-01-01",
      "40;083;0;Vorsteuern betreffend die am Abgabenkonto verbuchte Einfuhrumsatzsteuer (§12 Abs. 1 Z 2 lit.b);2;1970-01-01",
      "41;065;0;Vorsteuern aus dem innergemeinschaftlichen Erwerb;2;1970-01-01",
      "42;066;0;Vorsteuern betreffend der Steuerschuld gemäß § 19 Abs. 1c sowie gemäß Art. 25 Abs. 5;2;1970-01-01",
      "43;082;0;Vorsteuern betreffend der Steuerschuld gemäß § 19 Abs. 1a (Bauleistungen);2;1970-01-01",
      "44;087;0;Vorsteuern betreffend die Steuerschuld gemäß § 19 Abs. 1b (Sicherungseigentum, Vorbehaltseigentum und Grundstücke im Zwangsversteigerungsverfahren);2;1970-01-01",
      "45;064;0;Vorsteuern gemäß §12 Abs. 16 und Vorsteuern für innergemeinschaftliche Lieferungen neuer Fahrzeuge von Fahrzeuglieferanten gemäß Art. 2;2;1970-01-01",
      "46;062;0;Davon gemäß § 12 Abs. 3 iVm Abs. 4 und 5;2;1970-01-01",
      "47;063;0;Berichtigung gemäß § 12 Abs. 10 und 11;2;1970-01-01",
      "48;067;0;Berichtigung gemäß § 16;2;1970-01-01",
      "49;090;0;Sonstige Berichtigungen;2;1970-01-01",
      "50;095;0;Zahllast/Gutschrift;2;1970-01-01",
    ],
  );

  for my $statement ( 0 .. $#copy_statements ) {
    my $query = $copy_statements[$statement];
    my $sth   = $self->dbh->prepare($query) || $self->db_error($query);

    for my $copy_line ( 0 .. $#{$copy_data[$statement]} ) {
      #print $copy_data[$statement][$copy_line] . "<br />"
      $sth->execute(split m/;/, $copy_data[$statement][$copy_line], -1) || $self->db_error($query);
    } #/
    $sth->finish();
  }
  return 1;
}

sub do_insert_chart {
  my ($self) = @_;

  my @copy_statements = (
      "INSERT INTO chart VALUES (1, '0000', 'AUFWENDUNGEN FÜR INGANGSETZEN UND ERWEITERN DES BETRIEBES', 'H', 'A', '', '00', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.276724', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (2, '0010', 'Firmenwert', 'A', 'A', 'AP_amount', '015', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.28365', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (3, '0100', 'IMMATERIELLE VERMÖGENSGEGENSTÄNDE', 'H', 'A', '', '01', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.288542', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (4, '0110', 'Rechte', 'A', 'A', 'AP_amount', '011', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.291937', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (5, '0200', 'GRUNDSTÜCKE', 'H', 'A', '', '02-03', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.294929', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (6, '0210', 'unbebaute Grundstücke', 'A', 'A', 'AP_amount', '020', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.297958', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (7, '0220', 'bebaute Grundstücke', 'A', 'A', 'AP_amount', '021', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.300987', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (8, '0229', 'kum. Abschreibung bebaute Grundstücke', 'A', 'A', '', '039', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.304114', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (10, '0410', 'Maschinen', 'A', 'A', 'AP_amount', '041', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.312216', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (11, '0419', 'kum. Abschreibung Maschinen', 'A', 'A', '', '069', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.316198', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (12, '0500', 'FAHRZEUGE', 'H', 'A', '', '06', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.319978', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (13, '0510', 'Fahrzeuge', 'A', 'A', 'AP_amount', '063', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.323002', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (14, '0519', 'kum. Abschreibung Fahrzeuge', 'A', 'A', '', '069', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.326041', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (15, '0600', 'BETRIEBS- UND GESCHÄFTSAUSSTATTUNG', 'H', 'A', '', '06', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.330691', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (16, '0620', 'Büroeinrichtungen', 'A', 'A', 'AP_amount', '066', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.33373', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (17, '0625', 'kum. Abschreibung Betriebs- und Geschäftsausstattung', 'A', 'A', '', '069', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.336939', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (18, '0700', 'GELEISTETE ANZAHLUNGEN', 'H', 'A', '', '07', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.340614', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (19, '0800', 'FINANZANLAGEN', 'H', 'A', '', '08-09', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.3436', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (20, '0810', 'Beteiligungen', 'A', 'A', 'AP_amount', '081', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.346638', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (21, '0820', 'Wertpapiere', 'A', 'A', 'AP_amount', '080', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.351452', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (22, '1100', 'ROHSTOFFE', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.354419', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (23, '1120', 'Vorräte - Rohstoffe', 'A', 'A', 'IC', '110-119', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.357447', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (24, '1200', 'BEZOGENE TEILE', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.360423', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (25, '1220', 'Vorräte - bezogene Teile', 'A', 'A', 'IC', '120-129', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.363627', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (26, '1300', 'HILFS- UND BETRIEBSSTOFFE', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.368083', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (27, '1320', 'Hilfsstoffe', 'A', 'A', 'IC', '130-134', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.372229', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (28, '1350', 'Betriebssstoffe', 'A', 'A', 'IC', '135-139', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.375303', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (29, '1400', 'UNFERTIGE ERZEUGNISSE', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.378277', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (30, '1420', 'Vorräte - unfertige Erzeugnisse', 'A', 'A', 'IC', '140-149', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.381463', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (31, '1500', 'FERTIGE ERZEUGNISSE', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.384434', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (34, '1540', 'Vorräte - Gruppe C', 'A', 'A', 'IC', '150-159', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.395426', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (35, '1600', 'WAREN', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.39872', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (36, '1700', 'NOCH NICHT ABGERECHNETE LEISTUNGEN', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.401807', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (37, '1800', 'GELEISTETE ANZAHLUNGEN', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.404851', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (38, '1900', 'WERTBERICHTIGUNGEN', 'H', 'A', '', '1', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.409611', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (39, '2000', 'FORDEUNGEN AUS LIEFERUNGEN UND LEISTUNGEN', 'H', 'A', '', '2', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.412995', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (41, '2019', 'Wertberichtigung uneinbringliche Forderungen', 'A', 'A', '', '20-21', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.420867', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (42, '2300', 'SONSTIGE FORDERUNGEN', 'H', 'A', '', '2', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.423897', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (43, '2320', 'sonstige Forderungen', 'A', 'A', 'AP_amount', '23-24', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.428868', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (44, '2500', 'FORDERUNGEN AUS ABGABENVERRECHNUNG', 'H', 'A', '', '2', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.432042', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (46, '2600', 'WERTPAPIERE UND ANTEILE', 'H', 'A', '', '2', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.438205', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (47, '2620', 'Wertpapiere Umlaufvermögen', 'A', 'A', 'AP_amount', '26', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.441382', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (48, '2700', 'KASSABESTAND', 'H', 'A', '', '2', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.444391', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (50, '2800', 'SCHECKS, GUTHABEN BEI KREDITINSTITUTEN', 'H', 'A', '', '2', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.45237', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (53, '3100', 'LANGFRISTIGE VERBINDLICHKEITEN', 'H', 'L', '', '3', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.461985', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (54, '3110', 'Bank Verbindlichkeiten', 'A', 'L', '', '31', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.465019', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (56, '3300', 'VERBINDLICHKEITEN AUS LIEFERUNGEN UND LEISTUNGEN', 'H', 'L', '', '33', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.474305', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (58, '3500', 'VERBINDLICHKEITEN FINANZAMT', 'H', 'L', '', '35', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.480487', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (105, '7611', 'Reinigungsmaterial', 'A', 'E', 'AP_amount', '', 9, NULL, 11, 3, NULL, false, '2006-01-28 18:22:52.649072', '2006-02-03 15:26:38.591173', NULL, NULL);",
      "INSERT INTO chart VALUES (163, '7340', 'Reisekosten', 'A', 'E', 'AP_amount', '', 9, NULL, NULL, 3, NULL, false, '2006-02-03 15:38:11.636188', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (74, '4600', 'SONSTIGE ERLÖSE', 'H', 'I', '', '4', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.539718', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (95, '7120', 'Grundsteuer', 'A', 'E', '', '', 0, NULL, 12, 3, NULL, false, '2006-01-28 18:22:52.612982', '2006-02-03 15:07:18.076256', NULL, NULL);",
      "INSERT INTO chart VALUES (94, '7110', 'Ertragssteuern', 'A', 'E', '', '', 0, NULL, 12, 3, NULL, false, '2006-01-28 18:22:52.60961', '2006-02-03 15:07:57.018877', NULL, NULL);",
      "INSERT INTO chart VALUES (159, '7130', 'Gewerbl. Sozialversicherung', 'A', 'E', 'AP_amount', '', 0, NULL, 12, 3, NULL, false, '2006-02-03 15:16:10.635938', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (82, '6000', 'LOHNAUFWAND', 'H', 'E', '', '6', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.566594', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (83, '6010', 'Lohn ', 'A', 'E', '', '600-619', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.572154', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (84, '6200', 'GEAHLTSAUFWAND', 'H', 'E', '', '6', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.575155', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (85, '6210', 'Gehalt ', 'A', 'E', '', '620-639', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.578104', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (86, '6500', 'GESETZLICHER SOZIALAUFWAND', 'H', 'E', '', '6', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.581152', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (87, '6510', 'Dienstgeberanteile', 'A', 'E', '', '645-649', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.584214', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (88, '6700', 'FREIWILLIGER SOZIALAUFWAND', 'H', 'E', '', '6', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.589022', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (89, '6710', 'freiwilliger Sozialaufwand', 'A', 'E', '', '660-665', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.592541', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (90, '7000', 'ABSCHREIBUNGEN', 'H', 'E', '', '7', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.595566', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (91, '7010', 'Abschreibungen', 'A', 'E', '', '700', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.598657', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (92, '7020', 'geringwertige Wirtschaftsgüter', 'A', 'E', 'AP_amount', '701-708', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.601829', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (93, '7100', 'SONSTIGE STEUERN', 'H', 'E', '', '71', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.604871', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (96, '7200', 'INSTANDHALTUNGSAUFWAND', 'H', 'E', '', '7', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.6171', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (98, '7300', 'TRANSPORTKOSTEN', 'H', 'L', '', '73', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.623721', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (100, '7400', 'MIET-,PACHT-,LEASING-, LIZENZAUFWAND', 'H', 'E', '', '74', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.631869', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (113, '7710', 'Sachversicherung', 'A', 'E', 'AP_amount', '', 0, NULL, 13, NULL, NULL, false, '2006-01-28 18:22:52.677258', '2006-02-03 15:19:30.793109', NULL, NULL);",
      "INSERT INTO chart VALUES (103, '7600', 'VERWALTUNGSKOSTEN', 'H', 'E', '', '76', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.641023', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (161, '7780', 'Beiträge zur Berufsvertretung', 'A', 'E', 'AP_amount', '', 0, NULL, NULL, 3, NULL, false, '2006-02-03 15:33:11.055578', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (102, '7420', 'Betriebsk. und ant. AfA Garage + Werkst.', 'A', 'E', 'AP_amount', '', 0, NULL, NULL, 3, NULL, false, '2006-01-28 18:22:52.637918', '2006-02-03 15:41:13.126408', NULL, NULL);",
      "INSERT INTO chart VALUES (112, '7700', 'VERSICHERUNGEN UND ÜBRIGE AUFWÄNDUNGEN', 'H', 'E', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.674186', '2006-02-03 15:44:43.301845', NULL, NULL);",
      "INSERT INTO chart VALUES (114, '8000', 'FINANZERTRÄGE UND FINANZAUFWÄNDUNGEN', 'H', 'L', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.680743', '2006-02-03 15:45:08.299546', NULL, NULL);",
      "INSERT INTO chart VALUES (33, '1530', 'Vorräte Gruppe B', 'A', 'A', 'IC', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.392343', '2006-02-03 16:25:53.167131', NULL, NULL);",
      "INSERT INTO chart VALUES (120, '9020', 'nicht einbezahltes Kapital', 'A', 'Q', '', '919', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.700926', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (121, '9200', 'KAPITALRÜCKLAGEN', 'H', 'Q', '', '9', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.703925', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (122, '9210', 'freie Rücklage', 'A', 'Q', '', '920-929', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.708819', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (123, '9300', 'GEWINN', 'H', 'Q', '', '939', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.712247', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (124, '9310', 'Gewinnvortrag Vorjahr', 'A', 'Q', '', '980', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.716177', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (125, '9320', 'Jahresgewinn', 'A', 'Q', '', '985', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.719991', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (126, '9400', 'RÜCKSTELLUNGEN', 'H', 'L', '', '3', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.723021', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (127, '9420', 'Abfertigungsrückstellung', 'A', 'L', '', '300', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.726006', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (128, '9430', 'Urlaubsrückstellung', 'A', 'L', '', '304-309', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.730698', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (129, '9700', 'EINLAGEN STILLER GESELLSCHAFTER', 'H', 'Q', '', '9', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.73381', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (71, '4300', 'UMSATZ DIENSTLEISTUNGEN', 'H', 'I', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.529746', '2006-01-28 18:34:28.843136', NULL, NULL);",
      "INSERT INTO chart VALUES (9, '0300', 'BETRIEBS- UND GESCHÄFTSGEBÄUDE', 'H', 'A', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.308885', '2006-02-02 09:31:17.849895', NULL, NULL);",
      "INSERT INTO chart VALUES (45, '2530', 'sonstige Forderungen aus Abgebenverrechnung', 'A', 'A', 'AP_amount', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.435243', '2006-02-02 09:59:42.729713', NULL, NULL);",
      "INSERT INTO chart VALUES (67, '4000', 'BETRIEBLICHE ERTRÄGE', 'H', 'I', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.513926', '2006-02-02 10:05:21.278993', NULL, NULL);",
      "INSERT INTO chart VALUES (75, '4630', 'Erlöse aus Abgang vom Anlagevermögen', 'A', 'I', 'AR_amount:IC_income', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.542817', '2006-02-02 10:09:41.959462', NULL, NULL);",
      "INSERT INTO chart VALUES (131, '4450', 'Erlösschmälerung durch Skontoaufwand', 'A', 'I', 'AR_amount', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.740526', '2006-02-02 10:20:51.822294', NULL, NULL);",
      "INSERT INTO chart VALUES (144, '4640', 'Erträge aus Abgang vom Anlagevermögen', 'A', 'I', 'AR_amount:IC_income', '', 0, NULL, NULL, NULL, NULL, false, '2006-02-02 10:24:49.118289', '2006-02-02 10:25:34.716838', NULL, NULL);",
      "INSERT INTO chart VALUES (118, '9000', 'KAPITAL, UNVERSTEUERTE RÜCKLAGEN, ABSCHLUSS- UND EVIDENZKONTEN', 'H', 'Q', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.694841', '2006-02-02 10:28:27.424046', NULL, NULL);",
      "INSERT INTO chart VALUES (147, '9410', 'Privatentnahme', 'A', 'Q', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-02-02 11:52:04.383364', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (76, '5000', 'MATERIALAUFWAND', 'H', 'E', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.545768', '2006-02-02 12:02:53.065559', NULL, NULL);",
      "INSERT INTO chart VALUES (160, '7140', 'Fremdenverkehrsabgabe', 'A', 'E', 'AP_amount', '', 0, NULL, 12, 3, NULL, false, '2006-02-03 15:16:52.380825', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (99, '7310', 'Frachtaufwand durch Dritte', 'A', 'E', 'AP_amount:IC_expense', '', 9, NULL, NULL, 3, NULL, false, '2006-01-28 18:22:52.628717', '2006-02-03 15:22:49.082217', NULL, NULL);",
      "INSERT INTO chart VALUES (152, '7320', 'KFZ-Aufwand', 'A', 'E', 'AP_amount:IC_expense', '', 9, NULL, NULL, 3, NULL, false, '2006-02-02 12:22:18.511562', '2006-02-03 15:23:31.584235', NULL, NULL);",
      "INSERT INTO chart VALUES (80, '5600', 'VERBRAUCH BRENN- UND TREIBSTOFFE, ENERGIE UND WASSER', 'H', 'I', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.56006', '2006-02-02 12:17:24.198896', NULL, NULL);",
      "INSERT INTO chart VALUES (109, '7390', 'Porto und Postgebühren', 'A', 'E', 'AP_amount:IC_expense', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.661848', '2006-02-02 12:28:47.456197', NULL, NULL);",
      "INSERT INTO chart VALUES (101, '7410', 'Miete und Pachtaufwand', 'A', 'E', 'AP_amount', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.634888', '2006-02-02 12:29:27.184902', NULL, NULL);",
      "INSERT INTO chart VALUES (107, '7620', 'Zeitungen und Zeitschriften', 'A', 'E', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.655683', '2006-02-02 12:32:43.287819', NULL, NULL);",
      "INSERT INTO chart VALUES (106, '7670', 'Werbung und Marketing', 'A', 'E', 'AP_amount', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.652584', '2006-02-02 12:33:37.934111', NULL, NULL);",
      "INSERT INTO chart VALUES (110, '7680', 'Repräsentationsaufwand', 'A', 'E', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.665034', '2006-02-02 12:35:16.950252', NULL, NULL);",
      "INSERT INTO chart VALUES (111, '7750', 'Rechtsberatung', 'A', 'E', 'AP_amount', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.671109', '2006-02-02 12:36:56.116865', NULL, NULL);",
      "INSERT INTO chart VALUES (153, '7755', 'Steuerberatung', 'A', 'E', 'AP_amount', '', 0, NULL, NULL, NULL, NULL, false, '2006-02-02 12:37:35.558667', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (115, '8280', 'Bankzinsen und Gebühren', 'A', 'E', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.683783', '2006-02-02 12:41:44.274229', NULL, NULL);",
      "INSERT INTO chart VALUES (117, '8110', 'Erträge aus Zinsen', 'A', 'I', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.691802', '2006-02-02 12:42:41.520779', NULL, NULL);",
      "INSERT INTO chart VALUES (132, '8050', 'Erträge aus Wertpapieren', 'A', 'E', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.743602', '2006-02-02 12:44:29.033245', NULL, NULL);",
      "INSERT INTO chart VALUES (104, '7610', 'Büromaterial', 'A', 'E', 'AP_amount', '', 9, NULL, 11, 3, NULL, false, '2006-01-28 18:22:52.644151', '2006-02-03 15:25:38.53287', NULL, NULL);",
      "INSERT INTO chart VALUES (116, '8010', 'Erträge aus Beteiligungen', 'A', 'I', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.688643', '2006-02-02 12:47:19.930787', NULL, NULL);",
      "INSERT INTO chart VALUES (119, '9010', 'Kapital, Geschäftsanteile', 'A', 'Q', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.69788', '2006-02-02 12:48:41.514201', NULL, NULL);",
      "INSERT INTO chart VALUES (108, '7380', 'Telefonkosten, Internetkosten', 'A', 'E', 'AP_amount', '', 9, NULL, 11, 3, NULL, false, '2006-01-28 18:22:52.658721', '2006-02-03 15:24:27.553821', NULL, NULL);",
      "INSERT INTO chart VALUES (32, '1520', 'Vorräte Gruppe A', 'A', 'A', 'IC', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.389168', '2006-02-03 16:26:08.72507', NULL, NULL);",
      "INSERT INTO chart VALUES (52, '2820', 'Bankguthaben', 'A', 'A', 'AR_paid:AP_paid', '', 0, NULL, NULL, 1, NULL, false, '2006-01-28 18:22:52.458922', '2006-02-04 15:00:18.424069', NULL, NULL);",
      "INSERT INTO chart VALUES (59, '3550', 'Finanzamt Verrechnung Körperschaftssteuer', 'A', 'L', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.483655', '2006-02-08 20:09:47.697565', NULL, NULL);",
      "INSERT INTO chart VALUES (60, '3540', 'Finanzamt Verrechnung Umsatzsteuer', 'A', 'L', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.48865', '2006-02-08 20:15:23.622013', NULL, NULL);",
      "INSERT INTO chart VALUES (78, '5030', 'Warengruppe 1 10 %', 'A', 'E', 'AP_amount:IC_cogs', '', 7, NULL, 4, 2, NULL, false, '2006-01-28 18:22:52.553586', '2006-02-08 20:31:31.539794', NULL, NULL);",
      "INSERT INTO chart VALUES (79, '5040', 'Warengruppe 2 20%', 'A', 'E', 'AP_amount:IC_cogs', '', 9, NULL, 4, 2, NULL, false, '2006-01-28 18:22:52.55679', '2006-02-03 14:44:38.100283', NULL, NULL);",
      "INSERT INTO chart VALUES (155, '5210', 'Sonst. Verbrauchsmaterial', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 3, NULL, false, '2006-02-03 14:49:06.01478', '2006-02-03 14:54:51.813269', NULL, NULL);",
      "INSERT INTO chart VALUES (146, '9850', 'Schlussbilanz', 'A', 'L', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-02-02 10:36:45.059659', '2006-02-02 10:38:05.014595', NULL, NULL);",
      "INSERT INTO chart VALUES (150, '5640', 'Verbrauch von sonstigen Ölen und Schmierstoffen', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 1, 19, false, '2006-02-02 12:07:52.512006', '2006-02-03 15:01:09.867763', NULL, NULL);",
      "INSERT INTO chart VALUES (130, '9810', 'Eröffnungsbilanz', 'A', 'L', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.736825', '2006-02-02 10:37:49.001565', NULL, NULL);",
      "INSERT INTO chart VALUES (164, '9800', 'BILANZKONTEN', 'H', 'L', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-03-06 22:23:47.795675', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (148, '5620', 'Verbrauch von Treibstoffen (Diesel)', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 2, 17, false, '2006-02-02 11:59:26.297394', '2006-02-03 15:00:02.362976', NULL, NULL);",
      "INSERT INTO chart VALUES (149, '5630', 'Verbrauch von Treib- und Schmierstoffen für Motorsägen', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 1, 19, false, '2006-02-02 12:01:05.969406', '2006-02-03 15:00:30.512596', NULL, NULL);",
      "INSERT INTO chart VALUES (158, '5650', 'gasförmige Brennstoffe', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 2, 12, false, '2006-02-03 15:02:36.649746', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (156, '5710', 'Warenbezugskosten', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 2, 8, false, '2006-02-03 14:56:21.395879', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (157, '5750', 'Fremdarbeit', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 2, NULL, false, '2006-02-03 14:58:23.887944', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (154, '5310', 'Arbeitskleidung', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 1, NULL, false, '2006-02-03 14:48:10.349391', '2006-02-03 16:23:46.154559', NULL, NULL);",
      "INSERT INTO chart VALUES (151, '5510', 'Verbrauchswerkzeug', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 2, NULL, false, '2006-02-02 12:19:18.193535', '2006-02-03 14:51:29.573924', NULL, NULL);",
      "INSERT INTO chart VALUES (81, '5610', 'Energie (Strom und Wasser)', 'A', 'E', 'AP_amount', '', 9, NULL, 4, 2, NULL, false, '2006-01-28 18:22:52.563249', '2006-02-03 14:59:32.292173', NULL, NULL);",
      "INSERT INTO chart VALUES (97, '7210', 'Reparatur und Instandhaltung', 'A', 'E', 'AP_amount', '', 9, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.620315', '2006-02-03 15:14:08.186799', NULL, NULL);",
      "INSERT INTO chart VALUES (72, '4320', 'Erlöse Beratung', 'A', 'I', 'AR_amount:IC_sale:IC_income', '', 3, 51, 1, 1, 2, false, '2006-01-28 18:22:52.533226', '2006-02-04 23:05:45.241847', NULL, NULL);",
      "INSERT INTO chart VALUES (73, '4330', 'Erlöse Programmierung', 'A', 'I', 'AR_amount:IC_sale:IC_income', '', 3, 51, 1, 1, 1, false, '2006-01-28 18:22:52.536409', '2006-02-04 23:06:03.959353', NULL, NULL);",
      "INSERT INTO chart VALUES (69, '4030', 'Erlöse - Softwareverkauf', 'A', 'I', 'AR_amount:IC_sale', '', 2, 86, 1, 1, 1, false, '2006-01-28 18:22:52.521819', '2006-02-02 10:06:58.91888', NULL, NULL);",
      "INSERT INTO chart VALUES (70, '4040', 'Erlöse - Ersatzteilverkauf', 'A', 'I', 'AR_amount:IC_sale', '', 3, 51, 1, 1, 1, false, '2006-01-28 18:22:52.524987', '2006-02-02 10:07:34.327738', NULL, NULL);",
      "INSERT INTO chart VALUES (57, '3310', 'Verbindlichkeiten aus Lieferungen & Leistungen', 'A', 'L', 'AP', '', 0, NULL, NULL, 1, NULL, false, '2006-01-28 18:22:52.477485', '2006-02-02 18:12:21.634302', NULL, NULL);",
      "INSERT INTO chart VALUES (51, '2810', 'Schecks', 'A', 'A', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.455807', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (55, '3120', 'Kredite von Eigentümern', 'A', 'L', '', '', 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.471098', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (49, '2710', 'Kassa', 'A', 'A', 'AR_paid', '', 0, NULL, NULL, 1, NULL, false, '2006-01-28 18:22:52.449148', '2006-02-04 14:59:14.410329', NULL, NULL);",
      "INSERT INTO chart VALUES (77, '5020', 'Warengruppe 0', 'A', 'E', 'IC:IC_cogs:AP_amount', '', 7, NULL, NULL, NULL, 8, false, '2006-01-28 18:22:52.550381', '2006-02-08 20:30:42.871241', NULL, NULL);",
      "INSERT INTO chart VALUES (68, '4020', 'Erlöse - Hardwareverkauf', 'A', 'I', 'AR_amount:IC_sale', '', 2, 86, 1, 1, 1, false, '2006-01-28 18:22:52.51796', '2006-02-04 23:05:12.810823', NULL, NULL);",
      "INSERT INTO chart VALUES (40, '2010', 'Forderungen Lieferung & Leistung', 'A', 'A', 'AR', '200-207', NULL, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.41697', NULL, NULL, NULL);",
      "INSERT INTO chart VALUES (65, '2510', 'Vorsteuer 10%', 'A', 'E', 'AR_tax:AP_tax:IC_taxpart:IC_taxservice', NULL, 0, 66, NULL, NULL, NULL, false, '2006-01-28 18:22:52.505337', '2006-02-02 17:38:40.373624', NULL, NULL);",
      "INSERT INTO chart VALUES (64, '2512', 'Vorsteuer 12%', 'A', 'E', 'AR_tax:AP_tax:IC_taxpart:IC_taxservice', NULL, 0, 66, NULL, NULL, NULL, false, '2006-01-28 18:22:52.502023', '2006-02-08 20:14:19.543049', NULL, NULL);",
      "INSERT INTO chart VALUES (66, '2520', 'Vorsteuer 20%', 'A', 'E', 'AR_tax:AP_tax:IC_taxpart:IC_taxservice', NULL, 0, 66, NULL, NULL, NULL, false, '2006-01-28 18:22:52.510324', '2006-02-02 18:07:25.987706', NULL, NULL);",
      "INSERT INTO chart VALUES (61, '3501', 'Mehrwertsteuer 0%', 'A', 'I', 'AR_tax:AP_tax:IC_taxpart:IC_taxservice', NULL, 0, NULL, NULL, NULL, NULL, false, '2006-01-28 18:22:52.491959', '2006-02-08 20:17:24.589389', NULL, NULL);",
      "INSERT INTO chart VALUES (62, '3510', 'Mehrwertsteuer 10%', 'A', 'I', 'AR_tax:AP_tax:IC_taxpart:IC_taxservice', NULL, 0, 861, NULL, NULL, NULL, false, '2006-01-28 18:22:52.495255', '2006-02-08 20:16:06.81373', NULL, NULL);",
      "INSERT INTO chart VALUES (63, '3520', 'Mehrwertsteuer 20%', 'A', 'I', 'AR_tax:AP_tax:IC_taxpart:IC_taxservice', NULL, 0, 511, NULL, NULL, NULL, false, '2006-01-28 18:22:52.498543', '2006-02-08 20:16:30.014075', NULL, NULL);",
      "insert into chart (accno,description,charttype,gifi_accno,category,link) values ('0400','MASCHINEN','H','04-05','A','');",
      "insert into chart (accno,description,charttype,gifi_accno,category,link) values ('7411','Lizenzen','A','748-749','E','AP_amount');",
      "insert into chart (accno,description,charttype,gifi_accno,category,link) values ('7631','Internetkosten','A','738-739','E','AP_amount:IC_expense');",
      "insert into chart (accno,description,charttype,gifi_accno,category,link) values ('7632','Reise- und Repräsentationsaufwand','A','734-735','E','');",
      "insert into chart (accno,description,charttype,gifi_accno,category,link) values ('7634','Registrierungsgebühren','A','748-749','E','AP_amount');",
      "insert into chart (accno,description,charttype,gifi_accno,category,link) values ('8020','Bankzinsen und Gebühren','A','80-83','E','');",


  );

  $self->db_query($_) for @copy_statements;

  return 1;
}
sub do_insert_tax {
  my ($self) = @_;

  my @copy_statements = (
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (65, '2510', 7, 'Vorsteuer 10%', '2006-01-30 11:08:23.332857', '2006-02-08 20:28:09.63567', 0.10000, 173);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (64, '2512', 8, 'Vorsteuer 12%', '2006-02-02 17:39:18.535036', '2006-02-08 20:28:21.463869', 0.12000, 174);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (66, '2520', 9, 'Vorsteuer 20%', '2006-01-30 11:08:23.332857', '2006-02-08 19:57:47.648373', 0.20000, 175);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (61, '3501', 1, 'Mehrwertsteuerfrei', '2006-01-30 11:08:23.332857', '2006-02-08 20:23:14.242534', 0.00000, 176);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (62, '3510', 2, 'Mehrwertsteuer 10%', '2006-01-30 11:08:23.332857', '2006-02-08 20:23:32.978436', 0.10000, 177);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (63, '3520', 3, 'Mehrwertsteuer 20%', '2006-01-30 11:08:23.332857', '2006-02-08 20:23:47.331584', 0.20000, 178);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (NULL, NULL, 10, 'Im anderen EG-Staat steuerpfl. Lieferung', '2006-01-30 11:08:23.332857', '2006-02-08 12:45:36.44088', NULL, 171);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (NULL, NULL, 11, 'Steuerfreie EG-Lief. an Abn. mit UStIdNr', '2006-01-30 11:08:23.332857', '2006-02-08 12:45:36.44088', NULL, 172);",
      "INSERT INTO tax (chart_id, taxnumber, taxkey, taxdescription, itime, mtime, rate, id) VALUES (NULL, NULL, 0, 'Keine Steuer', '2006-01-30 11:08:23.332857', '2006-02-08 12:45:36.44088', 0.00000, 0);",

  );

  for my $statement ( 0 .. $#copy_statements ) {
    my $query = $copy_statements[$statement];
      #print $query . "<br />";  # Diagnose only!
      $self->db_query($query, 0);
  }
  return 1;
}

sub do_insert_taxkeys {
  my ($self) = @_;

  my @copy_statements = (
      "INSERT INTO taxkeys VALUES (230, 69, 177, 2, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (231, 72, 178, 3, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (232, 73, 178, 3, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (233, 70, 178, 3, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (234, 78, 173, 7, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (235, 77, 173, 7, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (236, 105, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (237, 163, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (238, 99, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (239, 152, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (240, 104, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (241, 108, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (242, 79, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (243, 155, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (244, 150, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (245, 148, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (246, 149, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (247, 158, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (248, 156, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (249, 157, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (250, 154, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (251, 151, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (252, 81, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (253, 97, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (258, 0, 171, 10, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (259, 0, 172, 11, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (260, 0, 173, 7, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (261, 0, 174, 8, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (262, 0, 175, 9, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (263, 0, 176, 1, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (264, 0, 177, 2, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (265, 0, 178, 3, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (266, 68, 177, 2, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (179, 95, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (180, 94, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (181, 159, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (182, 113, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (183, 161, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (184, 102, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (185, 112, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (186, 114, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (187, 33, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (188, 71, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (189, 9, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (190, 45, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (191, 67, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (192, 75, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (193, 131, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (194, 144, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (195, 118, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (196, 147, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (197, 76, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (198, 160, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (199, 80, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (200, 109, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (201, 101, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (202, 107, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (203, 106, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (204, 110, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (205, 111, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (206, 153, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (207, 115, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (208, 117, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (209, 132, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (210, 116, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (211, 119, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (212, 32, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (213, 52, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (214, 59, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (215, 60, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (217, 146, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (223, 130, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (224, 164, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (225, 57, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (226, 51, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (227, 55, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (228, 49, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (257, 0, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (267, 40, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (279, 65, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (280, 64, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (281, 66, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (282, 61, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (283, 62, 0, 0, NULL, '1970-01-01');",
      "INSERT INTO taxkeys VALUES (284, 63, 0, 0, NULL, '1970-01-01');",

      "ALTER TABLE taxkeys DROP COLUMN pos_ustva;",
      "ALTER TABLE taxkeys ADD COLUMN pos_ustva text;",
#      "INSERT INTO taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
#            SELECT id, 0, 0, NULL, '01.01.1970' FROM chart WHERE charttype='A';",
      "UPDATE chart SET taxkey_id = 0 WHERE taxkey_id ISNULL;",
      "UPDATE taxkeys SET pos_ustva='000' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('4010', '4015', '4020', '4025', '4030', '4035', '4040', '4045', '4050', '4310', '4315', '4320', '4322', '4325', '4330', '4335', '4340', '4345', '4350', '4450', '4029', '4329'));",
      "UPDATE taxkeys SET pos_ustva='011' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('4029', '4329'));",
      "UPDATE taxkeys SET pos_ustva='017' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('4015', '4025', '4035', '4045', '4315', '4325', '4335', '4345'));",
      "UPDATE taxkeys SET pos_ustva='022' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('4040', '4045'));",
      "UPDATE taxkeys SET pos_ustva='122' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('3520'));",
      "UPDATE taxkeys SET pos_ustva='029' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('4010', '4015'));",
      "UPDATE taxkeys SET pos_ustva='129' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('3510'));",
      "UPDATE taxkeys SET pos_ustva='025' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('4012'));",
      "UPDATE taxkeys SET pos_ustva='125' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('3512'));",
      "UPDATE taxkeys SET pos_ustva='035' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('4016'));",
      "UPDATE taxkeys SET pos_ustva='135' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('3516'));",
      "UPDATE taxkeys SET pos_ustva='070' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('5015', '5025'));",
      "UPDATE taxkeys SET pos_ustva='072' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('5025'));",
      "UPDATE taxkeys SET pos_ustva='172' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('3502'));",
      "UPDATE taxkeys SET pos_ustva='073' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('5015'));",
      "UPDATE taxkeys SET pos_ustva='173' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('3501'));",
      "UPDATE taxkeys SET pos_ustva='060' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('2510', '2512', '2516', '2519', '2520'));",
      "UPDATE taxkeys SET pos_ustva='065' WHERE chart_id IN (SELECT id FROM chart WHERE accno IN ('2515'));",
  );

  for my $statement ( 0 .. $#copy_statements ) {
    my $query = $copy_statements[$statement];
      #print $query . "<br />";  # Diagnose only!
      $self->db_query($query, 0);
  }

return 1;

}

sub do_insert_buchungsgruppen {
  my ($self) = @_;

  my @copy_statements = (
      "INSERT INTO buchungsgruppen VALUES (256, 'Erlöse aus Dienstleistungen', 23, 72, 99, 72, 77, 72, 77, 72, 77, 3);",
      "INSERT INTO buchungsgruppen VALUES (254, 'Erlöse aus Warenlieferungen', 23, 68, 77, 72, 77, 72, 77, 72, 77, 2);",
      "INSERT INTO buchungsgruppen VALUES (255, 'Erlöse aus Dienstleistungen', 23, 72, 77, 72, 77, 72, 77, 72, 77, 1);",
  );

  for my $statement ( 0 .. $#copy_statements ) {
    my $query = $copy_statements[$statement];
      #print $query . "<br />";  # Diagnose only!
      $self->db_query($query, 0);
  }

  return 1;
}

1;
