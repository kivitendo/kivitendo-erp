-- @tag: customer_long_entries
-- @description: Lange Spalten für Kundentabelle
-- @depends: release_2_6_1

ALTER TABLE customer ALTER COLUMN account_number TYPE text;
ALTER TABLE customer ALTER COLUMN bank_code TYPE text;
ALTER TABLE customer ALTER COLUMN ustid TYPE text;
ALTER TABLE customer ALTER COLUMN name TYPE text;
ALTER TABLE customer ALTER COLUMN contact TYPE text;

