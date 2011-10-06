-- @tag: customer_add_constraints
-- @description: Zusätzliche Fremdschlüssel für Sprache, Kundentyp und Zahlungskonditionen
-- @depends: release_2_6_3
-- @charset: utf-8
-- @ignore: 0

ALTER TABLE customer ADD FOREIGN KEY (payment_id) REFERENCES payment_terms (id);
ALTER TABLE customer ADD FOREIGN KEY (language_id) REFERENCES language (id);
ALTER TABLE customer ADD FOREIGN KEY (business_id) REFERENCES business (id);
