-- @tag: defaults_yearend_method
-- @description: method used for the automated year-end bookings
-- @depends: release_3_8_0

ALTER TABLE defaults ADD COLUMN yearend_method TEXT;
