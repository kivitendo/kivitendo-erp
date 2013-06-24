-- @tag: license_invoice_drop
-- @description: Weder Lizenzen noch Lizenzrechnungen können an der Oberfläche erfasst werden. Konsequenterweise auch die entsprechende Datenbankeinträge rausnehmen.
-- @depends: release_2_6_3
-- @ignore: 0
DROP TABLE license;
DROP TABLE licenseinvoice;
--DROP SEQUENCE licenseinvoice_id_seq;  --wird schon automatisch mit entfernt
