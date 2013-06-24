-- @tag: customer_add_constraints
-- @description: Zusätzliche Fremdschlüssel für Sprache, Kundentyp und Zahlungskonditionen
-- @depends: release_2_6_3
-- @ignore: 0

-- verwaiste Einträge vorher entfernen
UPDATE customer SET payment_id  = NULL WHERE payment_id  NOT IN (SELECT id FROM payment_terms);
UPDATE customer SET language_id = NULL WHERE language_id NOT IN (SELECT id FROM language);
UPDATE customer SET business_id = NULL WHERE business_id NOT IN (SELECT id FROM business);

ALTER TABLE customer ADD FOREIGN KEY (payment_id) REFERENCES payment_terms (id);
ALTER TABLE customer ADD FOREIGN KEY (language_id) REFERENCES language (id);
ALTER TABLE customer ADD FOREIGN KEY (business_id) REFERENCES business (id);
