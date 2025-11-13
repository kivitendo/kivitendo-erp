-- @tag: defaults_todo_oe_overdue_days
-- @description: Mandantenkonfiguration: Anzahl Tage, wann Angebote/Aufträge als überfällig für ToDos gelten
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN todo_oe_overdue_days INTEGER NOT NULL DEFAULT 1;
