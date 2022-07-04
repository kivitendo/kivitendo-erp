-- @tag: oe_add_order_status
-- @description: Status für Angebote und Aufträge: Feld in Angebot/Auftrags-Tabelle
-- @depends: order_statuses

ALTER TABLE oe ADD COLUMN order_status_id INTEGER REFERENCES order_statuses(id);
