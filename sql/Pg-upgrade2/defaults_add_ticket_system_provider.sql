-- @tag: defaults_add_ticket_system_provider
-- @description: Mandantenkonfiguration für Ticket System Anbieter
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN ticket_system_provider TEXT;
