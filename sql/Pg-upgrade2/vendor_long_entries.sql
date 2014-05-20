-- @tag: vendor_long_entries
-- @description: Lange Spalten für Lieferantentabelle
-- @depends: release_3_1_0

ALTER TABLE vendor ALTER COLUMN account_number TYPE text;
ALTER TABLE vendor ALTER COLUMN bank_code TYPE text;
ALTER TABLE vendor ALTER COLUMN ustid TYPE text;
ALTER TABLE vendor ALTER COLUMN name TYPE text;
ALTER TABLE vendor ALTER COLUMN contact TYPE text;

