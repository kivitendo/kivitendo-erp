-- @tag: add_transfer_doc_interval
-- @description: Konfigurierbarer Zeitraum innerhalb dessen Lieferscheine wieder rückgelagert werden können
-- @depends: release_3_5_6_1
ALTER TABLE defaults ADD COLUMN undo_transfer_interval integer DEFAULT 7;
