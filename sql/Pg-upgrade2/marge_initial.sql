-- @tag: marge_initial
-- @description: Anzeigen des Ertrages pro Position bei Rechnungen und Auftraegen
-- @depends: status_history
ALTER TABLE ar add column marge_total NUMERIC(15,5);
ALTER TABLE ar add column marge_percent NUMERIC(15,5);

ALTER TABLE oe add column marge_total NUMERIC(15,5);
ALTER TABLE oe add column marge_percent NUMERIC(15,5);

ALTER TABLE invoice add column marge_total NUMERIC(15,5);
ALTER TABLE invoice add column marge_percent NUMERIC(15,5);
ALTER TABLE invoice add column lastcost NUMERIC(15,5);

ALTER TABLE orderitems add column marge_total NUMERIC(15,5);
ALTER TABLE orderitems add column marge_percent NUMERIC(15,5);
ALTER TABLE orderitems add column lastcost NUMERIC(15,5);
