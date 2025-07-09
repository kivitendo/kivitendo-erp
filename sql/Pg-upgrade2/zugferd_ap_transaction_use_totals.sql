-- @tag: zugferd_ap_transaction_use_totals
-- @description: Mandatenkonfigurationsoption um im ZUGFeRD Import nur die Gesamtsummen zu importieren
-- @depends: release_3_9_2

ALTER TABLE defaults ADD COLUMN zugferd_ap_transaction_use_totals BOOLEAN NOT NULL DEFAULT FALSE;
