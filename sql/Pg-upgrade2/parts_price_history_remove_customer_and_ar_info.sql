-- @tag: parts_price_history_remove_customer_and_ar_info
-- @description: Kunden und VK-Beleginfo aus Preishistorie rausnehmen
-- @depends: parts_price_history_add_vc_arap_info

ALTER TABLE parts_price_history DROP COLUMN customer_id;
ALTER TABLE parts_price_history DROP COLUMN ar_id;
