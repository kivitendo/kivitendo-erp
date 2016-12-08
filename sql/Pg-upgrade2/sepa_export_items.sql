-- @tag: sepa_export_items
-- @description: sepa reference in tabelle auf den im Standard spezifizierten zulässigen Wert (140) erhöhen
-- @depends: release_3_4_1 sepa
ALTER TABLE sepa_export_items
ALTER COLUMN reference TYPE varchar(140);




