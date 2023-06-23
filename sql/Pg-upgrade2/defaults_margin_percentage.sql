-- @tag: defaults_margin_percentage
-- @description: New setting for default margin percentage. Will be preset in the Update Sell Price dialog.

ALTER TABLE defaults ADD COLUMN margin_percentage NUMERIC(8, 2);
UPDATE defaults SET margin_percentage = 1.0;
