-- @tag: accounts_tax_office_bad_homburg
-- @description: Neue Kontoverbindung für Finanzamt Bad Homburg
-- @depends: release_3_0_0
UPDATE finanzamt
SET fa_bankbezeichnung_1 = 'Landesbank Hessen-Thüringen',      fa_blz_1 = '50050000', fa_kontonummer_1 = '1000124',
    fa_bankbezeichnung_2 = 'DT BBK Filiale Frankfurt am Main', fa_blz_2 = '50000000', fa_kontonummer_2 = '50001501'
WHERE (fa_land_nr = '6')
  AND (fa_bufa_nr = '2603')
  AND (fa_name LIKE 'Bad Homburg%');
