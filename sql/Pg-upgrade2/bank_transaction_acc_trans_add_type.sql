-- @tag: bank_transaction_acc_trans_add_type
-- @description: Automatische GL-Buchungen ausgelöst durch Bankverbuchungen markieren und Typisieren
-- @depends: release_4_0_0 bank_transaction_acc_trans_remove_wrong_primary_key

ALTER TABLE bank_transaction_acc_trans
ADD COLUMN automatic BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN type      TEXT;

-- try to guess old entries by localized source in acc_trans
UPDATE bank_transaction_acc_trans
   SET automatic = true, type = 'skonto_charts_and_tax_correction'
 WHERE gl_id IS NOT NULL
   AND acc_trans_id IN (
       SELECT acc_trans_id
         FROM acc_trans
        WHERE memo=''
          AND (source LIKE 'Skonto-Steuerkorrektur für%' OR source LIKE 'Skonto Tax Correction for%')
   );
