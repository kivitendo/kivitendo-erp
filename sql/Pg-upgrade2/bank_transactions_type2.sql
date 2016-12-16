-- @tag: bank_transactions_type2
-- @description: Spalten für Transaktions-Code und -Typen etwas besser benennen
-- @depends: bank_transactions_type

ALTER TABLE bank_transactions RENAME transactioncode TO transaction_code;
ALTER TABLE bank_transactions RENAME transactiontext TO transaction_text;
