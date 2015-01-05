-- @tag: defaults_add_finanzamt_data
-- @description: Fuer Umsatzsteuer Daten aus finanzamt.ini raus
-- @depends: release_3_4_1
ALTER TABLE defaults ADD COLUMN FA_BUFA_Nr text;
ALTER TABLE defaults ADD COLUMN FA_dauerfrist text;
ALTER TABLE defaults ADD COLUMN FA_steuerberater_city text;
ALTER TABLE defaults ADD COLUMN FA_steuerberater_name text;
ALTER TABLE defaults ADD COLUMN FA_steuerberater_street text;
ALTER TABLE defaults ADD COLUMN FA_steuerberater_tel text;
ALTER TABLE defaults ADD COLUMN FA_voranmeld text;
