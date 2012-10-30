-- @tag: csv_import_profiles_2
-- @description: Tempflag in CSV-Import-Profilen
-- @depends: csv_import_profiles
-- @charset: utf-8

ALTER TABLE csv_import_profiles ADD COLUMN login TEXT;
