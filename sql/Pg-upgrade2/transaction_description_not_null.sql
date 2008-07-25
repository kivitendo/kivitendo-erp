-- @tag: transaction_description_not_null
-- @description: Das Feld "transaction_description" sollte nicht NULL-Werte enthalten.
-- @depends: transaction_description
UPDATE ap SET transaction_description = '' WHERE transaction_description IS NULL;
UPDATE ar SET transaction_description = '' WHERE transaction_description IS NULL;
UPDATE oe SET transaction_description = '' WHERE transaction_description IS NULL;
