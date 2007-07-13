-- @tag: oe_delivered
-- @description: Neues Feld f&uuml;r Status &quot;geliefert&quot; bei Auftragsbest&auml;tigungen und Lieferantenauftr&auml;gen
-- @depends: release_2_4_1
ALTER TABLE oe ADD COLUMN delivered boolean;
ALTER TABLE oe ALTER COLUMN delivered SET DEFAULT 'f';
UPDATE oe SET delivered = 'f';
