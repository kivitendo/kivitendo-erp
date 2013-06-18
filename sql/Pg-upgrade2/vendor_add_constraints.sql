-- @tag: vendor_add_constraints
-- @description: Zusätzliche Fremdschlüssel für Sprache, Lieferantentyp und Zahlungskonditionen
-- @depends: release_2_6_3
-- @ignore: 0

-- verwaiste Einträge vorher entfernen
UPDATE vendor SET payment_id  = NULL WHERE payment_id  NOT IN (SELECT id FROM payment_terms);
UPDATE vendor SET language_id = NULL WHERE language_id NOT IN (SELECT id FROM language);
UPDATE vendor SET business_id = NULL WHERE business_id NOT IN (SELECT id FROM business);

ALTER TABLE vendor ADD FOREIGN KEY (payment_id) REFERENCES payment_terms (id);
ALTER TABLE vendor ADD FOREIGN KEY (language_id) REFERENCES language (id);
ALTER TABLE vendor ADD FOREIGN KEY (business_id) REFERENCES business (id);
