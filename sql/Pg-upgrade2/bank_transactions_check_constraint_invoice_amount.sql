-- @tag: bank_transactions_check_constraint_invoice_amount
-- @description: Bank-Transaktionen dürfen mehrfach verbucht werden - Sicherheitscheck auf DB-Ebene, Überbuchen der Bankbewegung verbieten
-- @depends: bank_transactions_type2 release_3_5_3

ALTER TABLE bank_transactions ADD CHECK (abs(invoice_amount) <= abs(amount));
