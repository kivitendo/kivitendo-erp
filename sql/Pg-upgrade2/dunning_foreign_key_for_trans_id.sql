-- @tag: dunning_foreign_key_for_trans_id
-- @description: Mahnungstabelle: Fremdschlüssel für Verknüpfung zur Rechnungstabelle
-- @depends: release_3_5_3
DELETE FROM dunning
WHERE NOT EXISTS (
  SELECT ar.id
  FROM ar
  WHERE ar.id = dunning.trans_id
  LIMIT 1
);

ALTER TABLE dunning
ADD CONSTRAINT dunning_trans_id_fkey
FOREIGN KEY (trans_id) REFERENCES ar (id)
ON DELETE CASCADE;
