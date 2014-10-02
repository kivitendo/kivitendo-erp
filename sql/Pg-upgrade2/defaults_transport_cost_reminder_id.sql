-- @tag: defaults_transport_cost_reminder_id
-- @description: Transportkostenartikelname verwerfen und stattdessen die Artikel-ID nehmnen
-- @depends: release_3_1_0 defaults_transport_cost_reminder
ALTER TABLE defaults ADD COLUMN transport_cost_reminder_article_number_id INTEGER;
ALTER TABLE defaults DROP COLUMN transport_cost_reminder_article_number;
