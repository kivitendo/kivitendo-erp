-- @tag: rename_general_ledger_rights
-- @description: Umbennenung des general ledger Rechts
-- @depends: split_transaction_rights
-- @locales: AP/AR Aging & Journal
UPDATE auth.master_rights SET description='AP/AR Aging & Journal' WHERE name='general_ledger';
