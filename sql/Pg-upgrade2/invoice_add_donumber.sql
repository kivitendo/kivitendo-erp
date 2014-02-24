-- @tag: invoice_add_donumber
-- @description: invoice_add_donumber
-- @depends: release_3_0_0
ALTER TABLE invoice ADD COLUMN donumber TEXT;
