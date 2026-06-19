-- @tag: stock_counting_items_add_encountered
-- @description: Inventurzählung: unterscheide vorgefundene von fehlenden Posten
-- @depends: warehouse stock_countings release_4_0_0

ALTER TABLE stock_counting_items ADD COLUMN encountered BOOLEAN DEFAULT true;
