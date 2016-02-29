-- @tag: ar_ap_default
-- @description: Standardkonten für Forderungen und Verbindlichkeiten
-- @depends: release_3_2_0
ALTER TABLE defaults ADD COLUMN ap_chart_id integer;
ALTER TABLE defaults ADD FOREIGN KEY (ap_chart_id) REFERENCES chart (id);
ALTER TABLE defaults ADD COLUMN ar_chart_id integer;
ALTER TABLE defaults ADD FOREIGN KEY (ar_chart_id) REFERENCES chart (id);
