-- deutschsprachiger Kontenplan nach Schweizer Kontenrahmen KMU für Firmen in der Schweiz, die mehrwertsteuerpflichtig sind
-- Erstellt am 4.6.2014
-- Grundlage: Revision OR Stand 1.1.2013, insbesondere Art. 957a Abs. 2 
-- Redaktion: Andreas Rudin, http://www.revamp-it.ch
-- Copyright 2014 Andreas Rudin

-- This file is part of kivitendo.
-- kivitendo is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- kivitendo is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- You should have received a copy of the GNU General Public License
-- along with kivitendo. If not, see <http://www.gnu.org/licenses/>.


-- CH Konten
DELETE FROM chart;

INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1','AKTIVEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('10','UMLAUFSVERMÖGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('100','Flüssige Mittel','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1000','Kasse','A','A','AR_paid:AP_paid',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1020','Postfinance oder Bank1','A','A','AR_paid:AP_paid',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1021','Bank2','A','A','AR_paid:AP_paid',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('106','Kurzfristig gehaltene Aktiven mit Börsenkurs','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('110','Forderungen aus Lieferungen und Leistungen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1100','Forderungen aus Lieferungen und Leistungen','A','A','AR',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('114','Übrige kurzfristige Forderungen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1140','Vorschüsse, kurzfristige Darlehen','A','A','AR',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1170','Vorsteuer auf Aufwand','A','A','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1171','Vorsteuer auf Investitionen','A','A','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1176','Verrechnungssteuer','A','A','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('120','Vorräte und nicht fakturierte Dienstleistungen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1200','Handelswaren','A','A','IC',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1210','Rohstoffe','A','A','IC',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1280','Nicht fakturierte Dienstleistungen','A','A','IC',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1290','Angefangene Arbeiten','A','A','IC',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('130','Aktive Rechnungsabgrenzungen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1300','Aktive Rechnungsabgrenzungen','A','A','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('14','ANLAGEVERMÖGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('140','Finanzanlagen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('148','Beteiligungen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('150','Mobile Sachanlagen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1500','Maschinen und Apparate','A','A','IC',NULL,6,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1510','Mobiliar und Einrichtungen','A','A','IC',NULL,6,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1520','Büromaschinen, Informatik','A','A','IC',NULL,6,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1530','Fahrzeuge','A','A','IC',NULL,6,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('1540','Werkzeuge und Geräte','A','A','IC',NULL,6,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('160','Immobile Sachanlagen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('170','Immaterielle Werte','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('180','Nicht einbezahltes Grund- Gesellschafter- oder Stiftungskapital','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2','PASSIVEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('20','KURZFRISTIGES FREMDKAPITAL','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('200','Verbindlichkeiten aus Lieferungen und Leistungen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2000','Verbindlichkeiten aus Lieferungen und Leistungen','A','L','AP',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2001','Übrige Kreditoren','A','L','AP',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2030','Anzahlungen von Kundinnen und Kunden','A','L','AR_paid:AP_paid',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('210','Kurzfristige verzinsliche Verbindlichkeiten','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2100','Bankverbindlichkeiten','A','L','AR_paid:AP_paid',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2140','Übrige verzinsliche Verbindlichkeiten','A','L','AP',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('220','Übrige kurzfristige Verbindlichkeiten','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2200','Geschuldete MWST(2,5)','A','L','AR_tax:AP_tax:IC_taxpart:IC_taxservice:CT_tax',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2201','Geschuldete MWST(8,0)','A','L','AR_tax:AP_tax:IC_taxpart:IC_taxservice:CT_tax',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2206','Verrechnungssteuer','A','L','AP',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2210','Geschuldete Steuern','A','L','AP',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2250','Personalaufwand','A','L','AP',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2270','Verbindlichkeiten Sozialversicherungen und Vorsorgeeinrichtungen','A','L','AP',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('230','Passive Rechnungsabgrenzungen und kurzfristige Rückstellungen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2300','Passive Rechnungsabgrenzungen','A','L','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2330','Kurzfristige Rückstellungen','A','L','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('24','LANGFRISTIGES FREMDKAPITAL','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('240','Langfristige verzinsliche Verbindlichkeiten','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2400','Bankverbindlichkeiten','A','L','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2450','Langfristige verzinsliche Darlehen','A','L','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('250','Übrige langfristige Verbindlichkeiten','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2500','Zinslose Darlehen','A','L','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('260','Rückstellungen sowie vom Gesetz vorgesehene ähnliche Positionen','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('28','EIGENKAPITAL','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('280','Grund-, Gesellschafter- oder Stiftungskapital','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2800','Stammkapital','A','Q','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('290','Reserven, Jahresgewinn oder Jahresverlust','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2900','Gesetzliche Kapitalreserve','A','Q','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2950','Gesetzliche Gewinnreserve','A','Q','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2960','Freiwillige Gewinnreserve','A','Q','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2970','Gewinn- oder Verlustvortrag','A','Q','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2979','Jahresgewinn oder -verlust','A','Q','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('2980','Eigene Kapitalanteile','A','Q','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3','BETRIEBLICHER ERTRAG AUS LIEFERUNGEN UND LEISTUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('30','PRODUKTIONSERLÖSE','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3000','Produktionserlöse','A','I','AR_amount:IC_sale',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('32','HANDELSERLÖSE','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3200','Handelserlöse','A','I','AR_amount:IC_sale',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('34','DIENSTLEISTUNGSERLÖSE','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3400','Dienstleistungserlöse','A','I','AR_amount:IC_income',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('36','ÜBRIGE ERLÖSE AUS LIEFERUNGEN UND LEISTUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3600','Übrige Erlöse aus Lieferungen und Leistungen','A','I','IC_income',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('37','EIGENLEISTUNGEN UND EIGENVERBRAUCH','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3700','Eigenleistungen','A','I','',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('38','ERLÖSMINDERUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3800','Skonti','A','E','IC_sale:IC_cogs:IC_income:IC_expense',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3801','Rabatte, Preisnachlässe','A','E','IC_sale:IC_cogs:IC_income:IC_expense',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3805','Verluste aus Forderungen','A','E','IC_sale:IC_cogs:IC_income:IC_expense',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3809','MWST - nur Saldosteuersatz','A','E','IC_sale:IC_cogs:IC_income:IC_expense',NULL,0,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('39','BESTANDESÄNDERUNGEN AN UNFERTIGEN UND FERTIGEN ERZEUGNISSEN SOWIE AN NICHT FAKTURIERTEN DIENSTLEISTUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('3900','Bestandesänderungen','A','I','',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4','AUFWAND FÜR MATERIAL, HANDELSWAREN, DIENSTLEISTUNGEN UND ENERGIE','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('40','MATERIALAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4000','Materialeinkauf','A','E','AP_amount:IC_cogs',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('42','HANDELSWARENAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4200','Einkauf Handelswaren','A','E','AP_amount:IC_cogs',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4208','Bestandsänderungen Handelswaren','A','E','AP_amount:IC_cogs',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('44','AUFWAND FÜR BEZOGENE DRITTLEISTUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4400','Aufwand für Drittleistungen','A','E','AP_amount:IC_expense',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('45','ENERGIEAUFWAND ZUR LEISTUNGSERSTELLUNG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4500','Energieaufwand zur Leistungserstellung','A','E','AP_amount:IC_expense',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('46','ÜBRIGER AUFWAND FÜR MATERIAL, HANDELSWAREN UND DIENSTLEISTUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('47','DIREKTE EINKAUFSSPESEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4700','Einkaufsspesen','A','E','AP_amount:IC_expense',NULL,4,NULL,NULL,NULL,6, 'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('48','BESTANDESÄNDERUNGEN UND MATERIAL-/WARENVERLUSTE','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4800','Bestandesänderungen','A','E','',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('49','EINKAUFSPREISMINDERUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('4900','Skonti, Rabatte, Preisnachlässe','A','I','AP_amount:IC_expense',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5','PERSONALAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('500','Löhne und Gehälter','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5000','Löhne und Gehälter','A','E','IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5001','Erfolgsbeteiligungen','A','E','IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5005','Leistungen von Sozialversicherungen','A','I','IC_income',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('57','SOZIALVERSICHERUNGSAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5700','AHV, IV, EO, ALV','A','E','AP_amount:IC_income:IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5710','FAK','A','E','AP_amount:IC_income:IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5720','Berufliche Vorsorge','A','E','AP_amount:IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5730','Unfallversicherung','A','E','AP_amount:IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5740','Krankentaggeldversicherung','A','E','AP_amount:IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5790','Quellensteuer','A','E','AP_amount:IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('58','ÜBRIGER PERSONALAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5800','Aufwand für Personaleinstellung','A','E','IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5810','Weiterbildungskosten','A','E','IC_expense',NULL,1,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5830','Spesen','A','E','IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('5880','Sonstiger Personalaufwand','A','E','IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('59','LEISTUNGEN DRITTER','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6','ÜBRIGER BETRIEBLICHER AUFWAND, ABSCHREIBUNGEN UND WERTBERICHTIGUNGEN SOWIE FINANZERGEBNIS','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('60','RAUMAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6000','Miete','A','E','IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6040','Reinigung','A','E','IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6050','Übriger Raumaufwand','A','E','IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('61','UNTERHALT, REPARATUREN, ERSATZ, LEASING, MOBILE SACHANLAGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6100','Unterhalt','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('62','FAHRZEUG- UND TRANSPORTAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6200','Fahrzeugaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6201','Transportaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('63','SACHVERSICHERUNGEN, ABGABEN, GEBÜHREN, BEWILLIGUNGEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6300','Betriebsversicherungen','A','E','AP_amount:IC_expense',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6360','Abgaben, Gebühren und Bewilligungen','A','E','AP_amount:IC_expense',NULL,1,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('64','ENERGIE- UND ENTSORGUNGSAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6400','Strom, Gas, Wasser','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6460','Entsorgungsaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('65','VERWALTUNGS- UND INFORMATIKAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6500','Büromaterial, Drucksachen','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6503','Fachliteratur','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6510','Telefon, Fax, Porti Internet','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6520','Beiträge, Spenden','A','E','AP_amount:IC_expense',NULL,1,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6530','Buchführungs- und Beratungsaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6540','Verwaltungsrat, GV, Revision','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6570','Informatikaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6590','Übriger Verwaltungsaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('66','WERBEAUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6600','Werbeaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('67','SONSTIGER BETRIEBLICHER AUFWAND','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6720','Forschung und Entwicklung','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6790','Übriger Betriebsaufwand','A','E','AP_amount:IC_expense',NULL,6,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('68','ABSCHREIBUNGEN UND WERTBERICHTIGUNGEN AUF POSITIONEN DES ANLAGEVERMÖGENS','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6800','Abschreibungen Finanzanlagen','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6810','Abschreibungen Beteiligungen','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6820','Abschreibungen mobile Sachanlagen','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6840','Abschreibungen immaterielle Anlagen','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('69','FINANZAUFWAND UND FINANZERTRAG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('690','Finanzaufwand','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6900','Finanzaufwand','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6940','Bankspesen','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6942','Kursverluste','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6943','Rundungsaufwand','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('695','Finanzertrag','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6950','Finanzertrag','A','I','',NULL,0,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6952','Kursgewinne','A','I','',NULL,0,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6953','Rundungsertrag','A','I','',NULL,0,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6970','Mitgliederbeiträge','A','I','AR_amount:IC_income',NULL,1,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('6980','Spenden','A','I','AR_amount:IC_income',NULL,1,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('7','BETRIEBLICHER NEBENERFOLG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('70','ERFOLG AUS NEBENBETRIEBEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('75','ERFOLG AUS BETRIEBLICHEN LIEGENSCHAFTEN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8','BETRIEBSFREMDER, AUSSERORDENTLICHER, EINMALIGER UND PERIODENFREMDER AUFWAND UND ERTRAG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('80','BETRIEBSFREMDER AUFWAND UND BETRIEBSFREMDER ERTRAG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8000','Betriebsfremder Aufwand','A','E','AP_amount:IC_cogs',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8100','Betriebsfremder Ertrag','A','I','AR_amount:IC_sale',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('85','AUSSERORDENTLICHER, EINMALIGER AUFWAND UND ERTRAG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8500','Ausserordentlicher Aufwand','A','E','AP_amount:IC_cogs',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8510','Ausserordentlicher Ertrag','A','I','AR_amount:IC_sale',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('87','PERIODENFREMDER AUFWAND UND ERTRAG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8700','Periodenfremder Aufwand','A','E','AP_amount:IC_cogs',NULL,4,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8710','Periodenfremder Ertrag','A','I','AR_amount:IC_sale',NULL,2,NULL,NULL,NULL,1,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('89','DIREKTE STEUERN','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('8900','Direkte Steuern','A','E','',NULL,0,NULL,NULL,NULL,6,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('9','ABSCHLUSS','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('90','ERFOLGSRECHNUNG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('91','BILANZ','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('9100','Eröffnungsbilanz','A','E','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('92','GEWINNVERWENDUNG','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('95','JAHRESERGEBNISSE','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);
INSERT INTO chart (accno, description, charttype, category, link, gifi_accno, taxkey_id, pos_ustva, pos_bwa, pos_bilanz, pos_eur, datevautomatik, itime, mtime, valid_from) VALUES ('99','HILFSKONTEN NEBENBÜCHER','H','','',NULL,0,NULL,NULL,NULL,NULL,'f','2014-01-01 00:00:00.000000',NULL,NULL);


-- Buchungsgruppen
DELETE FROM buchungsgruppen;

INSERT INTO buchungsgruppen
  (description, inventory_accno_id,
    income_accno_id_0, expense_accno_id_0,
    income_accno_id_1, expense_accno_id_1,
    income_accno_id_2, expense_accno_id_2,
    income_accno_id_3, expense_accno_id_3)
 VALUES
  -- Beschreibung
  ('Standard',
  -- 1200: Handelswaren
  (SELECT id FROM chart WHERE accno = '1200'),
  -- 3000: Produktionserlöse
  -- 4000: Materialeinkauf
  (SELECT id FROM chart WHERE accno = '3000'),
  (SELECT id FROM chart WHERE accno = '4000'),
  -- 3000: Produktionserlöse
  -- 4000: Materialeinkauf
  (SELECT id FROM chart WHERE accno = '3000'),
  (SELECT id FROM chart WHERE accno = '4000'),
  -- 3000: Produktionserlöse
  -- 4000: Materialeinkauf
  (SELECT id FROM chart WHERE accno = '3000'),
  (SELECT id FROM chart WHERE accno = '4000'),
  -- 3000: Produktionserlöse
  -- 4000: Materialeinkauf
  (SELECT id FROM chart WHERE accno = '3000'),
  (SELECT id FROM chart WHERE accno = '4000'));


-- Mandantenkonfiguration
DELETE FROM defaults;

INSERT INTO defaults
  (inventory_accno_id, income_accno_id,
   expense_accno_id, fxgain_accno_id,
   fxloss_accno_id, invnumber,
   sonumber, weightunit,
   businessnumber, version,
   curr, closedto,
   revtrans, ponumber,
   sqnumber, rfqnumber,
   customernumber, vendornumber,
   audittrail, articlenumber,
   servicenumber, coa,
   itime, mtime,
   rmanumber, cnnumber,
   accounting_method, inventory_system,
   profit_determination)
 VALUES
  -- 1200: Handelswaren / 3000: Produktionserlöse
  ((SELECT id FROM CHART WHERE accno='1200'),(SELECT id FROM CHART WHERE accno='3000'),
  -- 4000: Materialeinkauf / 6952: Kursgewinne
  (SELECT id FROM CHART WHERE accno='4000'),(SELECT id FROM CHART WHERE accno='6952'),
  -- 6942: Kursverluste
  (SELECT id FROM CHART WHERE accno='6942'),0,
  0,'kg',
  '','3.1.0 CH',
  'CHF:EUR',NULL,
  'f',0,
  0,0,
  0,0,
  'f',0,
  0,'Switzerland-deutsch-MWST',
  '2014-01-01 00:00:00.000000',NULL,
  0,0,
  'accrual','periodic',
  'balance');


-- Steuern & Steuerzonen
DELETE FROM tax;

INSERT INTO tax (rate, taxkey, taxdescription, itime, mtime, id) VALUES
(0,0,'Keine Steuer','2014-01-01 00:00:00.000000',NULL,0),
(0,1,'Mehrwertsteuerfrei','2014-01-01 00:00:00.000000',NULL,1);

INSERT INTO tax (chart_id, rate, taxnumber, taxkey, taxdescription, itime, mtime, id) VALUES
  -- 2201:
  ((SELECT id FROM CHART WHERE accno='2201'),0.08000,2201,2,'MWST Normalsatz','2014-01-01 00:00:00.000000',NULL,2),
  -- 2200:
  ((SELECT id FROM CHART WHERE accno='2200'),0.02500,2200,3,'MWST reduzierter Satz','2014-01-01 00:00:00.000000',NULL,3),
  -- 1170:
  ((SELECT id FROM CHART WHERE accno='1170'),0.08000,1170,4,'MWST 8% Aufwand','2014-01-01 00:00:00.000000',NULL,4),
  -- 1170:
  ((SELECT id FROM CHART WHERE accno='1170'),0.02500,1170,5,'MWST 2.5% Aufwand','2014-01-01 00:00:00.000000',NULL,5),
  -- 1171:
  ((SELECT id FROM CHART WHERE accno='1171'),0.08000,1171,6,'MWST 8% Investitionen','2014-01-01 00:00:00.000000',NULL,6),
  -- 1171:
  ((SELECT id FROM CHART WHERE accno='1171'),0.02500,1171,7,'MWST 2.5% Investitionen','2014-01-01 00:00:00.000000',NULL,7);


DELETE FROM tax_zones;

INSERT INTO tax_zones (id, description) VALUES
(0,'Schweiz'),
(1,'EU mit USt-ID Nummer'),
(2,'EU ohne USt-ID Nummer'),
(3,'Ausserhalb EU');


DELETE FROM taxkeys;

INSERT INTO taxkeys (id, chart_id, tax_id, taxkey_id, pos_ustva, startdate) VALUES
(0,0,0,0,NULL,'2014-01-01'),
(1,1,0,0,NULL,'2014-01-01'),
(2,2,0,0,NULL,'2014-01-01'),
(3,3,0,0,NULL,'2014-01-01'),
(4,4,0,0,NULL,'2014-01-01'),
(5,5,0,0,NULL,'2014-01-01'),
(6,6,0,0,NULL,'2014-01-01'),
(7,7,0,0,NULL,'2014-01-01'),
(8,8,0,0,NULL,'2014-01-01'),
(9,9,0,0,NULL,'2014-01-01'),
(10,10,0,0,NULL,'2014-01-01'),
(11,11,0,0,NULL,'2014-01-01'),
(12,12,0,0,NULL,'2014-01-01'),
(13,13,0,0,NULL,'2014-01-01'),
(14,14,0,0,NULL,'2014-01-01'),
(15,15,0,0,NULL,'2014-01-01'),
(16,16,0,0,NULL,'2014-01-01'),
(17,17,0,0,NULL,'2014-01-01'),
(18,18,0,0,NULL,'2014-01-01'),
(19,19,0,0,NULL,'2014-01-01'),
(20,20,0,0,NULL,'2014-01-01'),
(21,21,0,0,NULL,'2014-01-01'),
(22,22,0,0,NULL,'2014-01-01'),
(23,23,0,0,NULL,'2014-01-01'),
(24,24,0,0,NULL,'2014-01-01'),
(25,25,0,0,NULL,'2014-01-01'),
(26,26,0,0,NULL,'2014-01-01'),
(27,27,0,0,NULL,'2014-01-01'),
(28,28,0,0,NULL,'2014-01-01'),
(29,29,0,0,NULL,'2014-01-01'),
(30,30,0,0,NULL,'2014-01-01'),
(31,31,0,0,NULL,'2014-01-01'),
(32,32,0,0,NULL,'2014-01-01'),
(33,33,0,0,NULL,'2014-01-01'),
(34,34,0,0,NULL,'2014-01-01'),
(35,35,0,0,NULL,'2014-01-01'),
(36,36,0,0,NULL,'2014-01-01'),
(37,37,0,0,NULL,'2014-01-01'),
(38,38,0,0,NULL,'2014-01-01'),
(39,39,0,0,NULL,'2014-01-01'),
(40,40,0,0,NULL,'2014-01-01'),
(41,41,0,0,NULL,'2014-01-01'),
(42,42,0,0,NULL,'2014-01-01'),
(43,43,0,0,NULL,'2014-01-01'),
(44,44,0,0,NULL,'2014-01-01'),
(45,45,0,0,NULL,'2014-01-01'),
(46,46,0,0,NULL,'2014-01-01'),
(47,47,0,0,NULL,'2014-01-01'),
(48,48,0,0,NULL,'2014-01-01'),
(49,49,0,0,NULL,'2014-01-01'),
(50,50,0,0,NULL,'2014-01-01'),
(51,51,0,0,NULL,'2014-01-01'),
(52,52,0,0,NULL,'2014-01-01'),
(53,53,0,0,NULL,'2014-01-01'),
(54,54,0,0,NULL,'2014-01-01'),
(55,55,0,0,NULL,'2014-01-01'),
(56,56,0,0,NULL,'2014-01-01'),
(57,57,0,0,NULL,'2014-01-01'),
(58,58,0,0,NULL,'2014-01-01'),
(59,59,0,0,NULL,'2014-01-01'),
(60,60,0,0,NULL,'2014-01-01'),
(61,61,0,0,NULL,'2014-01-01'),
(62,62,0,0,NULL,'2014-01-01'),
(63,63,0,0,NULL,'2014-01-01'),
(64,64,0,0,NULL,'2014-01-01'),
(65,65,0,0,NULL,'2014-01-01'),
(66,66,0,0,NULL,'2014-01-01'),
(67,67,0,0,NULL,'2014-01-01'),
(68,68,0,0,NULL,'2014-01-01'),
(69,69,0,0,NULL,'2014-01-01'),
(70,70,0,0,NULL,'2014-01-01'),
(71,71,0,0,NULL,'2014-01-01'),
(72,72,0,0,NULL,'2014-01-01'),
(73,73,0,0,NULL,'2014-01-01'),
(74,74,0,0,NULL,'2014-01-01'),
(75,75,0,0,NULL,'2014-01-01'),
(76,76,0,0,NULL,'2014-01-01'),
(77,77,0,0,NULL,'2014-01-01'),
(78,78,0,0,NULL,'2014-01-01'),
(79,79,0,0,NULL,'2014-01-01'),
(80,80,0,0,NULL,'2014-01-01'),
(81,81,0,0,NULL,'2014-01-01'),
(82,82,0,0,NULL,'2014-01-01'),
(83,83,0,0,NULL,'2014-01-01'),
(84,84,0,0,NULL,'2014-01-01'),
(85,85,0,0,NULL,'2014-01-01'),
(86,86,0,0,NULL,'2014-01-01'),
(87,87,0,0,NULL,'2014-01-01'),
(88,88,0,0,NULL,'2014-01-01'),
(89,89,0,0,NULL,'2014-01-01'),
(90,90,0,0,NULL,'2014-01-01'),
(91,91,0,0,NULL,'2014-01-01'),
(92,92,0,0,NULL,'2014-01-01'),
(93,93,0,0,NULL,'2014-01-01'),
(94,94,0,0,NULL,'2014-01-01'),
(95,95,0,0,NULL,'2014-01-01'),
(96,96,0,0,NULL,'2014-01-01'),
(97,97,0,0,NULL,'2014-01-01'),
(98,98,0,0,NULL,'2014-01-01'),
(99,99,0,0,NULL,'2014-01-01'),
(100,100,0,0,NULL,'2014-01-01'),
(101,101,0,0,NULL,'2014-01-01'),
(102,102,0,0,NULL,'2014-01-01'),
(103,103,0,0,NULL,'2014-01-01'),
(104,104,0,0,NULL,'2014-01-01'),
(105,105,0,0,NULL,'2014-01-01'),
(106,106,0,0,NULL,'2014-01-01'),
(107,107,0,0,NULL,'2014-01-01'),
(108,108,0,0,NULL,'2014-01-01'),
(109,109,0,0,NULL,'2014-01-01'),
(110,110,0,0,NULL,'2014-01-01'),
(111,111,0,0,NULL,'2014-01-01'),
(112,112,0,0,NULL,'2014-01-01'),
(113,113,0,0,NULL,'2014-01-01'),
(114,114,0,0,NULL,'2014-01-01'),
(115,115,0,0,NULL,'2014-01-01'),
(116,116,0,0,NULL,'2014-01-01'),
(117,117,0,0,NULL,'2014-01-01'),
(118,118,0,0,NULL,'2014-01-01'),
(119,119,0,0,NULL,'2014-01-01'),
(120,120,0,0,NULL,'2014-01-01'),
(121,121,0,0,NULL,'2014-01-01'),
(122,122,0,0,NULL,'2014-01-01'),
(123,123,0,0,NULL,'2014-01-01'),
(124,124,0,0,NULL,'2014-01-01'),
(125,125,0,0,NULL,'2014-01-01'),
(126,126,0,0,NULL,'2014-01-01'),
(127,127,0,0,NULL,'2014-01-01'),
(128,128,0,0,NULL,'2014-01-01'),
(129,129,0,0,NULL,'2014-01-01'),
(130,130,0,0,NULL,'2014-01-01'),
(131,131,0,0,NULL,'2014-01-01'),
(132,132,0,0,NULL,'2014-01-01'),
(133,133,0,0,NULL,'2014-01-01'),
(134,134,0,0,NULL,'2014-01-01'),
(135,135,0,0,NULL,'2014-01-01'),
(136,136,0,0,NULL,'2014-01-01'),
(137,137,0,0,NULL,'2014-01-01'),
(138,138,0,0,NULL,'2014-01-01'),
(139,139,0,0,NULL,'2014-01-01'),
(140,140,0,0,NULL,'2014-01-01'),
(141,141,0,0,NULL,'2014-01-01'),
(142,142,0,0,NULL,'2014-01-01'),
(143,143,0,0,NULL,'2014-01-01'),
(144,144,0,0,NULL,'2014-01-01'),
(145,145,0,0,NULL,'2014-01-01'),
(146,146,0,0,NULL,'2014-01-01'),
(147,147,0,0,NULL,'2014-01-01'),
(148,148,0,0,NULL,'2014-01-01'),
(149,149,0,0,NULL,'2014-01-01'),
(150,150,0,0,NULL,'2014-01-01'),
(151,151,0,0,NULL,'2014-01-01'),
(152,152,0,0,NULL,'2014-01-01'),
(153,153,0,0,NULL,'2014-01-01'),
(154,154,0,0,NULL,'2014-01-01'),
(155,155,0,0,NULL,'2014-01-01'),
(156,156,0,0,NULL,'2014-01-01'),
(157,157,0,0,NULL,'2014-01-01'),
(158,158,0,0,NULL,'2014-01-01'),
(159,159,0,0,NULL,'2014-01-01'),
(160,160,0,0,NULL,'2014-01-01'),
(161,161,0,0,NULL,'2014-01-01'),
(162,162,0,0,NULL,'2014-01-01'),
(163,163,0,0,NULL,'2014-01-01'),
(164,164,0,0,NULL,'2014-01-01'),
(165,165,0,0,NULL,'2014-01-01'),
(166,166,0,0,NULL,'2014-01-01'),
(167,167,0,0,NULL,'2014-01-01'),
(168,168,0,0,NULL,'2014-01-01'),
(169,169,0,0,NULL,'2014-01-01'),
(170,170,0,0,NULL,'2014-01-01'),
(171,171,0,0,NULL,'2014-01-01'),
(172,172,0,0,NULL,'2014-01-01'),
(173,173,0,0,NULL,'2014-01-01'),
(174,174,0,0,NULL,'2014-01-01'),
(175,175,0,0,NULL,'2014-01-01'),
(176,176,0,0,NULL,'2014-01-01'),
(177,177,0,0,NULL,'2014-01-01'),
(178,178,0,0,NULL,'2014-01-01'),
(179,179,0,0,NULL,'2014-01-01'),
(180,180,0,0,NULL,'2014-01-01'),
(181,181,0,0,NULL,'2014-01-01'),
(182,182,0,0,NULL,'2014-01-01'),
(183,183,0,0,NULL,'2014-01-01'),
(184,184,0,0,NULL,'2014-01-01'),
(185,185,0,0,NULL,'2014-01-01'),
(186,186,0,0,NULL,'2014-01-01'),
(187,187,0,0,NULL,'2014-01-01'),
(188,188,0,0,NULL,'2014-01-01'),
(189,189,0,0,NULL,'2014-01-01'),
(190,190,0,0,NULL,'2014-01-01'),
(191,191,0,0,NULL,'2014-01-01');


-- Einheiten
DELETE FROM units;

INSERT INTO units (name, base_unit, factor, type) VALUES
('Stck',NULL,0.00000,'dimension'),
('mg',NULL,0.00000,'dimension'),
('g','mg',1000.00000,'dimension'),
('kg','g',1000.00000,'dimension'),
('t','kg',1000.00000,'dimension'),
('ml',NULL,0.00000,'dimension'),
('L','ml',1000.00000,'dimension'),
('pauschal',NULL,0.00000,'service'),
('Min',NULL,0.00000,'service'),
('Std','Min',60.00000,'service'),
('Tag','Std',8.00000,'service'),
('Wo',NULL,0.00000,'service'),
('Mt','Wo',4.00000,'service'),
('Jahr','Mt',12.00000,'service');