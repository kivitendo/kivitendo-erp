-- @tag: add_ar_paid_defaults 
-- @description: Standardkonto für ar_paid (Umlaufvermögenskonto == Bank) in der Tabelle defaults hinzugefügt
-- @depends: release_2_6_1
ALTER TABLE defaults ADD COLUMN ar_paid_accno_id integer;
