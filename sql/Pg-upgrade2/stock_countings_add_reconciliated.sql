-- @tag: stock_countings_add_reconciliated
-- @description: Tabellenerweiterung für (Zwischen-)zählungen / Inventuren
-- @depends: warehouse stock_countings release_4_0_0

ALTER TABLE stock_countings ADD COLUMN reconciliated BOOLEAN DEFAULT false;
