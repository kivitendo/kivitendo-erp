-- @tag: defaults_transit_items_account
-- @description: Voreingestelltes Konto für Durchlaufende Posten
-- @depends: release_3_7_0

ALTER TABLE defaults ADD COLUMN transit_items_chart_id INTEGER;
UPDATE defaults set transit_items_chart_id = (select id from chart where description='Durchlaufende Posten' LIMIT 1);
