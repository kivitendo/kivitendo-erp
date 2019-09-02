-- @tag: bank_transaction_acc_trans_remove_wrong_primary_key
-- @description: bank_transaction_acc_trans_remove_wrong_primary_key
-- @depends: release_3_5_4
ALTER TABLE bank_transaction_acc_trans
DROP COLUMN id;
