-- @tag: stock_countings_add_cleared
-- @description: Tabellenerweiterung für (Zwischen-)zählungen / Inventuren
-- @depends: warehouse stock_countings release_3_9_0

ALTER TABLE stock_counting_items ADD COLUMN cleared BOOLEAN DEFAULT false;
