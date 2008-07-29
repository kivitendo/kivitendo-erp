-- @tag: transaction_description_not_null
-- @description: Das Feld "transaction_description" sollte keine NULL-Werte enthalten.
-- @depends: transaction_description delivery_orders
UPDATE ap SET transaction_description = '' WHERE transaction_description IS NULL;
UPDATE ar SET transaction_description = '' WHERE transaction_description IS NULL;
UPDATE oe SET transaction_description = '' WHERE transaction_description IS NULL;
UPDATE delivery_orders SET transaction_description = '' WHERE transaction_description IS NULL;
