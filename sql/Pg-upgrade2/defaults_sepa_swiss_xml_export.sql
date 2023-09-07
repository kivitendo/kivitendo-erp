-- @tag: defaults_sepa_swiss_xml_export
-- @description: Banküberweisung via Schweizer XML Export
-- @depends: release_3_8_0
ALTER TABLE defaults ADD COLUMN sepa_swiss_xml_export boolean DEFAULT false;
