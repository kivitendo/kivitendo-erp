-- @tag: bank_transactions_add_end_to_end_id
-- @description: Kontoauszüge: Spalte für Ende-zu-Ende-ID ergänzen
-- @depends: release_3_9_0
ALTER TABLE bank_transactions ADD COLUMN end_to_end_id TEXT;
