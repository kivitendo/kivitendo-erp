-- @tag: customer_vendor_phone_no_limits
-- @description: Keine Längenbeschränkung für Spalte phone in den Tabellen customer und vendor.
-- @depends: release_2_7_0

ALTER TABLE customer ALTER COLUMN phone TYPE text;
ALTER TABLE vendor   ALTER COLUMN phone TYPE text;
