-- @tag: accounts_tax_office_leonberg
-- @description: Geänderte Kontoverbindung, Öffnungszeiten und Kontaktdaten für Finanzamt Leonberg
-- @depends: release_3_5_2
UPDATE finanzamt
SET fa_bankbezeichnung_1 = 'DT BBK Filiale Stuttgart', fa_blz_1 = '60000000', fa_kontonummer_1 = '60301501',
    fa_bankbezeichnung_2 = '',                         fa_blz_2 = '', fa_kontonummer_2 = '',
    fa_oeffnungszeiten = 'MO-MI 7.30-12.00,DO 7.30-17.30,FR 7.30-12.30',
    fa_email = 'poststelle-70@finanzamt.bwl.de',
    fa_internet = 'http://www.fa-leonberg.de/'
WHERE (fa_land_nr = '8')
  AND (fa_bufa_nr = '2870')
  AND (fa_name LIKE 'Leonberg%');
