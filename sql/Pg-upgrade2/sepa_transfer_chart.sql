-- @tag: sepa_transfer_chart
-- @description: Für SEPA-Überweisungen ein Zwischenkonto konfigurierbar machen
-- @depends: release_3_8_0

ALTER TABLE defaults ADD COLUMN sepa_transfer_chart_id INTEGER REFERENCES chart(id);
