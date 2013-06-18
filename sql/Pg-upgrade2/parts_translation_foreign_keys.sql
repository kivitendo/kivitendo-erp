-- @tag: parts_translation_foreign_keys
-- @description: Fremdschlüsseldefinitionen für parts, translation
-- @depends: release_3_0_0

UPDATE parts SET partsgroup_id   = NULL WHERE (partsgroup_id   IS NOT NULL) AND (partsgroup_id   NOT IN (SELECT id FROM partsgroup));
UPDATE parts SET payment_id      = NULL WHERE (payment_id      IS NOT NULL) AND (payment_id      NOT IN (SELECT id FROM payment_terms));
UPDATE parts SET price_factor_id = NULL WHERE (price_factor_id IS NOT NULL) AND (price_factor_id NOT IN (SELECT id FROM price_factors));

ALTER TABLE parts ADD FOREIGN KEY (partsgroup_id)   REFERENCES partsgroup    (id);
ALTER TABLE parts ADD FOREIGN KEY (price_factor_id) REFERENCES price_factors (id);
ALTER TABLE parts ADD FOREIGN KEY (payment_id)      REFERENCES payment_terms (id);

ALTER TABLE translation ADD FOREIGN KEY (language_id) REFERENCES language (id);
