-- @tag: acc_trans_booleans_not_null
-- @description: Alte acc_trans boolean-Einträge mit NULL-Werten auf false setzen
-- @depends: release_3_0_0

UPDATE acc_trans SET cleared        = 'f' where cleared        IS NULL;
UPDATE acc_trans SET ob_transaction = 'f' where ob_transaction IS NULL;
UPDATE acc_trans SET cb_transaction = 'f' where cb_transaction IS NULL;
UPDATE acc_trans SET fx_transaction = 'f' where fx_transaction IS NULL;

ALTER TABLE acc_trans ALTER cleared        SET NOT NULL;
ALTER TABLE acc_trans ALTER ob_transaction SET NOT NULL;
ALTER TABLE acc_trans ALTER cb_transaction SET NOT NULL;
ALTER TABLE acc_trans ALTER fx_transaction SET NOT NULL;
